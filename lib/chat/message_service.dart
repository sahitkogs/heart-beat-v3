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
  final Set<String> _bundleSentTo = <String>{};
  final Set<String> _peerBundleReceived = <String>{};
  final Map<String, List<String>> _pendingByPeer = <String, List<String>>{};

  /// Called when a chat thread is opened so both sides exchange bundles even
  /// before the first user-typed message. Idempotent.
  Future<void> openChat(String peerPubkeyHex) async {
    await dao.ensureChat(peerPubkeyHex);
    await _maybeSendOwnBundle(peerPubkeyHex);
  }

  Future<void> sendText({
    required String peerPubkeyHex,
    required String body,
  }) async {
    await dao.ensureChat(peerPubkeyHex);
    await _maybeSendOwnBundle(peerPubkeyHex);
    await _persistOutbound(peerPubkeyHex, body);

    if (!_peerBundleReceived.contains(peerPubkeyHex)) {
      (_pendingByPeer[peerPubkeyHex] ??= <String>[]).add(body);
      return;
    }
    await _encryptAndSend(peerPubkeyHex, body);
  }

  Future<void> _maybeSendOwnBundle(String peerPubkeyHex) async {
    if (_bundleSentTo.contains(peerPubkeyHex)) return;
    final myBundle = await crypto.myPreKeyBundle();
    final stamped = myBundle.copyWithOwner(myPubkeyHex);
    await relay.send(
      toPubkeyHex: peerPubkeyHex,
      envelope: EnvelopeWire.wrapPreKeyBundle(stamped),
    );
    _bundleSentTo.add(peerPubkeyHex);
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
    await dao.ensureChat(frame.fromPubkeyHex);
    final ParsedEnvelope parsed;
    try {
      parsed = EnvelopeWire.parse(frame.envelope);
    } on FormatException {
      return;
    }

    if (parsed.isBundle) {
      await crypto.processPeerPreKeyBundle(parsed.bundle!);
      _peerBundleReceived.add(frame.fromPubkeyHex);
      // Make sure the peer also has our bundle so they can encrypt back.
      await _maybeSendOwnBundle(frame.fromPubkeyHex);
      // Drain anything that was queued while we waited.
      final pending = _pendingByPeer.remove(frame.fromPubkeyHex);
      if (pending != null) {
        for (final body in pending) {
          try {
            await _encryptAndSend(frame.fromPubkeyHex, body);
          } catch (_) {
            // Drop on the floor for now; future phase: retry / surface to UI.
          }
        }
      }
      return;
    }

    final List<int> plaintext;
    try {
      plaintext = await crypto.decrypt(
        peerPubkeyHex: frame.fromPubkeyHex,
        ciphertext: parsed.ciphertext!,
      );
    } catch (_) {
      return;
    }
    final body = utf8.decode(plaintext);

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

  Future<void> dispose() async {
    await _sub.cancel();
  }
}
