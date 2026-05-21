import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import '../data/chats_dao.dart';
import '../data/peer_bundle_state_dao.dart';
import '../relay/relay_client.dart';
import '../relay/relay_frames.dart';
import '../services/crypto_service.dart';
import '../services/wake_client.dart';
import 'group_envelope.dart';
import 'pre_key_bootstrap.dart';

/// Orchestrates the encrypt → send → persist and receive → decrypt → persist
/// flows. Constructed once per app session by the messageServiceProvider.
class MessageService {
  MessageService({
    required this.crypto,
    required this.relay,
    required this.dao,
    required this.peerBundleDao,
    required this.myPubkeyHex,
    this.wake,
  }) {
    _sub = relay.inbound.listen(_onInbound);
  }

  final CryptoService crypto;
  final RelayClient relay;
  final ChatsDao dao;
  final PeerBundleStateDao peerBundleDao;
  final String myPubkeyHex;
  // Optional in tests; production wiring always supplies one via the
  // messageServiceProvider. When null, recipient_offline errors are logged
  // but no wake fallback fires.
  final WakeClient? wake;

  late final StreamSubscription<RelayFrame> _sub;
  static const _uuid = Uuid();

  // Per-peer state needed for the chicken-and-egg bootstrap: libsignal cannot
  // encrypt to a peer until that peer's PreKey bundle has been processed, so
  // we must wait until we receive it before sending the first message.
  //
  // bundleSentAt / peerBundleReceivedAt live in PeerBundleStateDao (T3.1) so a
  // background FCM isolate (Phase 10.3 T7) doesn't re-run the bundle dance on
  // every wake, and state survives app restarts.
  // Only the pending-outbound queue stays in-memory — it's session-scoped and
  // drains the moment the peer's bundle arrives.
  // Entries are JSON inner-envelope bytes (List<int>), not raw strings.
  final Map<String, List<List<int>>> _pendingByPeer = <String, List<List<int>>>{};

  // Envelopes (message ones only, NOT bundles) that we've handed to the
  // relay but haven't proven made it to the peer. On a `recipient_offline`
  // error for a peer, we pop the oldest unacked envelope for that peer and
  // hand it to WakeClient.wake so the server can FCM-bridge it. Cleared for
  // a peer the moment we receive *any* inbound from them (proves online).
  final Map<String, List<List<int>>> _unackedByPeer = <String, List<List<int>>>{};

  /// Called when a chat thread is opened so both sides exchange bundles even
  /// before the first user-typed message. Idempotent.
  Future<void> openChat(String peerPubkeyHex) async {
    _log('openChat ${_short(peerPubkeyHex)}');
    await dao.ensureDirectChat(peerPubkeyHex);
    await _maybeSendOwnBundle(peerPubkeyHex);
  }

  Future<void> sendText({
    required String peerPubkeyHex,
    required String body,
  }) async {
    _log('sendText peer=${_short(peerPubkeyHex)} bodyLen=${body.length}');
    await dao.ensureDirectChat(peerPubkeyHex);
    await _maybeSendOwnBundle(peerPubkeyHex);

    // Compute lamport once; use it for both the persisted row and the
    // JSON inner envelope so they stay in sync.
    final lamport = await dao.bumpLamport(peerPubkeyHex);
    // chatId in the inner envelope is OUR pubkey (the sender's key), so that
    // the receiver's spoof guard (inner.chatId == frame.fromPubkeyHex) passes.
    final jsonBytes = InnerEnvelope.buildText(
      chatId: myPubkeyHex,
      lamport: lamport,
      body: body,
    );
    await _persistOutbound(peerPubkeyHex, body, lamport);

    final peerState = await peerBundleDao.get(peerPubkeyHex);
    if (peerState?.peerBundleReceivedAt == null) {
      (_pendingByPeer[peerPubkeyHex] ??= <List<int>>[]).add(jsonBytes);
      _log('queued (no peer bundle yet) peer=${_short(peerPubkeyHex)} '
          'queueDepth=${_pendingByPeer[peerPubkeyHex]!.length}');
      return;
    }
    try {
      await _encryptAndSend(peerPubkeyHex, jsonBytes);
      _log('encrypted+sent peer=${_short(peerPubkeyHex)}');
    } catch (e, st) {
      _log('ENCRYPT FAIL peer=${_short(peerPubkeyHex)} err=$e\n$st');
      rethrow;
    }
  }

