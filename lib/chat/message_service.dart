import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import '../data/chats_dao.dart';
import '../relay/relay_client.dart';
import '../relay/relay_frames.dart';
import '../services/crypto_service.dart';
import '../services/wake_client.dart';
import 'pre_key_bootstrap.dart';

/// Orchestrates the encrypt → send → persist and receive → decrypt → persist
/// flows. Constructed once per app session by the messageServiceProvider.
class MessageService {
  MessageService({
    required this.crypto,
    required this.relay,
    required this.dao,
    required this.myPubkeyHex,
    this.wake,
  }) {
    _sub = relay.inbound.listen(_onInbound);
  }

  final CryptoService crypto;
  final RelayClient relay;
  final ChatsDao dao;
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
  // bundleSentAt / peerBundleReceivedAt live in drift (T3.1) so a background
  // FCM isolate (Phase 10.3 T7) doesn't re-run the bundle dance on every wake.
  // Only the pending-outbound queue stays in-memory — it's session-scoped and
  // drains the moment the peer's bundle arrives.
  final Map<String, List<String>> _pendingByPeer = <String, List<String>>{};

  // TODO(T3.5): In-session substitutes for the PeerBundleState DB columns.
  // Populated in _handleDeliver / _maybeSendOwnBundle. Correct for new sessions;
  // cross-restart idempotency is restored when T3.5 re-wires to PeerBundleStateDao.
  final Set<String> _peerBundleReceivedInSession = <String>{};
  final Set<String> _bundleSentInSession = <String>{};

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
    await _persistOutbound(peerPubkeyHex, body);

    // TODO(T3.5): re-wire peerBundleReceivedAt check via PeerBundleStateDao.
    // Until T3, use an in-session set as a substitute. Correct for new sessions;
    // cross-restart idempotency (skip queue if peer bundle already received
    // in a prior session) is restored in T3.
    if (!_peerBundleReceivedInSession.contains(peerPubkeyHex)) {
      (_pendingByPeer[peerPubkeyHex] ??= <String>[]).add(body);
      _log('queued (no peer bundle yet) peer=${_short(peerPubkeyHex)} '
          'queueDepth=${_pendingByPeer[peerPubkeyHex]!.length}');
      return;
    }
    try {
      await _encryptAndSend(peerPubkeyHex, body);
      _log('encrypted+sent peer=${_short(peerPubkeyHex)}');
    } catch (e, st) {
      _log('ENCRYPT FAIL peer=${_short(peerPubkeyHex)} err=$e\n$st');
      rethrow;
    }
  }

  Future<void> _maybeSendOwnBundle(String peerPubkeyHex) async {
    // TODO(T3.5): re-wire bundleSentAt check via PeerBundleStateDao (for
    // cross-restart idempotency). Until T3, use in-session set as substitute.
    if (_bundleSentInSession.contains(peerPubkeyHex)) {
      _log('bundle already sent this session to ${_short(peerPubkeyHex)}');
      return;
    }
    final myBundle = await crypto.myPreKeyBundle();
    final stamped = myBundle.copyWithOwner(myPubkeyHex);
    await relay.send(
      toPubkeyHex: peerPubkeyHex,
      envelope: EnvelopeWire.wrapPreKeyBundle(stamped),
    );
    _bundleSentInSession.add(peerPubkeyHex);
    // TODO(T3.5): dao.markBundleSent(peerPubkeyHex) — via PeerBundleStateDao.
    _log('sent OUR bundle to ${_short(peerPubkeyHex)} (preKeyId='
        '${stamped.preKeyId} regId=${stamped.registrationId})');
  }

  Future<void> _persistOutbound(String peerPubkeyHex, String body) async {
    final lamport = await dao.bumpLamport(peerPubkeyHex);
    final now = DateTime.now();
    await dao.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: peerPubkeyHex,
      senderPubkeyHex: myPubkeyHex,
      body: body,
      lamport: lamport,
      sentAt: now,
    ));
    await dao.updateLastMessage(peerPubkeyHex, _preview(body), now);
  }

  Future<void> _encryptAndSend(String peerPubkeyHex, String body) async {
    final plaintext = utf8.encode(body);
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
      // TODO(T3.5): dao.clearBundleSent(peer) — via PeerBundleStateDao.
      _bundleSentInSession.remove(peer);
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
      // TODO(T3.5): re-wire peerBundleReceivedAt / markPeerBundleReceived /
      // clearBundleSent via PeerBundleStateDao. Until T3, use in-session sets.
      final isFirstFromPeer = !_peerBundleReceivedInSession.contains(frame.fromPubkeyHex);
      try {
        await crypto.processPeerPreKeyBundle(parsed.bundle!);
      } catch (e, st) {
        _log('processBundle FAIL: $e\n$st');
        return;
      }
      // TODO(T3.5): dao.markPeerBundleReceived(frame.fromPubkeyHex) — via PeerBundleStateDao.
      _peerBundleReceivedInSession.add(frame.fromPubkeyHex);
      if (isFirstFromPeer) {
        // TODO(T3.5): dao.clearBundleSent(frame.fromPubkeyHex) — via PeerBundleStateDao.
        _bundleSentInSession.remove(frame.fromPubkeyHex);
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
        for (final body in pending) {
          try {
            await _encryptAndSend(frame.fromPubkeyHex, body);
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
    final body = utf8.decode(plaintext);
    _log('decrypted from=${_short(frame.fromPubkeyHex)} bodyLen=${body.length}');

    final lamport = await dao.bumpLamport(frame.fromPubkeyHex);
    final now = DateTime.now();
    await dao.insertMessage(MessagesCompanion.insert(
      id: _uuid.v4(),
      chatId: frame.fromPubkeyHex,
      senderPubkeyHex: frame.fromPubkeyHex,
      body: body,
      lamport: lamport,
      sentAt: now,
      receivedAt: Value(now),
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
