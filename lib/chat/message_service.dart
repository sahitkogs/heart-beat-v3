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
/// flows. Constructed once per app session by the messageServiceProvider
/// (Task 22).
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

  /// Track per-peer "have we sent a PreKey bundle yet in this app session?".
  /// Reset on app restart; that's fine — sending a bundle a second time is
  /// also fine (libsignal idempotently advances the existing session).
  final Set<String> _bundleSentTo = <String>{};

  Future<void> sendText({
    required String peerPubkeyHex,
    required String body,
  }) async {
    await dao.ensureChat(peerPubkeyHex);

    if (!_bundleSentTo.contains(peerPubkeyHex)) {
      final myBundle = await crypto.myPreKeyBundle();
      final stamped = myBundle.copyWithOwner(myPubkeyHex);
      await relay.send(
        toPubkeyHex: peerPubkeyHex,
        envelope: EnvelopeWire.wrapPreKeyBundle(stamped),
      );
      _bundleSentTo.add(peerPubkeyHex);
    }

    final lamport = await dao.bumpLamport(peerPubkeyHex);
    final plaintext = utf8.encode(body);
    final ciphertext = await crypto.encrypt(
      peerPubkeyHex: peerPubkeyHex,
      plaintext: plaintext,
    );
    await relay.send(
      toPubkeyHex: peerPubkeyHex,
      envelope: EnvelopeWire.wrapMessage(ciphertext),
    );

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

  void _onInbound(RelayFrame frame) {
    if (frame is DeliverFrame) {
      // Fire-and-forget; errors are caught inside _handleDeliver.
      _handleDeliver(frame);
    }
    // Other frame types (error, online_status, pong) are not yet acted upon.
  }

  Future<void> _handleDeliver(DeliverFrame frame) async {
    await dao.ensureChat(frame.fromPubkeyHex);
    final ParsedEnvelope parsed;
    try {
      parsed = EnvelopeWire.parse(frame.envelope);
    } on FormatException {
      return; // Drop malformed envelopes silently
    }

    if (parsed.isBundle) {
      await crypto.processPeerPreKeyBundle(parsed.bundle!);
      return;
    }

    final List<int> plaintext;
    try {
      plaintext = await crypto.decrypt(
        peerPubkeyHex: frame.fromPubkeyHex,
        ciphertext: parsed.ciphertext!,
      );
    } catch (_) {
      return; // libsignal decrypt errors: drop the frame
    }
    final body = utf8.decode(plaintext);

    // Phase 10.2 uses a local Lamport bump on receive too; the remote's
    // Lamport isn't carried on the wire yet (future-phase protocol extension).
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