  Future<void> _maybeSendOwnBundle(String peerPubkeyHex) async {
    final state = await peerBundleDao.get(peerPubkeyHex);
    if (state?.bundleSentAt != null) {
      _log('bundle already sent to ${_short(peerPubkeyHex)}');
      return;
    }
    final myBundle = await crypto.myPreKeyBundle();
    final stamped = myBundle.copyWithOwner(myPubkeyHex);
    await relay.send(
      toPubkeyHex: peerPubkeyHex,
      envelope: EnvelopeWire.wrapPreKeyBundle(stamped),
    );
    await peerBundleDao.markBundleSent(peerPubkeyHex);
    _log('sent OUR bundle to ${_short(peerPubkeyHex)} (preKeyId='
        '${stamped.preKeyId} regId=${stamped.registrationId})');
  }

  Future<void> _persistOutbound(
    String peerPubkeyHex,
    String body,
    int lamport,
  ) async {
    final now = DateTime.now();
    await dao.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: peerPubkeyHex,
      senderPubkeyHex: myPubkeyHex,
      body: body,
      lamport: lamport,
      sentAt: now,
      kind: const Value('text'),
    ));
    await dao.updateLastMessage(peerPubkeyHex, _preview(body), now);
  }

  Future<void> _encryptAndSend(String peerPubkeyHex, List<int> plaintext) async {
    final ciphertext = await crypto.encrypt(
      peerPubkeyHex: peerPubkeyHex,
      plaintext: plaintext,
    );
    final envelope = EnvelopeWire.wrapMessage(ciphertext);
    (_unackedByPeer[peerPubkeyHex] ??= <List<int>>[]).add(envelope);
    await relay.send(
      toPubkeyHex: peerPubkeyHex,
      envelope: envelope,
    );
  }

  void _onInbound(RelayFrame frame) {
    if (frame is DeliverFrame) {
      // Any inbound proves the peer is online; clear pending wake queue.
      _unackedByPeer.remove(frame.fromPubkeyHex);
      _handleDeliver(frame);
    } else if (frame is ErrorFrame) {
      _handleError(frame);
    }
  }

  Future<void> _handleError(ErrorFrame frame) async {
    if (frame.code != 'recipient_offline' || frame.toPubkeyHex == null) {
      _log('inbound error code=${frame.code} msg=${frame.message} (no wake)');
      return;
    }
    final peer = frame.toPubkeyHex!;
    final queue = _unackedByPeer[peer];
    if (queue == null || queue.isEmpty) {
      // No unacked message envelope means this recipient_offline almost
      // certainly came from a bundle send (bundle sends don't go into
      // _unackedByPeer because the wake path skips them). _maybeSendOwnBundle
      // already marked bundleSent on the relay.send call, so without this
      // reset we'd never retry — every future openChat/sendText would
      // short-circuit on "bundle already sent" and the peer never receives
      // our bundle. Clearing here unblocks the next attempt. The rare
      // "stale error after peer came online" race only costs us one extra
      // bundle on the next send.
      _log('wake_skipped no_in_flight peer=${_short(peer)} '
          '(likely failed bundle send; resetting bundleSent for retry)');
      await peerBundleDao.clearBundleSent(peer);
      return;
    }
    final envelope = queue.removeAt(0);
    if (queue.isEmpty) _unackedByPeer.remove(peer);

    final wakeClient = wake;
    if (wakeClient == null) {
      _log('wake_unconfigured peer=${_short(peer)} envBytes=${envelope.length}');
      return;
    }
    _log('wake_dispatching peer=${_short(peer)} envBytes=${envelope.length}');
    final result = await wakeClient.wake(
      senderPubkeyHex: myPubkeyHex,
      recipientPubkeyHex: peer,
      envelope: envelope,
    );
    switch (result.status) {
      case WakeStatus.ok:
        _log('wake_dispatched peer=${_short(peer)}');
      case WakeStatus.recipientNotRegistered:
        _log('wake_failed_no_phonebook peer=${_short(peer)}');
      case WakeStatus.fcmError:
        _log('wake_failed_fcm peer=${_short(peer)} detail=${result.detail}');
      case WakeStatus.networkError:
        _log('wake_failed_network peer=${_short(peer)} detail=${result.detail}');
      case WakeStatus.serverError:
        _log('wake_failed_server peer=${_short(peer)} detail=${result.detail}');
      case WakeStatus.unauthorized:
        _log('wake_failed_unauthorized peer=${_short(peer)} detail=${result.detail}');
    }
  }

  Future<void> _handleDeliver(DeliverFrame frame) async {
    _log('inbound deliver from=${_short(frame.fromPubkeyHex)} '
        'envBytes=${frame.envelope.length} tag=0x${frame.envelope.isNotEmpty ? frame.envelope.first.toRadixString(16) : "??"}');
    await dao.ensureDirectChat(frame.fromPubkeyHex);
    final ParsedEnvelope parsed;
    try {
      parsed = EnvelopeWire.parse(frame.envelope);
    } on FormatException catch (e) {
      _log('parse envelope FAIL: $e');
      return;
    }

    if (parsed.isBundle) {
      _log('inbound BUNDLE from=${_short(frame.fromPubkeyHex)} '
          'preKeyId=${parsed.bundle!.preKeyId} regId=${parsed.bundle!.registrationId}');
      final existingState = await peerBundleDao.get(frame.fromPubkeyHex);
      final isFirstFromPeer = existingState?.peerBundleReceivedAt == null;
      try {
        await crypto.processPeerPreKeyBundle(parsed.bundle!);
      } catch (e, st) {
        _log('processBundle FAIL: $e\n$st');
        return;
      }
      await peerBundleDao.markPeerBundleReceived(frame.fromPubkeyHex);
      if (isFirstFromPeer) {
        await peerBundleDao.clearBundleSent(frame.fromPubkeyHex);
        try {
          await _maybeSendOwnBundle(frame.fromPubkeyHex);
        } catch (e, st) {
          _log('re-echo bundle FAIL: $e\n$st');
        }
      }
      final pending = _pendingByPeer.remove(frame.fromPubkeyHex);
      if (pending != null) {
        _log('draining ${pending.length} pending msg(s) to '
            '${_short(frame.fromPubkeyHex)}');
        for (final jsonBytes in pending) {
          try {
            await _encryptAndSend(frame.fromPubkeyHex, jsonBytes);
            _log('drained+sent peer=${_short(frame.fromPubkeyHex)}');
          } catch (e, st) {
            _log('drain ENCRYPT FAIL: $e\n$st');
          }
        }
      }
      return;
    }

    _log('inbound MESSAGE from=${_short(frame.fromPubkeyHex)} '
        'ctBytes=${parsed.ciphertext!.length}');
    final List<int> plaintext;
    try {
      plaintext = await crypto.decrypt(
        peerPubkeyHex: frame.fromPubkeyHex,
        ciphertext: parsed.ciphertext!,
      );
    } catch (e, st) {
      _log('DECRYPT FAIL from=${_short(frame.fromPubkeyHex)} err=$e\n$st');
      return;
    }
    final InnerEnvelope inner;
    try {
      inner = InnerEnvelope.parse(plaintext);
    } on FormatException catch (e) {
      _log('inner_parse_fail from=${_short(frame.fromPubkeyHex)} err=$e');
      return;
    }

    if (inner is! TextEnvelope) {
      _log('non_text_inner_in_direct_path type=${inner.runtimeType}');
      return; // Groups land in T6. For T4, direct path only handles text.
    }

    // Direct-chat spoof guard: inner.chatId must equal the libsignal-session sender.
    if (inner.chatId != frame.fromPubkeyHex) {
      _log('direct_chat_id_mismatch from=${_short(frame.fromPubkeyHex)} '
          'innerChatId=${_short(inner.chatId)}');
      return;
    }

    final body = inner.body;
    _log('decrypted from=${_short(frame.fromPubkeyHex)} bodyLen=${body.length}');

    final lamport = await dao.observeLamport(frame.fromPubkeyHex, inner.lamport);
    final now = DateTime.now();
    await dao.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: frame.fromPubkeyHex,
      senderPubkeyHex: frame.fromPubkeyHex,
      body: body,
      lamport: lamport,
      sentAt: now,
      receivedAt: Value(now),
      kind: const Value('text'),
    ));
    await dao.updateLastMessage(frame.fromPubkeyHex, _preview(body), now);
  }

  String _preview(String body) =>
      body.length <= 80 ? body : '${body.substring(0, 77)}...';

  static String _short(String hex) =>
      hex.length >= 16 ? '${hex.substring(0, 6)}…${hex.substring(hex.length - 6)}' : hex;

  static void _log(String msg) {
    // ignore: avoid_print
    print('[MS] $msg');
  }

  Future<void> dispose() async {
    await _sub.cancel();
  }
}
