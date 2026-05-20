import 'dart:async';
import 'dart:convert';

import 'package:app_v3/chat/message_service.dart';
import 'package:app_v3/chat/pre_key_bootstrap.dart';
import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/chats_dao.dart';
import 'package:app_v3/relay/relay_client.dart';
import 'package:app_v3/relay/relay_frames.dart';
import 'package:app_v3/services/crypto_pre_key_bundle.dart';
import 'package:app_v3/services/crypto_service.dart';
import 'package:app_v3/services/signing_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _SentFrame {
  _SentFrame(this.to, this.envelope);
  final String to;
  final List<int> envelope;
}

class _FakeRelay implements RelayClient {
  final StreamController<RelayFrame> _ctrl =
      StreamController<RelayFrame>.broadcast();
  final List<_SentFrame> sent = [];

  void emit(RelayFrame frame) => _ctrl.add(frame);

  @override
  Stream<RelayFrame> get inbound => _ctrl.stream;

  @override
  Future<void> send({
    required String toPubkeyHex,
    required List<int> envelope,
  }) async {
    sent.add(_SentFrame(toPubkeyHex, envelope));
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {
    await _ctrl.close();
  }

  @override
  Uri get relayWsUrl => Uri.parse('ws://test.invalid/');

  @override
  SigningService get signing => throw UnimplementedError();
}

class _FakeCrypto implements CryptoService {
  int encryptCalls = 0;
  int decryptCalls = 0;
  final List<CryptoPreKeyBundle> processedBundles = [];

  static const _sampleBundle = CryptoPreKeyBundle(
    ownerPubkeyHex: '',
    registrationId: 99,
    deviceId: 1,
    preKeyId: 1,
    preKeyPublicHex: '01',
    signedPreKeyId: 1,
    signedPreKeyPublicHex: '02',
    signedPreKeySignatureHex: '03',
    identityKeyPublicHex: '04',
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<CryptoPreKeyBundle> myPreKeyBundle() async => _sampleBundle;

  @override
  Future<void> processPeerPreKeyBundle(CryptoPreKeyBundle bundle) async {
    processedBundles.add(bundle);
  }

  @override
  Future<List<int>> encrypt({
    required String peerPubkeyHex,
    required List<int> plaintext,
  }) async {
    encryptCalls++;
    // Fake "encryption" — prefix the plaintext so the test can detect it.
    return [0xCC, ...plaintext];
  }

  @override
  Future<List<int>> decrypt({
    required String peerPubkeyHex,
    required List<int> ciphertext,
  }) async {
    decryptCalls++;
    // Strip the 0xCC prefix written by encrypt().
    if (ciphertext.isNotEmpty && ciphertext.first == 0xCC) {
      return ciphertext.sublist(1);
    }
    return ciphertext;
  }
}

void main() {
  late AppDatabase db;
  late ChatsDao dao;
  late _FakeCrypto crypto;
  late _FakeRelay relay;
  late MessageService service;

  final myPub = 'aa' * 32;
  final peerPub = 'bb' * 32;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ChatsDao(db);
    crypto = _FakeCrypto();
    relay = _FakeRelay();
    service = MessageService(
      crypto: crypto,
      relay: relay,
      dao: dao,
      myPubkeyHex: myPub,
    );
  });

  tearDown(() async {
    await service.dispose();
    await relay.dispose();
    await db.close();
  });

  test('first sendText emits PreKey bundle envelope then message envelope',
      () async {
    await service.sendText(peerPubkeyHex: peerPub, body: 'hello');

    expect(relay.sent.length, 2);
    expect(relay.sent[0].to, peerPub);
    expect(relay.sent[0].envelope.first, EnvelopeTag.preKeyBundle);

    // The bundle on the wire should carry the sender's pubkey stamped on it.
    final parsedBundle = EnvelopeWire.parse(relay.sent[0].envelope);
    expect(parsedBundle.isBundle, isTrue);
    expect(parsedBundle.bundle?.ownerPubkeyHex, myPub);

    expect(relay.sent[1].envelope.first, EnvelopeTag.message);
    final parsedMsg = EnvelopeWire.parse(relay.sent[1].envelope);
    expect(parsedMsg.isMessage, isTrue);
    // _FakeCrypto prefixes plaintext with 0xCC.
    expect(parsedMsg.ciphertext!.first, 0xCC);
    expect(utf8.decode(parsedMsg.ciphertext!.sublist(1)), 'hello');

    expect(crypto.encryptCalls, 1);
  });

  test('second sendText to same peer skips the bundle', () async {
    await service.sendText(peerPubkeyHex: peerPub, body: 'first');
    await service.sendText(peerPubkeyHex: peerPub, body: 'second');

    // 2 from first send (bundle + message), 1 from second (message only).
    expect(relay.sent.length, 3);
    expect(relay.sent[2].envelope.first, EnvelopeTag.message);
    expect(crypto.encryptCalls, 2);
  });

  test('inbound message envelope decrypts and persists a row', () async {
    final ciphertext = [0xCC, ...utf8.encode('hi from peer')];
    final envelope = EnvelopeWire.wrapMessage(ciphertext);

    relay.emit(DeliverFrame(fromPubkeyHex: peerPub, envelope: envelope));

    // Drain microtasks so the async _handleDeliver chain completes.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final msgs = await dao.watchMessages(peerPub).first;
    expect(msgs.length, 1);
    expect(msgs.first.body, 'hi from peer');
    expect(msgs.first.senderPubkeyHex, peerPub);
    expect(crypto.decryptCalls, 1);

    final chatList = await dao.watchChats().first;
    expect(chatList.length, 1);
    expect(chatList.first.lastMessagePreview, 'hi from peer');
  });

  test('inbound bundle envelope calls processPeerPreKeyBundle', () async {
    final bundle = CryptoPreKeyBundle(
      ownerPubkeyHex: peerPub,
      registrationId: 42,
      deviceId: 1,
      preKeyId: 7,
      preKeyPublicHex: '01' * 32,
      signedPreKeyId: 8,
      signedPreKeyPublicHex: '02' * 32,
      signedPreKeySignatureHex: '03' * 32,
      identityKeyPublicHex: '04' * 32,
    );
    final envelope = EnvelopeWire.wrapPreKeyBundle(bundle);

    relay.emit(DeliverFrame(fromPubkeyHex: peerPub, envelope: envelope));

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(crypto.processedBundles.length, 1);
    expect(crypto.processedBundles.first.registrationId, 42);

    // A bundle frame should not insert a message row.
    final msgs = await dao.watchMessages(peerPub).first;
    expect(msgs, isEmpty);
  });

  test('outbound sendText persists a row attributed to me', () async {
    await service.sendText(peerPubkeyHex: peerPub, body: 'mine');

    final msgs = await dao.watchMessages(peerPub).first;
    expect(msgs.length, 1);
    expect(msgs.first.body, 'mine');
    expect(msgs.first.senderPubkeyHex, myPub);
    expect(msgs.first.lamport, 1);
  });
}
