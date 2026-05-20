import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import '../data/chats_dao.dart';
import '../relay/relay_client.dart';
import '../relay/relay_frames.dart';
import '../services/crypto_service.dart';
import 'pre_key_bootstrap.dart';

/// Orchestrates the encrypt → send → persist and receive → decrypt → persist
/// flows. Constructed once per app session by the messageServiceProvider.
class MessageService {
  MessageService({
    required this.crypto,
    required this.relay,
    required this.dao,
    required this.myPubkeyHex,
  }) {
    _sub = relay.inbound.listen(_onInbound);
  }

  final CryptoService crypto;
  final RelayClient relay;
  final ChatsDao dao;
  final String myPubkeyHex;

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

  /// Called when a chat thread is opened so both sides exchange bundles even
  /// before the first user-typed message. Idempotent.
  Future<void> openChat(String peerPubkeyHex) async {
    _log('openChat ${_short(peerPubkeyHex)}');
    await dao.ensureChat(peerPubkeyHex);
    await _maybeSendOwnBundle(peerPubkeyHex);
  }

  Future<void> sendText({
    required String peerPubkeyHex,
    required String body,
  }) async {
    _log('sendText peer=${_short(peerPubkeyHex)} bodyLen=${body.length}');
    await dao.ensureChat(peerPubkeyHex);
    await _maybeSendOwnBundle(peerPubkeyHex);
    await _persistOutbound(peerPubkeyHex, body);

    final chat = await dao.getChat(peerPubkeyHex);
    if (chat?.peerBundleReceivedAt == null) {
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
    final chat = await dao.getChat(peerPubkeyHex);
    if (chat?.bundleSentAt != null) {
      _log('bundle already sent to ${_short(peerPubkeyHex)}');
      return;
    }
    final myBundle = await crypto.myPreKeyBundle();
    final stamped = myBundle.copyWithOwner(myPubkeyHex);
    await relay.send(
      toPubkeyHex: peerPubkeyHex,
      envelope: EnvelopeWire.wrapPreKeyBundle(stamped),
    );
    await dao.markBundleSent(peerPubkeyHex);
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
    await relay.send(
      toPubkeyHex: peerPubkeyHex,
      envelope: EnvelopeWire.wrapMessage(ciphertext),
    );
  }

  void _onInbound(RelayFrame frame) {
    if (frame is DeliverFrame) {
      _handleDeliver(frame);
    }
  }

  Future<void> _handleDeliver(DeliverFrame frame) async {
    _log('inbound deliver from=${_short(frame.fromPubkeyHex)} '
        'envBytes=${frame.envelope.length} tag=0x${frame.envelope.isNotEmpty ? frame.envelope.first.toRadixString(16) : "??"}');
    await dao.ensureChat(frame.fromPubkeyHex);
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
      final existingChat = await dao.getChat(frame.fromPubkeyHex);
      final isFirstFromPeer = existingChat?.peerBundleReceivedAt == null;
      try {
        await crypto.processPeerPreKeyBundle(parsed.bundle!);
      } catch (e, st) {
        _log('processBundle FAIL: $e\n$st');
        return;
      }
      await dao.markPeerBundleReceived(frame.fromPubkeyHex);
      // Re-echo our bundle ONLY on the first bundle we receive from this
      // peer: our earlier send may have failed (e.g. recipient_offline), so
      // we force a re-send to make sure the peer can encrypt back. Avoid
      // doing this on every inbound bundle — that creates an infinite
      // ping-pong (their echo triggers ours triggers theirs…).
      if (isFirstFromPeer) {
        await dao.clearBundleSent(frame.fromPubkeyHex);
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
