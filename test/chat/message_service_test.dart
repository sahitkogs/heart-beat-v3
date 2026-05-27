import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_v3/chat/group_envelope.dart';
import 'package:app_v3/chat/message_service.dart';
import 'package:app_v3/chat/pre_key_bootstrap.dart';
import 'package:app_v3/core/hex_codec.dart';
import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/chats_dao.dart';
import 'package:app_v3/data/contacts_repository.dart';
import 'package:app_v3/data/group_members_dao.dart';
import 'package:app_v3/data/group_ops_log_dao.dart';
import 'package:app_v3/data/models/contact.dart' as contact_model;
import 'package:app_v3/data/outbox_dao.dart';
import 'package:app_v3/data/peer_bundle_state_dao.dart';
import 'package:app_v3/data/profile_dao.dart';
import 'package:app_v3/relay/relay_client.dart';
import 'package:app_v3/relay/relay_frames.dart';
import 'package:app_v3/services/crypto_pre_key_bundle.dart';
import 'package:app_v3/services/crypto_service.dart';
import 'package:app_v3/services/identity_service.dart';
import 'package:app_v3/services/key_storage.dart';
import 'package:app_v3/services/signing_service.dart';
import 'package:app_v3/services/wake_client.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
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

  @override
  bool get isConnected => true;
}

class _NoopSecureStorage implements SecureKeyValueStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _FakeWakeClient extends WakeClient {
  _FakeWakeClient(this._respond)
      : super(
          baseUri: Uri.parse('http://wake.test'),
          signing: SigningService(KeyStorage(_NoopSecureStorage())),
        );

  final WakeResult Function() _respond;
  final List<_WakeCall> calls = [];

  @override
  Future<WakeResult> wake({
    required String senderPubkeyHex,
    required String recipientPubkeyHex,
    required List<int> envelope,
  }) async {
    calls.add(_WakeCall(senderPubkeyHex, recipientPubkeyHex, envelope));
    return _respond();
  }
}

class _WakeCall {
  _WakeCall(this.sender, this.peer, this.envelope);
  final String sender;
  final String peer;
  final List<int> envelope;
}

class _MemStorage implements SecureKeyValueStorage {
  final Map<String, String> _store = {};
  @override
  Future<String?> read(String key) async => _store[key];
  @override
  Future<void> write(String key, String value) async => _store[key] = value;
  @override
  Future<void> delete(String key) async => _store.remove(key);
}

/// Mirror of MessageService._short used in test assertions.
String _shortPub(String hex) =>
    hex.length >= 16 ? '${hex.substring(0, 6)}…${hex.substring(hex.length - 6)}' : hex;

/// Creates a [SigningService] with a freshly generated identity key so tests
/// can call [signing.sign] and [SigningService.verify] without touching device
/// Keystore.
Future<SigningService> makeSigningService() async {
  final ks = KeyStorage(_MemStorage());
  final id = IdentityService(ks);
  await id.loadOrCreate(); // generates + stores a random Ed25519 seed
  return SigningService(ks);
}

class _FakeCrypto implements CryptoService {
  int encryptCalls = 0;
  int decryptCalls = 0;
  final List<CryptoPreKeyBundle> processedBundles = [];
  /// Each encrypt() call appends its plaintext here. Used by T5.2 tests to
  /// inspect what was about to be sent on the wire (post-libsignal, the
  /// only thing tests can usefully assert is the JSON inner envelope).
  final List<List<int>> encryptedPlaintexts = [];

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
    encryptedPlaintexts.add(List<int>.from(plaintext));
    return [0xCC, ...plaintext];
  }

  @override
  Future<List<int>> decrypt({
    required String peerPubkeyHex,
    required List<int> ciphertext,
  }) async {
    decryptCalls++;
    if (ciphertext.isNotEmpty && ciphertext.first == 0xCC) {
      return ciphertext.sublist(1);
    }
    return ciphertext;
  }

  @override
  Future<void> forgetPeer(String peerPubkeyHex) async {}
}

/// A [CryptoService] wrapper that delegates all calls to [_inner] except
/// [encrypt], where it throws [StateError] for the specified [failPeer].
/// Used by T5.2 to verify that per-peer failures don't abort the fan-out.
class _FailCryptoForPeer implements CryptoService {
  _FailCryptoForPeer(this._inner, {required this.failPeer});
  final _FakeCrypto _inner;
  final String failPeer;

  @override
  Future<void> initialize() => _inner.initialize();

  @override
  Future<CryptoPreKeyBundle> myPreKeyBundle() => _inner.myPreKeyBundle();

  @override
  Future<void> processPeerPreKeyBundle(CryptoPreKeyBundle bundle) =>
      _inner.processPeerPreKeyBundle(bundle);

  @override
  Future<List<int>> encrypt({
    required String peerPubkeyHex,
    required List<int> plaintext,
  }) {
    if (peerPubkeyHex == failPeer) {
      throw StateError('_FailCryptoForPeer: forced failure for $failPeer');
    }
    return _inner.encrypt(peerPubkeyHex: peerPubkeyHex, plaintext: plaintext);
  }

  @override
  Future<List<int>> decrypt({
    required String peerPubkeyHex,
    required List<int> ciphertext,
  }) =>
      _inner.decrypt(peerPubkeyHex: peerPubkeyHex, ciphertext: ciphertext);

  @override
  Future<void> forgetPeer(String peerPubkeyHex) => _inner.forgetPeer(peerPubkeyHex);
}

void main() {
  // The restart test opens two AppDatabase instances over the same file —
  // suppress drift's "multiple databases" warning so real failures stay
  // visible.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late ChatsDao dao;
  late PeerBundleStateDao peerBundleDao;
  late OutboxDao outboxDao;
  late GroupMembersDao groupMembersDao;
  late GroupOpsLogDao groupOpsLogDao;
  late SigningService signing;
  late ContactsRepository contactsRepo;
  late _FakeCrypto crypto;
  late _FakeRelay relay;
  late MessageService service;

  final myPub = 'aa' * 32;
  final peerPub = 'bb' * 32;

  CryptoPreKeyBundle peerBundle() => const CryptoPreKeyBundle(
        ownerPubkeyHex: '',
        registrationId: 42,
        deviceId: 1,
        preKeyId: 7,
        preKeyPublicHex: '01',
        signedPreKeyId: 8,
        signedPreKeyPublicHex: '02',
        signedPreKeySignatureHex: '03',
        identityKeyPublicHex: '04',
      ).copyWithOwner(peerPub);

  Future<void> drainMicrotasks() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ChatsDao(db);
    peerBundleDao = PeerBundleStateDao(db);
    outboxDao = OutboxDao(db);
    groupMembersDao = GroupMembersDao(db);
    groupOpsLogDao = GroupOpsLogDao(db);
    signing = await makeSigningService();
    contactsRepo = ContactsRepository(db);
    crypto = _FakeCrypto();
    relay = _FakeRelay();
    service = MessageService(
      crypto: crypto,
      relay: relay,
      dao: dao,
      peerBundleDao: peerBundleDao,
      outboxDao: outboxDao,
      myPubkeyHex: myPub,
      groupMembersDao: groupMembersDao,
      groupOpsLogDao: groupOpsLogDao,
      signing: signing,
      contactsRepository: contactsRepo,
      profileDao: ProfileDao(db),
    );
  });

  tearDown(() async {
    await service.dispose();
    await relay.dispose();
    await db.close();
  });

  test("forgetPeer drops the peer's outbox rows", () async {
    // Bootstrap so sendText writes outbox rows.
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
    ));
    await drainMicrotasks();

    final peerB = 'cc' * 32;
    // Bootstrap peerB too.
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerB,
      envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle().copyWithOwner(peerB)),
    ));
    await drainMicrotasks();

    await service.sendText(peerPubkeyHex: peerPub, body: 'a');
    await service.sendText(peerPubkeyHex: peerB, body: 'b');
    final preA = await outboxDao.dueBefore(
        DateTime.now().add(const Duration(days: 1)));
    expect(preA.where((r) => r.peerPubkeyHex == peerPub), isNotEmpty);
    expect(preA.where((r) => r.peerPubkeyHex == peerB), isNotEmpty);

    await service.forgetPeer(peerPub);

    final postA = await outboxDao.dueBefore(
        DateTime.now().add(const Duration(days: 1)));
    expect(postA.where((r) => r.peerPubkeyHex == peerPub), isEmpty);
    expect(postA.where((r) => r.peerPubkeyHex == peerB), isNotEmpty);
  });

  test('inbound delivered receipt advances state and deletes outbox row', () async {
    // Bootstrap so sendText sends rather than queues.
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
    ));
    await drainMicrotasks();

    await service.sendText(peerPubkeyHex: peerPub, body: 'ping');
    final outRows = await outboxDao.dueBefore(
        DateTime.now().add(const Duration(days: 1)));
    final msgId = outRows.firstWhere((r) => r.peerPubkeyHex == peerPub).msgId;

    final receipt = InnerEnvelope.buildDeliveryReceipt(
      chatId: myPub,
      msgIds: [msgId],
      kind: ReceiptKind.delivered,
      at: DateTime.now(),
    );
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapMessage([0xCC, ...receipt]),
    ));
    await drainMicrotasks();

    final row = await dao.findMessageById(msgId);
    expect(row!.deliveryState, DeliveryState.delivered);
    expect(await outboxDao.findByMsgId(msgId), isNull);
  });

  test('read receipt allows direct sent -> read transition', () async {
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
    ));
    await drainMicrotasks();

    await service.sendText(peerPubkeyHex: peerPub, body: 'p');
    final msgId = (await outboxDao.dueBefore(
            DateTime.now().add(const Duration(days: 1))))
        .firstWhere((r) => r.peerPubkeyHex == peerPub)
        .msgId;

    final r = InnerEnvelope.buildDeliveryReceipt(
      chatId: myPub, msgIds: [msgId],
      kind: ReceiptKind.read, at: DateTime.now(),
    );
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapMessage([0xCC, ...r]),
    ));
    await drainMicrotasks();

    expect((await dao.findMessageById(msgId))!.deliveryState,
        DeliveryState.read);
  });

  test('forged receipt from wrong peer is ignored', () async {
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
    ));
    await drainMicrotasks();

    await service.sendText(peerPubkeyHex: peerPub, body: 'p');
    final msgId = (await outboxDao.dueBefore(
            DateTime.now().add(const Duration(days: 1))))
        .firstWhere((r) => r.peerPubkeyHex == peerPub)
        .msgId;

    final attacker = 'cc' * 32;
    final r = InnerEnvelope.buildDeliveryReceipt(
      chatId: myPub, msgIds: [msgId],
      kind: ReceiptKind.delivered, at: DateTime.now(),
    );
    relay.emit(DeliverFrame(
      fromPubkeyHex: attacker,
      envelope: EnvelopeWire.wrapMessage([0xCC, ...r]),
    ));
    await drainMicrotasks();

    // State unchanged, outbox row still present.
    expect((await dao.findMessageById(msgId))!.deliveryState,
        DeliveryState.sent);
    expect(await outboxDao.findByMsgId(msgId), isNotNull);
  });

  test('delivered after read does not downgrade tick', () async {
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
    ));
    await drainMicrotasks();

    await service.sendText(peerPubkeyHex: peerPub, body: 'p');
    final msgId = (await outboxDao.dueBefore(
            DateTime.now().add(const Duration(days: 1))))
        .firstWhere((r) => r.peerPubkeyHex == peerPub)
        .msgId;

    // Read first (legal — receipts can reorder).
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapMessage([0xCC, ...InnerEnvelope.buildDeliveryReceipt(
        chatId: myPub, msgIds: [msgId],
        kind: ReceiptKind.read, at: DateTime.now())]),
    ));
    await drainMicrotasks();

    // We need to re-insert the outbox row because the read receipt deleted
    // it; otherwise the second receipt would hit the no-outbox skip branch.
    // Instead, just verify the state stays at `read` after a delivered receipt
    // would have been processed: re-insert a fresh outbox row, then send.
    final now = DateTime.now();
    await outboxDao.insert(
      msgId: msgId, peerPubkeyHex: peerPub,
      envelopeBytes: [1], createdAt: now, nextRetryAt: now,
    );
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapMessage([0xCC, ...InnerEnvelope.buildDeliveryReceipt(
        chatId: myPub, msgIds: [msgId],
        kind: ReceiptKind.delivered, at: DateTime.now())]),
    ));
    await drainMicrotasks();

    expect((await dao.findMessageById(msgId))!.deliveryState,
        DeliveryState.read);
  });

  test('inbound text persists with id = inner.msgId', () async {
    final inner = InnerEnvelope.buildText(
      chatId: peerPub, lamport: 1, body: 'hello',
      msgId: 'fixed-msg-1',
    );
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapMessage([0xCC, ...inner]),
    ));
    await drainMicrotasks();

    final row = await dao.findMessageById('fixed-msg-1');
    expect(row, isNotNull);
    expect(row!.body, 'hello');
    expect(row.senderPubkeyHex, peerPub);
  });

  test('duplicate inbound text is dropped silently', () async {
    final inner = InnerEnvelope.buildText(
      chatId: peerPub, lamport: 1, body: 'hi',
      msgId: 'dup-1',
    );
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapMessage([0xCC, ...inner]),
    ));
    await drainMicrotasks();
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapMessage([0xCC, ...inner]),
    ));
    await drainMicrotasks();

    final rows = (await db.select(db.messages).get())
        .where((r) => r.id == 'dup-1').toList();
    expect(rows, hasLength(1));
  });

  test('sendText writes an outbox row keyed by msgId', () async {
    // Get to a state where peer bundle is known so sendText doesn't just
    // queue: emit a peer bundle first.
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
    ));
    await drainMicrotasks();

    await service.sendText(peerPubkeyHex: peerPub, body: 'hello');

    final allRows = await outboxDao.dueBefore(
        DateTime.now().add(const Duration(days: 1)));
    final peerRows = allRows.where((r) => r.peerPubkeyHex == peerPub).toList();
    expect(peerRows, hasLength(1));
    final msgId = peerRows.first.msgId;

    // The messages.id row must match the outbox msgId.
    final msgRow = await dao.findMessageById(msgId);
    expect(msgRow, isNotNull);
    expect(msgRow!.senderPubkeyHex, myPub);
    expect(msgRow.body, 'hello');
  });

  test('sendText sets initial nextRetryAt to createdAt + 30s', () async {
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
    ));
    await drainMicrotasks();

    final before = DateTime.now();
    await service.sendText(peerPubkeyHex: peerPub, body: 'x');
    final after = DateTime.now();
    final rows = await outboxDao.dueBefore(after.add(const Duration(days: 1)));
    final row = rows.firstWhere((r) => r.peerPubkeyHex == peerPub);
    final delta = row.nextRetryAt.difference(row.createdAt);
    expect(delta.inSeconds, inInclusiveRange(28, 32));
    expect(row.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue);
  });

  test('first sendText sends bundle, persists row, queues encrypt', () async {
    await service.sendText(peerPubkeyHex: peerPub, body: 'hello');

    // Bundle goes out immediately; message is queued, so encrypt hasn't run.
    expect(relay.sent.length, 1);
    expect(relay.sent[0].to, peerPub);
    expect(relay.sent[0].envelope.first, EnvelopeTag.preKeyBundle);
    final parsedBundle = EnvelopeWire.parse(relay.sent[0].envelope);
    expect(parsedBundle.bundle?.ownerPubkeyHex, myPub);
    expect(crypto.encryptCalls, 0);

    // The outbound row is still persisted so the UI can show it.
    final msgs = await dao.watchMessages(peerPub).first;
    expect(msgs.length, 1);
    expect(msgs.first.body, 'hello');
    expect(msgs.first.senderPubkeyHex, myPub);
  });

  test('queued sendText flushes when peer bundle arrives', () async {
    await service.sendText(peerPubkeyHex: peerPub, body: 'queued');
    expect(crypto.encryptCalls, 0);

    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
    ));
    await drainMicrotasks();

    // After the bundle arrives: encrypt fires once, message envelope sent.
    expect(crypto.encryptCalls, 1);
    final msgEnvelopes = relay.sent
        .where((f) => f.envelope.first == EnvelopeTag.message)
        .toList();
    expect(msgEnvelopes.length, 1);
    final parsedMsg = EnvelopeWire.parse(msgEnvelopes.first.envelope);
    // FakeCrypto prepends 0xCC; strip it to get the inner JSON bytes.
    final innerBytes = parsedMsg.ciphertext!.sublist(1);
    final inner = InnerEnvelope.parse(innerBytes);
    expect(inner, isA<TextEnvelope>());
    expect((inner as TextEnvelope).body, 'queued');
    // chatId is the sender's own pubkey (myPub) so the receiver's
    // spoof guard (chatId == fromPubkeyHex) passes.
    expect(inner.chatId, myPub);
  });

  test('second sendText after bundle is already established sends immediately',
      () async {
    // Bootstrap: peer bundle arrives first.
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
    ));
    await drainMicrotasks();
    final sentBefore = relay.sent.length;

    await service.sendText(peerPubkeyHex: peerPub, body: 'one');
    await service.sendText(peerPubkeyHex: peerPub, body: 'two');

    // Each subsequent sendText sends exactly one message envelope.
    final newSent = relay.sent.skip(sentBefore).toList();
    final msgFrames = newSent
        .where((f) => f.envelope.first == EnvelopeTag.message)
        .toList();
    expect(msgFrames.length, 2);
    expect(crypto.encryptCalls, 2);
  });

  test('inbound message envelope decrypts and persists a row', () async {
    // Sender uses JSON inner envelope; chatId must equal fromPubkeyHex for
    // the direct-chat spoof guard to pass.
    final innerBytes = InnerEnvelope.buildText(
      chatId: peerPub,
      lamport: 1,
      body: 'hi from peer',
      msgId: 'msg-hi-from-peer',
    );
    final ciphertext = [0xCC, ...innerBytes];
    final envelope = EnvelopeWire.wrapMessage(ciphertext);

    relay.emit(DeliverFrame(fromPubkeyHex: peerPub, envelope: envelope));
    await drainMicrotasks();

    final msgs = await dao.watchMessages(peerPub).first;
    expect(msgs.length, 1);
    expect(msgs.first.body, 'hi from peer');
    expect(msgs.first.senderPubkeyHex, peerPub);
    expect(crypto.decryptCalls, 1);

    final chatList = await dao.watchChats().first;
    expect(chatList.length, 1);
    expect(chatList.first.lastMessagePreview, 'hi from peer');
  });

  test('inbound bundle envelope processes peer and sends our bundle back',
      () async {
    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
    ));
    await drainMicrotasks();

    expect(crypto.processedBundles.length, 1);
    expect(crypto.processedBundles.first.registrationId, 42);

    // We should have replied with our own bundle so the peer can encrypt back.
    final ourBundles = relay.sent
        .where((f) => f.envelope.first == EnvelopeTag.preKeyBundle)
        .toList();
    expect(ourBundles.length, 1);
    expect(ourBundles.first.to, peerPub);

    final msgs = await dao.watchMessages(peerPub).first;
    expect(msgs, isEmpty);
  });

  test('outbound sendText persists a row attributed to me with lamport 1',
      () async {
    await service.sendText(peerPubkeyHex: peerPub, body: 'mine');

    final msgs = await dao.watchMessages(peerPub).first;
    expect(msgs.length, 1);
    expect(msgs.first.body, 'mine');
    expect(msgs.first.senderPubkeyHex, myPub);
    expect(msgs.first.lamport, 1);
  });

  test('inbound peer bundle re-echoes our bundle even if we sent before',
      () async {
    // Simulate the real race: we sent our bundle first (peer was offline so
    // relay dropped it), then peer comes online and sends theirs.
    await service.openChat(peerPub);
    final sentByUs = relay.sent.length;
    expect(sentByUs, 1); // our bundle attempt

    relay.emit(DeliverFrame(
      fromPubkeyHex: peerPub,
      envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
    ));
    await drainMicrotasks();

    // We should re-send our bundle so the peer (who likely missed the first
    // attempt) actually receives it.
    final ourBundles = relay.sent
        .where((f) => f.envelope.first == EnvelopeTag.preKeyBundle)
        .toList();
    expect(ourBundles.length, 2);
  });

  test('openChat sends bundle once and does not send any message', () async {
    await service.openChat(peerPub);
    await service.openChat(peerPub); // idempotent

    expect(relay.sent.length, 1);
    expect(relay.sent.first.envelope.first, EnvelopeTag.preKeyBundle);
    expect(crypto.encryptCalls, 0);

    // ensureChat was called so the chat row exists.
    final chats = await dao.watchChats().first;
    expect(chats.length, 1);
    expect(chats.first.chatId, peerPub);
  });

  group('wake fallback on recipient_offline (T6)', () {
    late _FakeWakeClient wake;
    late MessageService wakeService;

    Future<void> setUpWith(WakeResult Function() respond) async {
      // Tear down the default setUp's service first so we can attach a wake.
      await service.dispose();
      wake = _FakeWakeClient(respond);
      wakeService = MessageService(
        crypto: crypto,
        relay: relay,
        dao: dao,
        peerBundleDao: peerBundleDao,
        outboxDao: outboxDao,
        myPubkeyHex: myPub,
        wake: wake,
        groupMembersDao: groupMembersDao,
        groupOpsLogDao: groupOpsLogDao,
        signing: signing,
        contactsRepository: contactsRepo,
        profileDao: ProfileDao(db),
      );
      // After this point any inbound from `relay` flows through wakeService.
    }

    tearDown(() async {
      await wakeService.dispose();
    });

    /// Drive the bootstrap so a libsignal "session" exists from the
    /// FakeCrypto perspective and the next sendText goes through
    /// _encryptAndSend (i.e. pushes onto _unackedByPeer).
    Future<void> bootstrap() async {
      relay.emit(DeliverFrame(
        fromPubkeyHex: peerPub,
        envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
      ));
      await drainMicrotasks();
    }

    test('recipient_offline fires wake unconditionally (empty envelope)',
        () async {
      // Spec §7m — Phase 10.4.3b drops the in-flight gate. Server-side queue
      // (10.4.3a) holds the actual envelope; client wake is a marker-only
      // FCM hint that fires every time, even without a matching in-flight.
      await setUpWith(() => const WakeResult(WakeStatus.ok));
      relay.emit(ErrorFrame(
        code: 'recipient_offline',
        message: '',
        toPubkeyHex: peerPub,
      ));
      await drainMicrotasks();

      expect(wake.calls, hasLength(1));
      expect(wake.calls.single.peer, peerPub);
      expect(wake.calls.single.sender, myPub);
      expect(wake.calls.single.envelope, isEmpty,
          reason: 'wake carries no payload — Layer A holds the real envelope');
    });

    test('recipient_offline fires wake after sendText too', () async {
      await setUpWith(() => const WakeResult(WakeStatus.ok));
      await bootstrap();

      await wakeService.sendText(peerPubkeyHex: peerPub, body: 'while offline');

      relay.emit(ErrorFrame(
        code: 'recipient_offline',
        message: '',
        toPubkeyHex: peerPub,
      ));
      await drainMicrotasks();

      expect(wake.calls, hasLength(1));
      expect(wake.calls.single.peer, peerPub);
      expect(wake.calls.single.envelope, isEmpty);
    });

    test('FCM error: wake is still dispatched once (status surfaced via logs)',
        () async {
      await setUpWith(() => const WakeResult(
            WakeStatus.fcmError,
            detail: 'FCM unavailable',
          ));
      relay.emit(ErrorFrame(
        code: 'recipient_offline',
        message: '',
        toPubkeyHex: peerPub,
      ));
      await drainMicrotasks();

      expect(wake.calls, hasLength(1));
      // No retry, no exception — failure is logged structurally.
    });

    test('non-recipient_offline error does not fire wake', () async {
      await setUpWith(() => const WakeResult(WakeStatus.ok));
      relay.emit(ErrorFrame(
        code: 'some_other_error',
        message: 'whatever',
        toPubkeyHex: peerPub,
      ));
      await drainMicrotasks();

      expect(wake.calls, isEmpty);
    });
  });

  group('JSON inner envelope round-trip on 1:1 (T4.3)', () {
    /// Bootstrap: emit peer's PreKey bundle so sendText encrypts immediately.
    Future<void> bootstrap() async {
      relay.emit(DeliverFrame(
        fromPubkeyHex: peerPub,
        envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
      ));
      await drainMicrotasks();
    }

    test('A sends hello — wire carries correct JSON inner envelope', () async {
      await bootstrap();

      // A sends 'hello'. FakeCrypto echoes plaintext with 0xCC prefix.
      await service.sendText(peerPubkeyHex: peerPub, body: 'hello');

      final msgFrame = relay.sent
          .lastWhere((f) => f.envelope.first == EnvelopeTag.message);
      final parsedEnv = EnvelopeWire.parse(msgFrame.envelope);
      // Strip 0xCC prefix added by FakeCrypto.
      final innerBytes = parsedEnv.ciphertext!.sublist(1);
      final inner = InnerEnvelope.parse(innerBytes);
      expect(inner, isA<TextEnvelope>());
      final textInner = inner as TextEnvelope;
      expect(textInner.body, 'hello');
      // chatId is sender's own pubkey so receiver spoof guard passes.
      expect(textInner.chatId, myPub);
      expect(textInner.lamport, greaterThan(0));

      // The outbound DB row should have the raw body (display-friendly).
      final msgs = await dao.watchMessages(peerPub).first;
      expect(msgs.any((m) => m.body == 'hello' && m.senderPubkeyHex == myPub),
          isTrue);
    });

    test('B sends hi — A parses JSON and persists correct body and sender',
        () async {
      // B sends 'hi' to A. chatId = peerPub (B's own sender key) so that
      // A's spoof guard (inner.chatId == frame.fromPubkeyHex == peerPub) passes.
      final innerBytes = InnerEnvelope.buildText(
        chatId: peerPub, // sender's (B's) own pubkey
        lamport: 1,
        body: 'hi',
        msgId: 'msg-spoof-ok',
      );
      final ciphertext = [0xCC, ...innerBytes];
      final envelope = EnvelopeWire.wrapMessage(ciphertext);

      relay.emit(DeliverFrame(fromPubkeyHex: peerPub, envelope: envelope));
      await drainMicrotasks();

      final msgs = await dao.watchMessages(peerPub).first;
      expect(msgs.length, 1);
      expect(msgs.first.body, 'hi');
      expect(msgs.first.senderPubkeyHex, peerPub);
    });

    test('spoof guard: drops message with mismatched chatId', () async {
      // Attacker sends a message claiming chatId = some third party.
      final thirdParty = 'cc' * 32;
      final innerBytes = InnerEnvelope.buildText(
        chatId: thirdParty, // wrong — should be peerPub (the sender)
        lamport: 1,
        body: 'spoofed',
        msgId: 'msg-spoof-bad',
      );
      final ciphertext = [0xCC, ...innerBytes];
      final envelope = EnvelopeWire.wrapMessage(ciphertext);

      relay.emit(DeliverFrame(fromPubkeyHex: peerPub, envelope: envelope));
      await drainMicrotasks();

      // Should be silently dropped — no row in DB.
      final msgs = await dao.watchMessages(peerPub).first;
      expect(msgs.where((m) => m.body == 'spoofed'), isEmpty,
          reason: 'spoof guard must drop messages with mismatched chatId');
    });
  });

  group('inbound claimedName update (T6.1)', () {
    test('updates contacts.claimedName when contact exists', () async {
      // Seed: alice has peerPub as a contact.
      await contactsRepo.add(contact_model.Contact(
        pubkeyHex: peerPub,
        addedAt: DateTime.utc(2026, 5, 22),
      ));
      // Peer sends a text with senderDisplayName='Bobby'.
      final innerBytes = InnerEnvelope.buildText(
        chatId: peerPub, lamport: 1, body: 'hi',
        msgId: 'msg-claim-bobby-1',
        senderDisplayName: 'Bobby',
      );
      relay.emit(DeliverFrame(
        fromPubkeyHex: peerPub,
        envelope: EnvelopeWire.wrapMessage([0xCC, ...innerBytes]),
      ));
      await drainMicrotasks();

      final contacts = await contactsRepo.loadAll();
      final c = contacts.firstWhere((c) => c.pubkeyHex == peerPub);
      expect(c.claimedName, 'Bobby');
      expect(c.displayName, isNull); // never auto-populates displayName
    });

    test('drops claimedName when contact does not exist', () async {
      // No contact row for peerPub.
      final innerBytes = InnerEnvelope.buildText(
        chatId: peerPub, lamport: 1, body: 'hi',
        msgId: 'msg-claim-bobby-2',
        senderDisplayName: 'Bobby',
      );
      relay.emit(DeliverFrame(
        fromPubkeyHex: peerPub,
        envelope: EnvelopeWire.wrapMessage([0xCC, ...innerBytes]),
      ));
      await drainMicrotasks();

      final contacts = await contactsRepo.loadAll();
      // No contact for peerPub was added (the test confirms that we don't
      // create one as a side effect of the inbound).
      expect(contacts.where((c) => c.pubkeyHex == peerPub), isEmpty);
    });

    test('whitespace-only senderDisplayName does not overwrite', () async {
      await contactsRepo.add(contact_model.Contact(
        pubkeyHex: peerPub,
        addedAt: DateTime.utc(2026, 5, 22),
      ));
      // First inbound sets claimedName='old'.
      final firstInner = InnerEnvelope.buildText(
        chatId: peerPub, lamport: 1, body: 'first',
        msgId: 'msg-claim-first',
        senderDisplayName: 'old',
      );
      relay.emit(DeliverFrame(
        fromPubkeyHex: peerPub,
        envelope: EnvelopeWire.wrapMessage([0xCC, ...firstInner]),
      ));
      await drainMicrotasks();
      expect((await contactsRepo.loadAll())
              .firstWhere((c) => c.pubkeyHex == peerPub).claimedName,
          'old');

      // Second inbound with whitespace-only name should NOT overwrite.
      final secondInner = InnerEnvelope.buildText(
        chatId: peerPub, lamport: 2, body: 'second',
        msgId: 'msg-claim-second',
        senderDisplayName: '   ',
      );
      relay.emit(DeliverFrame(
        fromPubkeyHex: peerPub,
        envelope: EnvelopeWire.wrapMessage([0xCC, ...secondInner]),
      ));
      await drainMicrotasks();
      expect((await contactsRepo.loadAll())
              .firstWhere((c) => c.pubkeyHex == peerPub).claimedName,
          'old',
          reason: 'whitespace senderDisplayName must not overwrite claimedName');
    });
  });

  group('senderDisplayName in outbound envelopes (T5.2)', () {
    Future<void> bootstrap() async {
      relay.emit(DeliverFrame(
        fromPubkeyHex: peerPub,
        envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
      ));
      await drainMicrotasks();
    }

    test('sendText includes profile.displayName in the inner envelope',
        () async {
      // Seed profile with a name.
      await ProfileDao(db).setDisplayName('Alice');
      await bootstrap();

      await service.sendText(peerPubkeyHex: peerPub, body: 'hi');

      // Read the captured plaintext from FakeCrypto.
      expect(crypto.encryptedPlaintexts, isNotEmpty);
      final inner =
          InnerEnvelope.parse(crypto.encryptedPlaintexts.last) as TextEnvelope;
      expect(inner.body, 'hi');
      expect(inner.senderDisplayName, 'Alice');
    });

    test('sendText emits senderDisplayName=null when no profile row exists',
        () async {
      // No ProfileDao.setDisplayName call — profile row is absent.
      await bootstrap();

      await service.sendText(peerPubkeyHex: peerPub, body: 'hi');

      final inner =
          InnerEnvelope.parse(crypto.encryptedPlaintexts.last) as TextEnvelope;
      expect(inner.senderDisplayName, isNull);
    });
  });

  group('createGroup (T5.1)', () {
    final peerB = 'bb' * 32;
    final peerC = 'cc' * 32;

    test('fans out 2 invites with the correct toPubkeyHex when bundles present',
        () async {
      await peerBundleDao.markPeerBundleReceived(peerB);
      await peerBundleDao.markPeerBundleReceived(peerC);

      await service.createGroup(
        name: 'Family',
        memberPubkeysHex: [peerB, peerC],
      );

      // fan-out should have sent exactly 2 message envelopes (one per peer).
      // _maybeSendOwnBundle also fires, so filter to message-tagged frames.
      final msgFrames = relay.sent
          .where((f) => f.envelope.first == EnvelopeTag.message)
          .toList();
      expect(msgFrames.length, 2);
      final destinations = msgFrames.map((f) => f.to).toSet();
      expect(destinations, {peerB, peerC});
    });

    test('persists chat + member rows + group_created system message',
        () async {
      await peerBundleDao.markPeerBundleReceived(peerB);
      await peerBundleDao.markPeerBundleReceived(peerC);

      final chatId = await service.createGroup(
        name: 'Family',
        memberPubkeysHex: [peerB, peerC],
      );

      // Chat row.
      final chat = await dao.getChat(chatId);
      expect(chat, isNotNull);
      expect(chat!.kind, 'group');
      expect(chat.groupName, 'Family');
      expect(chat.creatorPubkeyHex, myPub);
      expect(chat.lastOpSeq, 1);

      // Member rows: creator + 2 invitees.
      final members = await groupMembersDao.activeMembers(chatId);
      final memberKeys = members.map((m) => m.memberPubkeyHex).toSet();
      expect(memberKeys, {myPub, peerB, peerC});

      // System message.
      final msgs = await dao.watchMessages(chatId).first;
      final sysMsg = msgs.firstWhere((m) => m.kind == 'group_created');
      expect(sysMsg.body, 'You created the group');
      expect(sysMsg.senderPubkeyHex, myPub);
      expect(sysMsg.lamport, 0);
    });

    test('rejects memberPubkeysHex.length > 7', () async {
      expect(
        () => service.createGroup(
          name: 'x',
          memberPubkeysHex: List.generate(8, (i) => 'peer$i'),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('queues invite when peer bundle not yet received, drains on arrival',
        () async {
      // peerB has no bundle yet; peerC does.
      await peerBundleDao.markPeerBundleReceived(peerC);

      await service.createGroup(
        name: 'Queued',
        memberPubkeysHex: [peerB, peerC],
      );

      // Only peerC should have received a message frame immediately.
      final msgsBefore = relay.sent
          .where((f) => f.envelope.first == EnvelopeTag.message)
          .map((f) => f.to)
          .toList();
      expect(msgsBefore.contains(peerC), isTrue);
      expect(msgsBefore.contains(peerB), isFalse,
          reason: 'peerB invite must be queued (no bundle yet)');

      // Simulate peerB's bundle arriving.
      relay.emit(DeliverFrame(
        fromPubkeyHex: peerB,
        envelope: EnvelopeWire.wrapPreKeyBundle(
          const CryptoPreKeyBundle(
            ownerPubkeyHex: '',
            registrationId: 77,
            deviceId: 1,
            preKeyId: 3,
            preKeyPublicHex: '01',
            signedPreKeyId: 4,
            signedPreKeyPublicHex: '02',
            signedPreKeySignatureHex: '03',
            identityKeyPublicHex: '04',
          ).copyWithOwner(peerB),
        ),
      ));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // After drain, peerB should now have a message frame.
      final msgsAfter = relay.sent
          .where((f) =>
              f.envelope.first == EnvelopeTag.message && f.to == peerB)
          .toList();
      expect(msgsAfter, isNotEmpty,
          reason: 'queued invite must drain when peerB bundle arrives');
    });

    test('group_invite sig field round-trips through SigningService.verify',
        () async {
      await peerBundleDao.markPeerBundleReceived(peerB);

      await service.createGroup(
        name: 'SigCheck',
        memberPubkeysHex: [peerB],
      );

      // Find the message frame sent to peerB.
      final msgFrame = relay.sent
          .lastWhere((f) =>
              f.envelope.first == EnvelopeTag.message && f.to == peerB);

      final parsedEnv = EnvelopeWire.parse(msgFrame.envelope);
      // FakeCrypto prepends 0xCC; strip it.
      final innerBytes = parsedEnv.ciphertext!.sublist(1);
      final inner = InnerEnvelope.parse(innerBytes);
      expect(inner, isA<GroupInviteEnvelope>());
      final invite = inner as GroupInviteEnvelope;

      // Rebuild the canonical bytes the same way createGroup did (omit 'sig').
      final rawJson = jsonDecode(utf8.decode(innerBytes)) as Map<String, dynamic>;
      final canonical = canonicalJsonBytes(rawJson, omit: 'sig');

      // Verify the signature using the creator's public key.
      final signerPubHex = await signing.publicKeyHex();
      final ok = await SigningService.verify(
        publicKeyHex: signerPubHex,
        message: canonical,
        signature: hexToBytes(invite.sigHex),
      );
      expect(ok, isTrue,
          reason: 'group_invite sig must verify against creator public key');
    });
  });

  group('sendGroupText (T5.2)', () {
    final peerB = 'bb' * 32;
    final peerC = 'cc' * 32;

    /// Creates a group with members {self, B, C} and marks both peers'
    /// bundles as received. Returns the chatId.
    Future<String> setUpGroup() async {
      await peerBundleDao.markPeerBundleReceived(peerB);
      await peerBundleDao.markPeerBundleReceived(peerC);
      return service.createGroup(
        name: 'TestGroup',
        memberPubkeysHex: [peerB, peerC],
      );
    }

    test('3-member group fans out 2 copies; both peers receive identical envelope bytes',
        () async {
      final gid = await setUpGroup();
      final sentBefore = relay.sent.length;

      await service.sendGroupText(chatId: gid, body: 'hello');

      final newFrames = relay.sent.skip(sentBefore).toList();
      final msgFrames = newFrames
          .where((f) => f.envelope.first == EnvelopeTag.message)
          .toList();
      expect(msgFrames.length, 2,
          reason: 'should fan out exactly 2 message envelopes (one per peer)');

      final destinations = msgFrames.map((f) => f.to).toSet();
      expect(destinations, {peerB, peerC});

      // Both copies should carry identical inner-envelope bytes with the
      // correct chatId, body, and lamport.
      int? sharedLamport;
      for (final frame in msgFrames) {
        final parsedEnv = EnvelopeWire.parse(frame.envelope);
        // FakeCrypto prepends 0xCC; strip it to get plaintext inner bytes.
        final innerBytes = parsedEnv.ciphertext!.sublist(1);
        final inner = InnerEnvelope.parse(innerBytes);
        expect(inner, isA<TextEnvelope>());
        final text = inner as TextEnvelope;
        expect(text.body, 'hello');
        expect(text.chatId, gid);
        sharedLamport ??= text.lamport;
        expect(text.lamport, sharedLamport,
            reason: 'both copies must carry the same lamport');
      }
    });

    test('per-peer encryption failure does not abort the rest of the fan-out',
        () async {
      // Create a crypto wrapper that throws for peerC but succeeds for peerB.
      final failingCrypto = _FailCryptoForPeer(crypto, failPeer: peerC);
      await service.dispose();
      service = MessageService(
        crypto: failingCrypto,
        relay: relay,
        dao: dao,
        peerBundleDao: peerBundleDao,
        outboxDao: outboxDao,
        myPubkeyHex: myPub,
        groupMembersDao: groupMembersDao,
        groupOpsLogDao: groupOpsLogDao,
        signing: signing,
        contactsRepository: contactsRepo,
        profileDao: ProfileDao(db),
      );

      final gid = await setUpGroup();
      final sentBefore = relay.sent.length;

      // Should not throw despite peerC failing.
      await service.sendGroupText(chatId: gid, body: 'partial');

      final newFrames = relay.sent.skip(sentBefore).toList();
      final msgFrames = newFrames
          .where((f) => f.envelope.first == EnvelopeTag.message)
          .toList();

      // peerB should have received 1 message envelope; peerC none.
      final bFrames = msgFrames.where((f) => f.to == peerB).toList();
      final cFrames = msgFrames.where((f) => f.to == peerC).toList();
      expect(bFrames, hasLength(1),
          reason: 'peerB should still receive the envelope');
      expect(cFrames, isEmpty,
          reason: 'peerC should not have received (encrypt threw)');

      // Local row must be persisted regardless.
      final msgs = await dao.watchMessages(gid).first;
      expect(msgs.any((m) => m.body == 'partial' && m.senderPubkeyHex == myPub),
          isTrue,
          reason: "sender's local row must persist even when fan-out partially fails");
    });

    test('peer without bundle yet queues envelope and still persists the local row',
        () async {
      // peerB has its bundle; peerC does NOT.
      await peerBundleDao.markPeerBundleReceived(peerB);
      // Do NOT mark peerC.
      final gid = await service.createGroup(
        name: 'QueueTest',
        memberPubkeysHex: [peerB, peerC],
      );
      final sentBefore = relay.sent.length;

      await service.sendGroupText(chatId: gid, body: 'queued-msg');

      final newFrames = relay.sent.skip(sentBefore).toList();
      final msgFrames = newFrames
          .where((f) => f.envelope.first == EnvelopeTag.message)
          .toList();

      // peerB should have received a message; peerC should not.
      final cFrames = msgFrames.where((f) => f.to == peerC).toList();
      expect(cFrames, isEmpty,
          reason: 'peerC envelope must be queued, not sent');
      final bFrames = msgFrames.where((f) => f.to == peerB).toList();
      expect(bFrames, hasLength(1),
          reason: 'peerB should receive the envelope immediately');

      // Local row still persisted.
      final msgs = await dao.watchMessages(gid).first;
      expect(msgs.any((m) => m.body == 'queued-msg' && m.senderPubkeyHex == myPub),
          isTrue,
          reason: "sender's row must be persisted before the fan-out");

      // Now simulate peerC's bundle arriving — the queued envelope should drain.
      relay.emit(DeliverFrame(
        fromPubkeyHex: peerC,
        envelope: EnvelopeWire.wrapPreKeyBundle(
          const CryptoPreKeyBundle(
            ownerPubkeyHex: '',
            registrationId: 55,
            deviceId: 1,
            preKeyId: 5,
            preKeyPublicHex: '01',
            signedPreKeyId: 6,
            signedPreKeyPublicHex: '02',
            signedPreKeySignatureHex: '03',
            identityKeyPublicHex: '04',
          ).copyWithOwner(peerC),
        ),
      ));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // After drain, peerC should now have received the envelope.
      final cFramesAfter = relay.sent
          .where((f) =>
              f.envelope.first == EnvelopeTag.message && f.to == peerC)
          .toList();
      expect(cFramesAfter, isNotEmpty,
          reason: 'queued envelope must drain when peerC bundle arrives');
    });

    test('throws StateError if chat does not exist', () async {
      expect(
        () => service.sendGroupText(chatId: 'nonexistent', body: 'x'),
        throwsStateError,
      );
    });

    test('throws StateError if chat.leftAt is set', () async {
      final gid = await setUpGroup();
      await dao.setLeftAt(gid, DateTime.now());
      expect(
        () => service.sendGroupText(chatId: gid, body: 'after-leave'),
        throwsStateError,
      );
    });
  });

  group('addMemberToGroup (T5.3)', () {
    final peerB = 'bb' * 32;
    final peerC = 'cc' * 32;
    final peerD = 'dd' * 32;

    /// Creates a {self=myPub, B, C} group with bundles pre-marked for B and C.
    Future<String> setUpGroup() async {
      await peerBundleDao.markPeerBundleReceived(peerB);
      await peerBundleDao.markPeerBundleReceived(peerC);
      return service.createGroup(
        name: 'TestGroup',
        memberPubkeysHex: [peerB, peerC],
      );
    }

    test('3-member group; creator adds D; fan-out is correct', () async {
      final gid = await setUpGroup();
      await peerBundleDao.markPeerBundleReceived(peerD);

      final sentBefore = relay.sent.length;
      await service.addMemberToGroup(chatId: gid, newMemberPubkeyHex: peerD);

      // Collect only the NEW message frames produced by addMemberToGroup.
      final newMsgFrames = relay.sent
          .skip(sentBefore)
          .where((f) => f.envelope.first == EnvelopeTag.message)
          .toList();

      // Expect exactly 3: member_add to B, member_add to C, group_invite to D.
      expect(newMsgFrames.length, 3,
          reason: 'should fan out 2 member_add + 1 group_invite');

      final toB = newMsgFrames.where((f) => f.to == peerB).toList();
      final toC = newMsgFrames.where((f) => f.to == peerC).toList();
      final toD = newMsgFrames.where((f) => f.to == peerD).toList();

      expect(toB, hasLength(1), reason: 'B should receive member_add');
      expect(toC, hasLength(1), reason: 'C should receive member_add');
      expect(toD, hasLength(1), reason: 'D should receive group_invite');

      // Verify B receives a member_add.
      final bInner = InnerEnvelope.parse(
          EnvelopeWire.parse(toB.first.envelope).ciphertext!.sublist(1));
      expect(bInner, isA<MemberAddEnvelope>());
      expect((bInner as MemberAddEnvelope).target, peerD);

      // Verify C receives a member_add.
      final cInner = InnerEnvelope.parse(
          EnvelopeWire.parse(toC.first.envelope).ciphertext!.sublist(1));
      expect(cInner, isA<MemberAddEnvelope>());
      expect((cInner as MemberAddEnvelope).target, peerD);

      // Verify D receives a group_invite with joinedVia='add' and all 4 members.
      final dInner = InnerEnvelope.parse(
          EnvelopeWire.parse(toD.first.envelope).ciphertext!.sublist(1));
      expect(dInner, isA<GroupInviteEnvelope>());
      final invite = dInner as GroupInviteEnvelope;
      expect(invite.joinedVia, 'add');
      expect(invite.members, containsAll([myPub, peerB, peerC, peerD]));
      expect(invite.members.length, 4);
    });

    test('non-creator addMemberToGroup throws StateError', () async {
      // Forge a group where creator is 'X' but self (myPub) is a plain member.
      final forgedCreator = 'ee' * 32;
      final gid = 'ff' * 16; // synthetic chatId
      await dao.insertGroupChat(
        chatId: gid,
        groupName: 'ForgedGroup',
        creatorPubkeyHex: forgedCreator,
        createdAt: DateTime.now(),
        initialOpSeq: 1,
      );
      await groupMembersDao.insertMember(
        chatId: gid,
        memberPubkeyHex: myPub,
        addedByPubkeyHex: forgedCreator,
        addedAt: DateTime.now(),
      );

      expect(
        () => service.addMemberToGroup(chatId: gid, newMemberPubkeyHex: peerD),
        throwsStateError,
      );
    });

    test('addMemberToGroup persists local state correctly', () async {
      final gid = await setUpGroup();
      await peerBundleDao.markPeerBundleReceived(peerD);

      final chatBefore = await dao.getChat(gid);
      final oldOpSeq = chatBefore!.lastOpSeq;

      await service.addMemberToGroup(chatId: gid, newMemberPubkeyHex: peerD);

      // D is now an active member.
      final members = await groupMembersDao.activeMembers(gid);
      final memberKeys = members.map((m) => m.memberPubkeyHex).toSet();
      expect(memberKeys, contains(peerD));

      // lastOpSeq bumped by 1.
      final chatAfter = await dao.getChat(gid);
      expect(chatAfter!.lastOpSeq, oldOpSeq + 1);

      // A member_add system message was inserted.
      final msgs = await dao.watchMessages(gid).first;
      final addMsg = msgs.where((m) => m.kind == 'member_add').toList();
      expect(addMsg, hasLength(1));
      expect(addMsg.first.senderPubkeyHex, myPub);
      expect(addMsg.first.body, contains(_shortPub(peerD)));
    });

    test('group_ops_log records both ops with applied=true', () async {
      final gid = await setUpGroup();
      await peerBundleDao.markPeerBundleReceived(peerD);

      await service.addMemberToGroup(chatId: gid, newMemberPubkeyHex: peerD);

      final ops = await groupOpsLogDao.forChat(gid);
      // The first op (from createGroup) is 'create'; then we add 'add' + 'create'.
      final addOps = ops.where((o) => o.kind == 'add').toList();
      final createOps = ops.where((o) => o.kind == 'create').toList();

      expect(addOps, hasLength(1), reason: 'should have one add op');
      expect(addOps.first.applied, isTrue);
      expect(addOps.first.targetPubkeyHex, peerD);

      // Two create-kind entries total: the original createGroup + the invite for D.
      expect(createOps.length, greaterThanOrEqualTo(1));
      final inviteOp = createOps.lastWhere((o) => o.targetPubkeyHex == peerD);
      expect(inviteOp.applied, isTrue);
    });

    test('adding 9th member throws ArgumentError', () async {
      // Build a group already at 8 members (self + 7 others).
      final others = List.generate(7, (i) => i.toRadixString(16).padLeft(2, '0') * 32);
      for (final p in others) {
        await peerBundleDao.markPeerBundleReceived(p);
      }
      final gid = await service.createGroup(
        name: 'FullGroup',
        memberPubkeysHex: others,
      );

      // activeBefore.length == 8 → adding one more should throw.
      await expectLater(
        () => service.addMemberToGroup(chatId: gid, newMemberPubkeyHex: peerD),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('adding an already-active member throws ArgumentError', () async {
      final gid = await setUpGroup();

      // peerB is already an active member.
      await expectLater(
        () => service.addMemberToGroup(chatId: gid, newMemberPubkeyHex: peerB),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('removeMemberFromGroup (T5.4)', () {
    final peerB = 'bb' * 32;
    final peerC = 'cc' * 32;
    final peerD = 'dd' * 32;

    /// Creates a {self=myPub, B, C} group with bundles pre-marked for B and C.
    Future<String> setUpGroup() async {
      await peerBundleDao.markPeerBundleReceived(peerB);
      await peerBundleDao.markPeerBundleReceived(peerC);
      return service.createGroup(
        name: 'TestGroup',
        memberPubkeysHex: [peerB, peerC],
      );
    }

    test('3-member group; creator removes C; fan-out is correct (incl. target)',
        () async {
      final gid = await setUpGroup();
      final chatBefore = await dao.getChat(gid);
      final oldOpSeq = chatBefore!.lastOpSeq;

      final sentBefore = relay.sent.length;
      await service.removeMemberFromGroup(
          chatId: gid, targetPubkeyHex: peerC);

      // Collect only the NEW message frames produced by removeMemberFromGroup.
      final newMsgFrames = relay.sent
          .skip(sentBefore)
          .where((f) => f.envelope.first == EnvelopeTag.message)
          .toList();

      // Expect exactly 2: member_remove to B AND to C (the target).
      expect(newMsgFrames.length, 2,
          reason: 'should fan out member_remove to every member except self, '
              'including the target');

      final toB = newMsgFrames.where((f) => f.to == peerB).toList();
      final toC = newMsgFrames.where((f) => f.to == peerC).toList();

      expect(toB, hasLength(1), reason: 'B should receive member_remove');
      expect(toC, hasLength(1),
          reason: 'target C should also receive member_remove so its UI locks');

      // Decode both inner envelopes — they should be MemberRemoveEnvelope with
      // target == peerC and opSeq == oldOpSeq + 1.
      final bInner = InnerEnvelope.parse(
          EnvelopeWire.parse(toB.first.envelope).ciphertext!.sublist(1));
      expect(bInner, isA<MemberRemoveEnvelope>());
      expect((bInner as MemberRemoveEnvelope).target, peerC);
      expect(bInner.opSeq, oldOpSeq + 1);

      final cInner = InnerEnvelope.parse(
          EnvelopeWire.parse(toC.first.envelope).ciphertext!.sublist(1));
      expect(cInner, isA<MemberRemoveEnvelope>());
      expect((cInner as MemberRemoveEnvelope).target, peerC);
      expect(cInner.opSeq, oldOpSeq + 1);
    });

    test('removeMemberFromGroup persists local state correctly', () async {
      final gid = await setUpGroup();
      final chatBefore = await dao.getChat(gid);
      final oldOpSeq = chatBefore!.lastOpSeq;

      await service.removeMemberFromGroup(
          chatId: gid, targetPubkeyHex: peerC);

      // C is no longer an active member.
      final active = await groupMembersDao.activeMembers(gid);
      final activeKeys = active.map((m) => m.memberPubkeyHex).toSet();
      expect(activeKeys, isNot(contains(peerC)));

      // C's row exists with removedAt non-null.
      final all = await groupMembersDao.allMembers(gid);
      final cRow = all.firstWhere((m) => m.memberPubkeyHex == peerC);
      expect(cRow.removedAt, isNotNull);

      // lastOpSeq bumped by 1.
      final chatAfter = await dao.getChat(gid);
      expect(chatAfter!.lastOpSeq, oldOpSeq + 1);

      // A member_remove system message was inserted.
      final msgs = await dao.watchMessages(gid).first;
      final removeMsg = msgs.where((m) => m.kind == 'member_remove').toList();
      expect(removeMsg, hasLength(1));
      expect(removeMsg.first.senderPubkeyHex, myPub);
      expect(removeMsg.first.body, contains(_shortPub(peerC)));
    });

    test('group_ops_log records remove op with applied=true', () async {
      final gid = await setUpGroup();
      final chatBefore = await dao.getChat(gid);
      final oldOpSeq = chatBefore!.lastOpSeq;

      await service.removeMemberFromGroup(
          chatId: gid, targetPubkeyHex: peerC);

      final ops = await groupOpsLogDao.forChat(gid);
      final removeOps = ops.where((o) => o.kind == 'remove').toList();

      expect(removeOps, hasLength(1));
      expect(removeOps.first.applied, isTrue);
      expect(removeOps.first.targetPubkeyHex, peerC);
      expect(removeOps.first.signerPubkeyHex, myPub);
      expect(removeOps.first.opSeq, oldOpSeq + 1);
    });

    test('member_remove sig field round-trips through SigningService.verify',
        () async {
      final gid = await setUpGroup();

      await service.removeMemberFromGroup(
          chatId: gid, targetPubkeyHex: peerC);

      // Pick any of the two member_remove frames (use the one to B).
      final msgFrame = relay.sent.lastWhere((f) =>
          f.envelope.first == EnvelopeTag.message && f.to == peerB);

      final parsedEnv = EnvelopeWire.parse(msgFrame.envelope);
      // FakeCrypto prepends 0xCC; strip it.
      final innerBytes = parsedEnv.ciphertext!.sublist(1);
      final inner = InnerEnvelope.parse(innerBytes);
      expect(inner, isA<MemberRemoveEnvelope>());
      final remove = inner as MemberRemoveEnvelope;

      // Rebuild the canonical bytes from the inner envelope JSON (omit 'sig').
      final rawJson = jsonDecode(utf8.decode(innerBytes)) as Map<String, dynamic>;
      final canonical = canonicalJsonBytes(rawJson, omit: 'sig');

      final signerPubHex = await signing.publicKeyHex();
      final ok = await SigningService.verify(
        publicKeyHex: signerPubHex,
        message: canonical,
        signature: hexToBytes(remove.sigHex),
      );
      expect(ok, isTrue,
          reason: 'member_remove sig must verify against creator public key');
    });

    test('non-creator removeMemberFromGroup throws StateError', () async {
      // Forge a group where creator is 'X' but self (myPub) is a plain member.
      final forgedCreator = 'ee' * 32;
      final gid = 'ff' * 16; // synthetic chatId
      await dao.insertGroupChat(
        chatId: gid,
        groupName: 'ForgedGroup',
        creatorPubkeyHex: forgedCreator,
        createdAt: DateTime.now(),
        initialOpSeq: 1,
      );
      await groupMembersDao.insertMember(
        chatId: gid,
        memberPubkeyHex: myPub,
        addedByPubkeyHex: forgedCreator,
        addedAt: DateTime.now(),
      );
      await groupMembersDao.insertMember(
        chatId: gid,
        memberPubkeyHex: peerB,
        addedByPubkeyHex: forgedCreator,
        addedAt: DateTime.now(),
      );

      expect(
        () =>
            service.removeMemberFromGroup(chatId: gid, targetPubkeyHex: peerB),
        throwsStateError,
      );
    });

    test('removing a non-member throws ArgumentError', () async {
      final gid = await setUpGroup();

      // peerD was never added.
      await expectLater(
        () =>
            service.removeMemberFromGroup(chatId: gid, targetPubkeyHex: peerD),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('removing an already-removed member throws ArgumentError', () async {
      final gid = await setUpGroup();

      // First remove succeeds.
      await service.removeMemberFromGroup(
          chatId: gid, targetPubkeyHex: peerC);

      // Second remove of the same member must throw.
      await expectLater(
        () =>
            service.removeMemberFromGroup(chatId: gid, targetPubkeyHex: peerC),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('leaveGroup (T5.5)', () {
    final peerB = 'bb' * 32;
    final peerC = 'cc' * 32;

    /// Creates a {self=myPub, B, C} group with bundles pre-marked for B and C.
    Future<String> setUpGroup() async {
      await peerBundleDao.markPeerBundleReceived(peerB);
      await peerBundleDao.markPeerBundleReceived(peerC);
      return service.createGroup(
        name: 'TestGroup',
        memberPubkeysHex: [peerB, peerC],
      );
    }

    test('3-member group; self leaves → fan-out to B and C only', () async {
      final gid = await setUpGroup();
      final before = DateTime.now();

      final sentBefore = relay.sent.length;
      await service.leaveGroup(chatId: gid);

      // Collect only the NEW message frames produced by leaveGroup.
      final newMsgFrames = relay.sent
          .skip(sentBefore)
          .where((f) => f.envelope.first == EnvelopeTag.message)
          .toList();

      expect(newMsgFrames.length, 2,
          reason: 'should fan out member_leave to every active member except self');

      final toB = newMsgFrames.where((f) => f.to == peerB).toList();
      final toC = newMsgFrames.where((f) => f.to == peerC).toList();
      expect(toB, hasLength(1));
      expect(toC, hasLength(1));

      // Each inner envelope should be MemberLeaveEnvelope with matching chatId,
      // leftAt close to now, and a non-empty sigHex.
      for (final f in newMsgFrames) {
        final inner = InnerEnvelope.parse(
            EnvelopeWire.parse(f.envelope).ciphertext!.sublist(1));
        expect(inner, isA<MemberLeaveEnvelope>());
        final leave = inner as MemberLeaveEnvelope;
        expect(leave.chatId, gid);
        expect(leave.sigHex, isNotEmpty);
        // leftAt is within a few seconds of "before".
        final delta = leave.leftAt.toUtc().difference(before.toUtc()).abs();
        expect(delta.inSeconds, lessThan(10));
      }
    });

    test('leaveGroup persists local state correctly', () async {
      final gid = await setUpGroup();

      await service.leaveGroup(chatId: gid);

      // chats.leftAt is set.
      final chatAfter = await dao.getChat(gid);
      expect(chatAfter!.leftAt, isNotNull);

      // self's group_members row has removedAt non-null and self is no longer
      // an active member.
      final all = await groupMembersDao.allMembers(gid);
      final selfRow = all.firstWhere((m) => m.memberPubkeyHex == myPub);
      expect(selfRow.removedAt, isNotNull);
      final active = await groupMembersDao.activeMembers(gid);
      expect(active.map((m) => m.memberPubkeyHex), isNot(contains(myPub)));

      // A member_leave system message with body == 'You left' exists.
      final msgs = await dao.watchMessages(gid).first;
      final leaveMsgs = msgs.where((m) => m.kind == 'member_leave').toList();
      expect(leaveMsgs, hasLength(1));
      expect(leaveMsgs.first.senderPubkeyHex, myPub);
      expect(leaveMsgs.first.body, 'You left');
    });

    test('group_ops_log records leave op with opSeq=null, applied=true',
        () async {
      final gid = await setUpGroup();

      await service.leaveGroup(chatId: gid);

      final ops = await groupOpsLogDao.forChat(gid);
      final leaveOps = ops.where((o) => o.kind == 'leave').toList();

      expect(leaveOps, hasLength(1));
      expect(leaveOps.first.applied, isTrue);
      expect(leaveOps.first.targetPubkeyHex, isNull);
      expect(leaveOps.first.signerPubkeyHex, myPub);
      expect(leaveOps.first.opSeq, isNull,
          reason: 'leave is lamport-ordered, no opSeq');
    });

    test('member_leave sig field round-trips through SigningService.verify',
        () async {
      final gid = await setUpGroup();

      await service.leaveGroup(chatId: gid);

      // Pick the frame to B.
      final msgFrame = relay.sent.lastWhere((f) =>
          f.envelope.first == EnvelopeTag.message && f.to == peerB);

      final parsedEnv = EnvelopeWire.parse(msgFrame.envelope);
      final innerBytes = parsedEnv.ciphertext!.sublist(1);
      final inner = InnerEnvelope.parse(innerBytes);
      expect(inner, isA<MemberLeaveEnvelope>());
      final leave = inner as MemberLeaveEnvelope;

      // Rebuild the canonical bytes from the inner envelope JSON (omit 'sig').
      final rawJson = jsonDecode(utf8.decode(innerBytes)) as Map<String, dynamic>;
      final canonical = canonicalJsonBytes(rawJson, omit: 'sig');

      final signerPubHex = await signing.publicKeyHex();
      final ok = await SigningService.verify(
        publicKeyHex: signerPubHex,
        message: canonical,
        signature: hexToBytes(leave.sigHex),
      );
      expect(ok, isTrue,
          reason: 'member_leave sig must verify against self public key');
    });

    test('calling leaveGroup twice throws StateError on second call', () async {
      final gid = await setUpGroup();

      await service.leaveGroup(chatId: gid);

      await expectLater(
        () => service.leaveGroup(chatId: gid),
        throwsStateError,
      );
    });

    test('leaveGroup on a direct chat throws StateError', () async {
      // ensureDirectChat creates a chat row with kind='direct'.
      await dao.ensureDirectChat(peerB);

      await expectLater(
        () => service.leaveGroup(chatId: peerB),
        throwsStateError,
      );
    });

    test('leaveGroup when self is not an active member throws StateError',
        () async {
      // Forge a group where self isn't a member.
      final forgedCreator = 'ee' * 32;
      final gid = 'ff' * 16;
      await dao.insertGroupChat(
        chatId: gid,
        groupName: 'ForgedGroup',
        creatorPubkeyHex: forgedCreator,
        createdAt: DateTime.now(),
        initialOpSeq: 1,
      );
      await groupMembersDao.insertMember(
        chatId: gid,
        memberPubkeyHex: forgedCreator,
        addedByPubkeyHex: forgedCreator,
        addedAt: DateTime.now(),
      );
      await groupMembersDao.insertMember(
        chatId: gid,
        memberPubkeyHex: peerB,
        addedByPubkeyHex: forgedCreator,
        addedAt: DateTime.now(),
      );

      // myPub is NOT in group_members for this group.
      await expectLater(
        () => service.leaveGroup(chatId: gid),
        throwsStateError,
      );
    });
  });

  group('handle inbound group_invite (T6.1)', () {
    // Build a signed group_invite envelope authored by [creatorSigning],
    // wrapped via EnvelopeWire.wrapMessage so it can be emitted as a
    // DeliverFrame. The FakeCrypto's decrypt strips the 0xCC prefix
    // (set fakeCryptoPrefix=true) so the receiver sees the raw inner bytes.
    Future<List<int>> buildSignedInviteEnvelope({
      required SigningService creatorSigning,
      required String creatorPub,
      required String chatId,
      required String groupName,
      required List<String> members,
      required DateTime createdAt,
      int opSeq = 1,
      String joinedVia = 'create',
      bool tamperSig = false,
    }) async {
      final canonicalBody = <String, dynamic>{
        'v': 1, 'type': 'group_invite',
        'chatId': chatId, 'lamport': 0,
        'groupName': groupName,
        'creator': creatorPub,
        'members': members,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'opSeq': opSeq,
        'joinedVia': joinedVia,
      };
      final canonical = canonicalJsonBytes(canonicalBody);
      final sigBytes = await creatorSigning.sign(canonical);
      var sigHex = bytesToHex(sigBytes);
      if (tamperSig) {
        // Flip one byte in the signature so verify rejects it.
        final mutable = List<int>.from(sigBytes);
        mutable[0] = mutable[0] ^ 0xFF;
        sigHex = bytesToHex(mutable);
      }
      final inviteBytes = InnerEnvelope.buildGroupInvite(
        chatId: chatId,
        groupName: groupName,
        creator: creatorPub,
        members: members,
        createdAt: createdAt,
        opSeq: opSeq,
        joinedVia: joinedVia,
        sigHex: sigHex,
      );
      // FakeCrypto decrypts by stripping a leading 0xCC; prepend it so the
      // receiver's crypto.decrypt yields the JSON bytes back.
      final ciphertext = [0xCC, ...inviteBytes];
      return EnvelopeWire.wrapMessage(ciphertext);
    }

    test('valid invite from a contact-creator persists chat + members + '
        'system row + ops log row', () async {
      // A is the inviter; we (myPub) are the receiver.
      final creatorSigning = await makeSigningService();
      final creatorPub = await creatorSigning.publicKeyHex();
      await contactsRepo.add(contact_model.Contact(
        pubkeyHex: creatorPub,
        addedAt: DateTime.now(),
      ));

      final chatId = 'ab' * 16;
      final members = [creatorPub, myPub, 'cc' * 32];
      final createdAt = DateTime.utc(2026, 5, 21, 12, 0, 0);
      final envelope = await buildSignedInviteEnvelope(
        creatorSigning: creatorSigning,
        creatorPub: creatorPub,
        chatId: chatId,
        groupName: 'Welcome Group',
        members: members,
        createdAt: createdAt,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: creatorPub, envelope: envelope));
      await drainMicrotasks();

      // chats row.
      final chat = await dao.getChat(chatId);
      expect(chat, isNotNull);
      expect(chat!.kind, 'group');
      expect(chat.groupName, 'Welcome Group');
      expect(chat.creatorPubkeyHex, creatorPub);
      expect(chat.lastOpSeq, 1);

      // group_members rows for every member in the invite.
      final activeMembers = await groupMembersDao.activeMembers(chatId);
      final memberKeys = activeMembers.map((m) => m.memberPubkeyHex).toSet();
      expect(memberKeys, members.toSet());

      // system 'group_created' message with sender = creator.
      final msgs = await dao.watchMessages(chatId).first;
      final sysMsg = msgs.firstWhere((m) => m.kind == 'group_created');
      expect(sysMsg.senderPubkeyHex, creatorPub);
      expect(sysMsg.body, contains(_shortPub(creatorPub)));

      // ops_log entry applied=true.
      final ops = await groupOpsLogDao.forChat(chatId);
      expect(ops, hasLength(1));
      expect(ops.first.applied, isTrue);
      expect(ops.first.kind, 'create');
      expect(ops.first.signerPubkeyHex, creatorPub);
    });

    test('tampered sig → dropped; chat NOT persisted; ops_log applied=false',
        () async {
      final creatorSigning = await makeSigningService();
      final creatorPub = await creatorSigning.publicKeyHex();
      await contactsRepo.add(contact_model.Contact(
        pubkeyHex: creatorPub,
        addedAt: DateTime.now(),
      ));

      final chatId = 'ab' * 16;
      final envelope = await buildSignedInviteEnvelope(
        creatorSigning: creatorSigning,
        creatorPub: creatorPub,
        chatId: chatId,
        groupName: 'Bad Sig',
        members: [creatorPub, myPub],
        createdAt: DateTime.utc(2026, 5, 21),
        tamperSig: true,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: creatorPub, envelope: envelope));
      await drainMicrotasks();

      expect(await dao.getChat(chatId), isNull,
          reason: 'sig-fail invites must not persist a chat row');
      final activeMembers = await groupMembersDao.activeMembers(chatId);
      expect(activeMembers, isEmpty,
          reason: 'sig-fail invites must not insert group_members');
      final ops = await groupOpsLogDao.forChat(chatId);
      expect(ops, hasLength(1));
      expect(ops.first.applied, isFalse,
          reason: 'sig-fail must record an applied=false ops_log entry');
    });

    test('creator not in contacts → dropped; no ops_log row', () async {
      final creatorSigning = await makeSigningService();
      final creatorPub = await creatorSigning.publicKeyHex();
      // Do NOT seed contactsRepo.

      final chatId = 'ab' * 16;
      final envelope = await buildSignedInviteEnvelope(
        creatorSigning: creatorSigning,
        creatorPub: creatorPub,
        chatId: chatId,
        groupName: 'Stranger',
        members: [creatorPub, myPub],
        createdAt: DateTime.utc(2026, 5, 21),
      );
      relay.emit(DeliverFrame(fromPubkeyHex: creatorPub, envelope: envelope));
      await drainMicrotasks();

      expect(await dao.getChat(chatId), isNull);
      final ops = await groupOpsLogDao.forChat(chatId);
      expect(ops, isEmpty,
          reason: 'non-sig verification failures must not log to ops_log');
    });

    test('members.length > 8 → dropped; no ops_log row', () async {
      final creatorSigning = await makeSigningService();
      final creatorPub = await creatorSigning.publicKeyHex();
      await contactsRepo.add(contact_model.Contact(
        pubkeyHex: creatorPub,
        addedAt: DateTime.now(),
      ));

      // Build 9 members including creator + self.
      final extras = List.generate(
          7, (i) => (i + 1).toRadixString(16).padLeft(2, '0') * 32);
      final members = [creatorPub, myPub, ...extras];
      expect(members.length, 9);

      final chatId = 'ab' * 16;
      final envelope = await buildSignedInviteEnvelope(
        creatorSigning: creatorSigning,
        creatorPub: creatorPub,
        chatId: chatId,
        groupName: 'Too Big',
        members: members,
        createdAt: DateTime.utc(2026, 5, 21),
      );
      relay.emit(DeliverFrame(fromPubkeyHex: creatorPub, envelope: envelope));
      await drainMicrotasks();

      expect(await dao.getChat(chatId), isNull);
      final ops = await groupOpsLogDao.forChat(chatId);
      expect(ops, isEmpty);
    });

    test('self not in members → dropped; no ops_log row', () async {
      final creatorSigning = await makeSigningService();
      final creatorPub = await creatorSigning.publicKeyHex();
      await contactsRepo.add(contact_model.Contact(
        pubkeyHex: creatorPub,
        addedAt: DateTime.now(),
      ));

      final chatId = 'ab' * 16;
      // myPub is NOT in members.
      final envelope = await buildSignedInviteEnvelope(
        creatorSigning: creatorSigning,
        creatorPub: creatorPub,
        chatId: chatId,
        groupName: 'Not Me',
        members: [creatorPub, 'cc' * 32, 'dd' * 32],
        createdAt: DateTime.utc(2026, 5, 21),
      );
      relay.emit(DeliverFrame(fromPubkeyHex: creatorPub, envelope: envelope));
      await drainMicrotasks();

      expect(await dao.getChat(chatId), isNull);
      final ops = await groupOpsLogDao.forChat(chatId);
      expect(ops, isEmpty);
    });

    test('duplicate invite → no second chat row; ops_log gets second '
        'applied=true entry', () async {
      final creatorSigning = await makeSigningService();
      final creatorPub = await creatorSigning.publicKeyHex();
      await contactsRepo.add(contact_model.Contact(
        pubkeyHex: creatorPub,
        addedAt: DateTime.now(),
      ));

      final chatId = 'ab' * 16;
      final members = [creatorPub, myPub];
      final createdAt = DateTime.utc(2026, 5, 21);

      Future<void> emitOnce() async {
        final envelope = await buildSignedInviteEnvelope(
          creatorSigning: creatorSigning,
          creatorPub: creatorPub,
          chatId: chatId,
          groupName: 'Dup',
          members: members,
          createdAt: createdAt,
        );
        relay.emit(DeliverFrame(fromPubkeyHex: creatorPub, envelope: envelope));
        await drainMicrotasks();
      }

      await emitOnce();
      await emitOnce();

      // Still exactly one chat row.
      final chat = await dao.getChat(chatId);
      expect(chat, isNotNull);
      // Members not duplicated either.
      final activeMembers = await groupMembersDao.activeMembers(chatId);
      expect(activeMembers.map((m) => m.memberPubkeyHex).toSet(),
          members.toSet());
      // ops_log records the second invite.
      final ops = await groupOpsLogDao.forChat(chatId);
      expect(ops, hasLength(2),
          reason: 'second invite should append a second ops_log entry');
      expect(ops.every((o) => o.applied), isTrue);
    });
  });

  group('handle inbound group text (T6.2)', () {
    /// Build a `text` envelope wrapped via EnvelopeWire.wrapMessage so it can
    /// be emitted as a DeliverFrame. FakeCrypto strips the 0xCC prefix on
    /// decrypt, so we prepend it to mimic ciphertext.
    List<int> buildTextEnvelope({
      required String chatId,
      required int lamport,
      required String body,
    }) {
      final innerBytes = InnerEnvelope.buildText(
        chatId: chatId,
        lamport: lamport,
        body: body,
        msgId: 'msg-group-text-$chatId-$lamport',
      );
      final ciphertext = [0xCC, ...innerBytes];
      return EnvelopeWire.wrapMessage(ciphertext);
    }

    /// Seed a group chat where [myPub] is a member and [memberA] is an active
    /// member. The chat is keyed by [chatId].
    Future<void> seedGroupWithMemberA({
      required String chatId,
      required String memberA,
    }) async {
      final createdAt = DateTime.utc(2026, 5, 21);
      await dao.insertGroupChat(
        chatId: chatId,
        groupName: 'Test Group',
        creatorPubkeyHex: memberA,
        createdAt: createdAt,
        initialOpSeq: 1,
      );
      await groupMembersDao.insertMember(
        chatId: chatId,
        memberPubkeyHex: memberA,
        addedByPubkeyHex: memberA,
        addedAt: createdAt,
      );
      await groupMembersDao.insertMember(
        chatId: chatId,
        memberPubkeyHex: myPub,
        addedByPubkeyHex: memberA,
        addedAt: createdAt,
      );
    }

    test('group text from an active member is persisted under the group chat',
        () async {
      final memberA = 'a1' * 32;
      final chatId = 'cd' * 16;
      await seedGroupWithMemberA(chatId: chatId, memberA: memberA);

      final envelope = buildTextEnvelope(
        chatId: chatId,
        lamport: 1,
        body: 'hello group',
      );
      relay.emit(DeliverFrame(fromPubkeyHex: memberA, envelope: envelope));
      await drainMicrotasks();

      final msgs = await dao.watchMessages(chatId).first;
      final textRows = msgs.where((m) => m.kind == 'text').toList();
      expect(textRows, hasLength(1));
      expect(textRows.first.chatId, chatId);
      expect(textRows.first.senderPubkeyHex, memberA);
      expect(textRows.first.body, 'hello group');

      final chat = await dao.getChat(chatId);
      expect(chat, isNotNull);
      // T8.1: group-tile preview is prefixed with `<short(sender)>: ` so the
      // chat list shows who's talking. _short in MessageService is 6/6.
      expect(
        chat!.lastMessagePreview,
        '${memberA.substring(0, 6)}…${memberA.substring(memberA.length - 6)}: hello group',
      );
    });

    test('group text from a removed member is dropped', () async {
      final memberA = 'a2' * 32;
      final chatId = 'ce' * 16;
      await seedGroupWithMemberA(chatId: chatId, memberA: memberA);
      // Remove A from the group BEFORE the text arrives.
      await groupMembersDao.markRemoved(
        chatId: chatId,
        memberPubkeyHex: memberA,
        removedAt: DateTime.utc(2026, 5, 21, 1),
      );

      final envelope = buildTextEnvelope(
        chatId: chatId,
        lamport: 1,
        body: 'sneaky',
      );
      relay.emit(DeliverFrame(fromPubkeyHex: memberA, envelope: envelope));
      await drainMicrotasks();

      final msgs = await dao.watchMessages(chatId).first;
      expect(msgs.where((m) => m.senderPubkeyHex == memberA && m.kind == 'text'),
          isEmpty,
          reason: 'removed members must not be able to inject group messages');
    });

    test('group text claiming an unknown chatId is dropped', () async {
      final memberA = 'a3' * 32;
      final unknownChatId = 'ef' * 16;
      // Do NOT seed any chat row for unknownChatId.

      final envelope = buildTextEnvelope(
        chatId: unknownChatId,
        lamport: 1,
        body: 'phantom',
      );
      relay.emit(DeliverFrame(fromPubkeyHex: memberA, envelope: envelope));
      await drainMicrotasks();

      // No chat row for unknownChatId got created.
      expect(await dao.getChat(unknownChatId), isNull);
      // No message row attributed to the unknown chat.
      final msgs = await dao.watchMessages(unknownChatId).first;
      expect(msgs, isEmpty);
    });

    test('direct-chat spoof guard: text claiming a different existing direct '
        'chat is dropped', () async {
      // Two direct chats pre-seeded: one with peerA (the actual sender) and
      // one with peerB (the spoof target). Sender = peerA, but inner.chatId
      // claims peerB. Should be dropped by the direct kind == 'direct' guard.
      final peerA = 'a4' * 32;
      final peerB = 'b4' * 32;
      await dao.ensureDirectChat(peerA);
      await dao.ensureDirectChat(peerB);

      final envelope = buildTextEnvelope(
        chatId: peerB, // wrong — should be peerA (the actual sender)
        lamport: 1,
        body: 'spoof',
      );
      relay.emit(DeliverFrame(fromPubkeyHex: peerA, envelope: envelope));
      await drainMicrotasks();

      // The spoofed-target chat must NOT receive a message row.
      final msgsB = await dao.watchMessages(peerB).first;
      expect(msgsB.where((m) => m.body == 'spoof'), isEmpty,
          reason: 'spoof must not write to the claimed direct chat');
      // The sender's actual chat must also NOT receive this message (we
      // dropped before insert), only the auto-created chat row exists.
      final msgsA = await dao.watchMessages(peerA).first;
      expect(msgsA.where((m) => m.body == 'spoof'), isEmpty);
    });

    test('direct text happy path still works (T4.2 regression)', () async {
      // peerA sends a text addressed to its own chat (chatId == sender).
      final peerA = 'a5' * 32;
      // No need to pre-seed — `_handleDeliver` calls `ensureDirectChat`
      // on EVERY inbound deliver, which creates the chat row before the
      // text branch runs.
      final envelope = buildTextEnvelope(
        chatId: peerA,
        lamport: 1,
        body: 'hello direct',
      );
      relay.emit(DeliverFrame(fromPubkeyHex: peerA, envelope: envelope));
      await drainMicrotasks();

      final msgs = await dao.watchMessages(peerA).first;
      expect(msgs, hasLength(1));
      expect(msgs.first.chatId, peerA);
      expect(msgs.first.senderPubkeyHex, peerA);
      expect(msgs.first.body, 'hello direct');
    });
  });

  group('handle inbound member_add (T6.3)', () {
    /// Seed a group chat where `creator` is the group creator and self
    /// ([myPub]) is a pre-seeded member iff [seedSelfAsMember]. Returns the
    /// creator's pubkey + SigningService so the test can synthesize signed
    /// envelopes. The chat starts at [initialOpSeq].
    Future<({String chatId, String creator, SigningService creatorSigning})>
        setupReceivedGroup({
      required int initialOpSeq,
      bool seedSelfAsMember = true,
    }) async {
      final creatorSigning = await makeSigningService();
      final creator = await creatorSigning.publicKeyHex();
      await contactsRepo.add(contact_model.Contact(
        pubkeyHex: creator,
        addedAt: DateTime.now(),
      ));
      final chatId = '11' * 16; // synthetic
      final createdAt = DateTime.utc(2026, 5, 21);
      await dao.insertGroupChat(
        chatId: chatId,
        groupName: 'TestG',
        creatorPubkeyHex: creator,
        createdAt: createdAt,
        initialOpSeq: initialOpSeq,
      );
      await groupMembersDao.insertMember(
        chatId: chatId,
        memberPubkeyHex: creator,
        addedByPubkeyHex: creator,
        addedAt: createdAt,
      );
      if (seedSelfAsMember) {
        await groupMembersDao.insertMember(
          chatId: chatId,
          memberPubkeyHex: myPub,
          addedByPubkeyHex: creator,
          addedAt: createdAt,
        );
      }
      return (chatId: chatId, creator: creator, creatorSigning: creatorSigning);
    }

    /// Build a libsignal-decrypted-and-then-pseudo-encrypted member_add
    /// envelope wrapped in [EnvelopeWire.wrapMessage]. The FakeCrypto's
    /// `decrypt` strips a leading 0xCC so the receiver gets the raw JSON
    /// inner bytes.
    Future<List<int>> buildSignedMemberAddEnvelope({
      required SigningService creatorSigning,
      required String chatId,
      required String target,
      required DateTime addedAt,
      required int opSeq,
      int lamport = 1,
      bool tamperSig = false,
    }) async {
      final canonicalBody = <String, dynamic>{
        'v': 1, 'type': 'member_add',
        'chatId': chatId, 'lamport': lamport,
        'target': target,
        'addedAt': addedAt.toUtc().toIso8601String(),
        'opSeq': opSeq,
      };
      final canonical = canonicalJsonBytes(canonicalBody);
      final sigBytes = await creatorSigning.sign(canonical);
      var sigHex = bytesToHex(sigBytes);
      if (tamperSig) {
        final mutable = List<int>.from(sigBytes);
        mutable[0] = mutable[0] ^ 0xFF;
        sigHex = bytesToHex(mutable);
      }
      final inner = InnerEnvelope.buildMemberAdd(
        chatId: chatId,
        lamport: lamport,
        target: target,
        addedAt: addedAt,
        opSeq: opSeq,
        sigHex: sigHex,
      );
      final ciphertext = [0xCC, ...inner];
      return EnvelopeWire.wrapMessage(ciphertext);
    }

    test('happy path: opSeq == last+1 → member added, lastOpSeq bumped, '
        'system row + ops_log applied=true', () async {
      final g = await setupReceivedGroup(initialOpSeq: 1);
      final newMember = '77' * 32;
      final addedAt = DateTime.utc(2026, 5, 21, 12);
      final envelope = await buildSignedMemberAddEnvelope(
        creatorSigning: g.creatorSigning,
        chatId: g.chatId,
        target: newMember,
        addedAt: addedAt,
        opSeq: 2,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: g.creator, envelope: envelope));
      await drainMicrotasks();

      // Member row added.
      final active = await groupMembersDao.activeMembers(g.chatId);
      final activeKeys = active.map((m) => m.memberPubkeyHex).toSet();
      expect(activeKeys, contains(newMember));

      // lastOpSeq bumped.
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 2);

      // System message present with both creator + target shorts, kind=member_add.
      final msgs = await dao.watchMessages(g.chatId).first;
      final sys = msgs.where((m) => m.kind == 'member_add').toList();
      expect(sys, hasLength(1));
      expect(sys.first.senderPubkeyHex, g.creator);
      expect(sys.first.body, contains(_shortPub(g.creator)));
      expect(sys.first.body, contains(_shortPub(newMember)));

      // ops_log applied=true with kind='add'.
      final ops = await groupOpsLogDao.forChat(g.chatId);
      final addOps = ops.where((o) => o.kind == 'add').toList();
      expect(addOps, hasLength(1));
      expect(addOps.first.applied, isTrue);
      expect(addOps.first.targetPubkeyHex, newMember);
      expect(addOps.first.opSeq, 2);
    });

    test('target == self → system body says "added you"', () async {
      // Don't pre-seed self so the inbound add looks like the first time we're
      // hearing about this group's new membership of us. (Add still works
      // regardless because insertMember uses insertOrIgnore; the body branch
      // is the contract under test.)
      final g = await setupReceivedGroup(
        initialOpSeq: 1,
        seedSelfAsMember: false,
      );
      final addedAt = DateTime.utc(2026, 5, 21, 12);
      final envelope = await buildSignedMemberAddEnvelope(
        creatorSigning: g.creatorSigning,
        chatId: g.chatId,
        target: myPub,
        addedAt: addedAt,
        opSeq: 2,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: g.creator, envelope: envelope));
      await drainMicrotasks();

      final msgs = await dao.watchMessages(g.chatId).first;
      final sys = msgs.where((m) => m.kind == 'member_add').toList();
      expect(sys, hasLength(1));
      expect(sys.first.body, '${_shortPub(g.creator)} added you');
    });

    test('sig fail → dropped; ops_log applied=false; no member row added',
        () async {
      final g = await setupReceivedGroup(initialOpSeq: 1);
      final newMember = '77' * 32;
      final envelope = await buildSignedMemberAddEnvelope(
        creatorSigning: g.creatorSigning,
        chatId: g.chatId,
        target: newMember,
        addedAt: DateTime.utc(2026, 5, 21, 12),
        opSeq: 2,
        tamperSig: true,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: g.creator, envelope: envelope));
      await drainMicrotasks();

      // Member row NOT added.
      final active = await groupMembersDao.activeMembers(g.chatId);
      expect(active.map((m) => m.memberPubkeyHex), isNot(contains(newMember)));

      // lastOpSeq NOT bumped.
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 1);

      // ops_log has applied=false entry.
      final ops = await groupOpsLogDao.forChat(g.chatId);
      final addOps = ops.where((o) => o.kind == 'add').toList();
      expect(addOps, hasLength(1));
      expect(addOps.first.applied, isFalse);
      expect(addOps.first.targetPubkeyHex, newMember);
    });

    test('signer is not the creator → dropped (no ops_log row)', () async {
      final g = await setupReceivedGroup(initialOpSeq: 1);
      final newMember = '77' * 32;
      // Synthesize a libsignal-session sender that isn't the creator.
      final imposter = 'ee' * 32;
      final envelope = await buildSignedMemberAddEnvelope(
        creatorSigning: g.creatorSigning,
        chatId: g.chatId,
        target: newMember,
        addedAt: DateTime.utc(2026, 5, 21, 12),
        opSeq: 2,
      );
      // frame.fromPubkeyHex = imposter, NOT the creator.
      relay.emit(DeliverFrame(fromPubkeyHex: imposter, envelope: envelope));
      await drainMicrotasks();

      // No member added.
      final active = await groupMembersDao.activeMembers(g.chatId);
      expect(active.map((m) => m.memberPubkeyHex), isNot(contains(newMember)));

      // No bump.
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 1);

      // No ops_log row for this op (sig was never checked because we bailed
      // at the signer-is-creator gate).
      final ops = await groupOpsLogDao.forChat(g.chatId);
      expect(ops.where((o) => o.kind == 'add'), isEmpty);
    });

    test('stale opSeq (<= last) → dropped; no ops_log row, no member row',
        () async {
      // Start the chat at lastOpSeq=5; send an envelope with opSeq=5.
      final g = await setupReceivedGroup(initialOpSeq: 5);
      final newMember = '77' * 32;
      final envelope = await buildSignedMemberAddEnvelope(
        creatorSigning: g.creatorSigning,
        chatId: g.chatId,
        target: newMember,
        addedAt: DateTime.utc(2026, 5, 21, 12),
        opSeq: 5,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: g.creator, envelope: envelope));
      await drainMicrotasks();

      // No member row.
      final active = await groupMembersDao.activeMembers(g.chatId);
      expect(active.map((m) => m.memberPubkeyHex), isNot(contains(newMember)));

      // lastOpSeq unchanged.
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 5);

      // No ops_log row.
      final ops = await groupOpsLogDao.forChat(g.chatId);
      expect(ops.where((o) => o.kind == 'add'), isEmpty);
    });

    test('gap opSeq (> last+1) → accepted; logs op_seq_gap', () async {
      // Start at lastOpSeq=1; send opSeq=3 (skips 2).
      final g = await setupReceivedGroup(initialOpSeq: 1);
      final newMember = '77' * 32;
      final envelope = await buildSignedMemberAddEnvelope(
        creatorSigning: g.creatorSigning,
        chatId: g.chatId,
        target: newMember,
        addedAt: DateTime.utc(2026, 5, 21, 12),
        opSeq: 3,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: g.creator, envelope: envelope));
      await drainMicrotasks();

      // Member row added.
      final active = await groupMembersDao.activeMembers(g.chatId);
      expect(active.map((m) => m.memberPubkeyHex), contains(newMember));

      // lastOpSeq jumps to 3.
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 3);

      // ops_log applied=true.
      final ops = await groupOpsLogDao.forChat(g.chatId);
      final addOps = ops.where((o) => o.kind == 'add').toList();
      expect(addOps, hasLength(1));
      expect(addOps.first.applied, isTrue);
      expect(addOps.first.opSeq, 3);
    });

    test('unknown chat → dropped', () async {
      // No setup — chat does not exist locally.
      final creatorSigning = await makeSigningService();
      final creator = await creatorSigning.publicKeyHex();
      final unknownChatId = '22' * 16;
      final newMember = '77' * 32;
      final envelope = await buildSignedMemberAddEnvelope(
        creatorSigning: creatorSigning,
        chatId: unknownChatId,
        target: newMember,
        addedAt: DateTime.utc(2026, 5, 21, 12),
        opSeq: 2,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: creator, envelope: envelope));
      await drainMicrotasks();

      // Chat still doesn't exist.
      expect(await dao.getChat(unknownChatId), isNull);
      // No ops_log rows for that chat.
      final ops = await groupOpsLogDao.forChat(unknownChatId);
      expect(ops, isEmpty);
    });
  });

  group('handle inbound member_remove (T6.4)', () {
    /// Seed a group chat where `creator` is the group creator, self ([myPub])
    /// is a pre-seeded member, and [extraMember] (if provided) is also a
    /// pre-seeded active member. Returns the creator's pubkey + SigningService
    /// so the test can synthesize signed envelopes. The chat starts at
    /// [initialOpSeq].
    Future<({String chatId, String creator, SigningService creatorSigning})>
        setupReceivedGroup({
      required int initialOpSeq,
      bool seedSelfAsMember = true,
      String? extraMember,
    }) async {
      final creatorSigning = await makeSigningService();
      final creator = await creatorSigning.publicKeyHex();
      await contactsRepo.add(contact_model.Contact(
        pubkeyHex: creator,
        addedAt: DateTime.now(),
      ));
      final chatId = '11' * 16; // synthetic
      final createdAt = DateTime.utc(2026, 5, 21);
      await dao.insertGroupChat(
        chatId: chatId,
        groupName: 'TestG',
        creatorPubkeyHex: creator,
        createdAt: createdAt,
        initialOpSeq: initialOpSeq,
      );
      await groupMembersDao.insertMember(
        chatId: chatId,
        memberPubkeyHex: creator,
        addedByPubkeyHex: creator,
        addedAt: createdAt,
      );
      if (seedSelfAsMember) {
        await groupMembersDao.insertMember(
          chatId: chatId,
          memberPubkeyHex: myPub,
          addedByPubkeyHex: creator,
          addedAt: createdAt,
        );
      }
      if (extraMember != null) {
        await groupMembersDao.insertMember(
          chatId: chatId,
          memberPubkeyHex: extraMember,
          addedByPubkeyHex: creator,
          addedAt: createdAt,
        );
      }
      return (chatId: chatId, creator: creator, creatorSigning: creatorSigning);
    }

    /// Build a libsignal-decrypted-and-then-pseudo-encrypted member_remove
    /// envelope wrapped in [EnvelopeWire.wrapMessage]. FakeCrypto's `decrypt`
    /// strips a leading 0xCC so the receiver gets the raw JSON inner bytes.
    Future<List<int>> buildSignedMemberRemoveEnvelope({
      required SigningService creatorSigning,
      required String chatId,
      required String target,
      required DateTime removedAt,
      required int opSeq,
      int lamport = 1,
      bool tamperSig = false,
    }) async {
      final canonicalBody = <String, dynamic>{
        'v': 1, 'type': 'member_remove',
        'chatId': chatId, 'lamport': lamport,
        'target': target,
        'removedAt': removedAt.toUtc().toIso8601String(),
        'opSeq': opSeq,
      };
      final canonical = canonicalJsonBytes(canonicalBody);
      final sigBytes = await creatorSigning.sign(canonical);
      var sigHex = bytesToHex(sigBytes);
      if (tamperSig) {
        final mutable = List<int>.from(sigBytes);
        mutable[0] = mutable[0] ^ 0xFF;
        sigHex = bytesToHex(mutable);
      }
      final inner = InnerEnvelope.buildMemberRemove(
        chatId: chatId,
        lamport: lamport,
        target: target,
        removedAt: removedAt,
        opSeq: opSeq,
        sigHex: sigHex,
      );
      final ciphertext = [0xCC, ...inner];
      return EnvelopeWire.wrapMessage(ciphertext);
    }

    test('happy path: creator removes a third party → member removed, '
        'lastOpSeq bumped, leftAt unset, system row + ops_log applied=true',
        () async {
      final peerC = '77' * 32;
      final g = await setupReceivedGroup(
        initialOpSeq: 1,
        extraMember: peerC,
      );
      final removedAt = DateTime.utc(2026, 5, 21, 12);
      final envelope = await buildSignedMemberRemoveEnvelope(
        creatorSigning: g.creatorSigning,
        chatId: g.chatId,
        target: peerC,
        removedAt: removedAt,
        opSeq: 2,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: g.creator, envelope: envelope));
      await drainMicrotasks();

      // peerC no longer in activeMembers, but still in allMembers.
      final active = await groupMembersDao.activeMembers(g.chatId);
      expect(active.map((m) => m.memberPubkeyHex), isNot(contains(peerC)));
      final all = await groupMembersDao.allMembers(g.chatId);
      expect(all.map((m) => m.memberPubkeyHex), contains(peerC));

      // lastOpSeq bumped; leftAt still null (self wasn't the target).
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 2);
      expect(chat.leftAt, isNull);

      // System message present with both creator + target shorts,
      // kind=member_remove.
      final msgs = await dao.watchMessages(g.chatId).first;
      final sys = msgs.where((m) => m.kind == 'member_remove').toList();
      expect(sys, hasLength(1));
      expect(sys.first.senderPubkeyHex, g.creator);
      expect(sys.first.body, contains(_shortPub(g.creator)));
      expect(sys.first.body, contains(_shortPub(peerC)));

      // ops_log applied=true with kind='remove'.
      final ops = await groupOpsLogDao.forChat(g.chatId);
      final removeOps = ops.where((o) => o.kind == 'remove').toList();
      expect(removeOps, hasLength(1));
      expect(removeOps.first.applied, isTrue);
      expect(removeOps.first.targetPubkeyHex, peerC);
      expect(removeOps.first.opSeq, 2);
    });

    test('target == self → chats.leftAt set; body is "<creator> removed you"',
        () async {
      final g = await setupReceivedGroup(initialOpSeq: 1);
      final removedAt = DateTime.utc(2026, 5, 21, 12);
      final envelope = await buildSignedMemberRemoveEnvelope(
        creatorSigning: g.creatorSigning,
        chatId: g.chatId,
        target: myPub,
        removedAt: removedAt,
        opSeq: 2,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: g.creator, envelope: envelope));
      await drainMicrotasks();

      // leftAt set, self no longer active.
      final chat = await dao.getChat(g.chatId);
      expect(chat!.leftAt, isNotNull);
      expect(await groupMembersDao.isActiveMember(g.chatId, myPub), isFalse);

      // System message body is the "removed you" branch.
      final msgs = await dao.watchMessages(g.chatId).first;
      final sys = msgs.where((m) => m.kind == 'member_remove').toList();
      expect(sys, hasLength(1));
      expect(sys.first.body, '${_shortPub(g.creator)} removed you');
    });

    test('sig fail → dropped; ops_log applied=false; target still active',
        () async {
      final peerC = '77' * 32;
      final g = await setupReceivedGroup(
        initialOpSeq: 1,
        extraMember: peerC,
      );
      final envelope = await buildSignedMemberRemoveEnvelope(
        creatorSigning: g.creatorSigning,
        chatId: g.chatId,
        target: peerC,
        removedAt: DateTime.utc(2026, 5, 21, 12),
        opSeq: 2,
        tamperSig: true,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: g.creator, envelope: envelope));
      await drainMicrotasks();

      // Target still active.
      expect(await groupMembersDao.isActiveMember(g.chatId, peerC), isTrue);

      // lastOpSeq not bumped.
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 1);
      expect(chat.leftAt, isNull);

      // ops_log applied=false.
      final ops = await groupOpsLogDao.forChat(g.chatId);
      final removeOps = ops.where((o) => o.kind == 'remove').toList();
      expect(removeOps, hasLength(1));
      expect(removeOps.first.applied, isFalse);
      expect(removeOps.first.targetPubkeyHex, peerC);
    });

    test('signer is not the creator → dropped (no ops_log row)', () async {
      final peerC = '77' * 32;
      final g = await setupReceivedGroup(
        initialOpSeq: 1,
        extraMember: peerC,
      );
      final imposter = 'ee' * 32;
      final envelope = await buildSignedMemberRemoveEnvelope(
        creatorSigning: g.creatorSigning,
        chatId: g.chatId,
        target: peerC,
        removedAt: DateTime.utc(2026, 5, 21, 12),
        opSeq: 2,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: imposter, envelope: envelope));
      await drainMicrotasks();

      // Target still active; no bump; no ops_log row.
      expect(await groupMembersDao.isActiveMember(g.chatId, peerC), isTrue);
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 1);
      final ops = await groupOpsLogDao.forChat(g.chatId);
      expect(ops.where((o) => o.kind == 'remove'), isEmpty);
    });

    test('stale opSeq (<= last) → dropped; no ops_log row; target still active',
        () async {
      final peerC = '77' * 32;
      final g = await setupReceivedGroup(
        initialOpSeq: 5,
        extraMember: peerC,
      );
      final envelope = await buildSignedMemberRemoveEnvelope(
        creatorSigning: g.creatorSigning,
        chatId: g.chatId,
        target: peerC,
        removedAt: DateTime.utc(2026, 5, 21, 12),
        opSeq: 5,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: g.creator, envelope: envelope));
      await drainMicrotasks();

      expect(await groupMembersDao.isActiveMember(g.chatId, peerC), isTrue);
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 5);
      final ops = await groupOpsLogDao.forChat(g.chatId);
      expect(ops.where((o) => o.kind == 'remove'), isEmpty);
    });

    test('gap opSeq (> last+1) → accepted; lastOpSeq jumps; ops_log applied=true',
        () async {
      final peerC = '77' * 32;
      final g = await setupReceivedGroup(
        initialOpSeq: 1,
        extraMember: peerC,
      );
      final envelope = await buildSignedMemberRemoveEnvelope(
        creatorSigning: g.creatorSigning,
        chatId: g.chatId,
        target: peerC,
        removedAt: DateTime.utc(2026, 5, 21, 12),
        opSeq: 3,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: g.creator, envelope: envelope));
      await drainMicrotasks();

      expect(await groupMembersDao.isActiveMember(g.chatId, peerC), isFalse);
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 3);
      final ops = await groupOpsLogDao.forChat(g.chatId);
      final removeOps = ops.where((o) => o.kind == 'remove').toList();
      expect(removeOps, hasLength(1));
      expect(removeOps.first.applied, isTrue);
      expect(removeOps.first.opSeq, 3);
    });

    test('unknown target (never in group_members) → dropped; no bump; no log; '
        'no member row created', () async {
      final g = await setupReceivedGroup(initialOpSeq: 1);
      final peerZ = '99' * 32; // never been a member of this chat
      final envelope = await buildSignedMemberRemoveEnvelope(
        creatorSigning: g.creatorSigning,
        chatId: g.chatId,
        target: peerZ,
        removedAt: DateTime.utc(2026, 5, 21, 12),
        opSeq: 2,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: g.creator, envelope: envelope));
      await drainMicrotasks();

      // No member row for peerZ (neither active nor removed).
      final all = await groupMembersDao.allMembers(g.chatId);
      expect(all.map((m) => m.memberPubkeyHex), isNot(contains(peerZ)));

      // No bump, no ops_log row.
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 1);
      final ops = await groupOpsLogDao.forChat(g.chatId);
      expect(ops.where((o) => o.kind == 'remove'), isEmpty);
    });

    test('unknown chat → dropped', () async {
      final creatorSigning = await makeSigningService();
      final creator = await creatorSigning.publicKeyHex();
      final unknownChatId = '22' * 16;
      final target = '77' * 32;
      final envelope = await buildSignedMemberRemoveEnvelope(
        creatorSigning: creatorSigning,
        chatId: unknownChatId,
        target: target,
        removedAt: DateTime.utc(2026, 5, 21, 12),
        opSeq: 2,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: creator, envelope: envelope));
      await drainMicrotasks();

      expect(await dao.getChat(unknownChatId), isNull);
      final ops = await groupOpsLogDao.forChat(unknownChatId);
      expect(ops, isEmpty);
    });
  });

  group('handle inbound member_leave (T6.5)', () {
    /// Seed a group chat where `creator` is the group creator, self ([myPub])
    /// is a pre-seeded member, and [leaverPub] (if provided) is also a
    /// pre-seeded active member. Returns both the creator's pubkey and
    /// (optionally) the leaver's pubkey so tests can synthesize signed
    /// leave envelopes from the leaver.
    Future<({String chatId, String creator})> setupReceivedGroup({
      required int initialOpSeq,
      bool seedSelfAsMember = true,
      String? leaverPub,
    }) async {
      final creatorSigning = await makeSigningService();
      final creator = await creatorSigning.publicKeyHex();
      await contactsRepo.add(contact_model.Contact(
        pubkeyHex: creator,
        addedAt: DateTime.now(),
      ));
      final chatId = '33' * 16; // synthetic, distinct from T6.4
      final createdAt = DateTime.utc(2026, 5, 21);
      await dao.insertGroupChat(
        chatId: chatId,
        groupName: 'TestG',
        creatorPubkeyHex: creator,
        createdAt: createdAt,
        initialOpSeq: initialOpSeq,
      );
      await groupMembersDao.insertMember(
        chatId: chatId,
        memberPubkeyHex: creator,
        addedByPubkeyHex: creator,
        addedAt: createdAt,
      );
      if (seedSelfAsMember) {
        await groupMembersDao.insertMember(
          chatId: chatId,
          memberPubkeyHex: myPub,
          addedByPubkeyHex: creator,
          addedAt: createdAt,
        );
      }
      if (leaverPub != null) {
        await groupMembersDao.insertMember(
          chatId: chatId,
          memberPubkeyHex: leaverPub,
          addedByPubkeyHex: creator,
          addedAt: createdAt,
        );
      }
      return (chatId: chatId, creator: creator);
    }

    /// Build a libsignal-decrypted-and-then-pseudo-encrypted member_leave
    /// envelope, signed under [leaverSigning] (the leaver IS the signer).
    /// FakeCrypto's `decrypt` strips a leading 0xCC so the receiver gets the
    /// raw JSON inner bytes.
    Future<List<int>> buildSignedMemberLeaveEnvelope({
      required SigningService leaverSigning,
      required String chatId,
      required DateTime leftAt,
      int lamport = 1,
      bool tamperSig = false,
    }) async {
      final canonicalBody = <String, dynamic>{
        'v': 1, 'type': 'member_leave',
        'chatId': chatId, 'lamport': lamport,
        'leftAt': leftAt.toUtc().toIso8601String(),
      };
      final canonical = canonicalJsonBytes(canonicalBody);
      final sigBytes = await leaverSigning.sign(canonical);
      var sigHex = bytesToHex(sigBytes);
      if (tamperSig) {
        final mutable = List<int>.from(sigBytes);
        mutable[0] = mutable[0] ^ 0xFF;
        sigHex = bytesToHex(mutable);
      }
      final inner = InnerEnvelope.buildMemberLeave(
        chatId: chatId,
        lamport: lamport,
        leftAt: leftAt,
        sigHex: sigHex,
      );
      final ciphertext = [0xCC, ...inner];
      return EnvelopeWire.wrapMessage(ciphertext);
    }

    test('happy path: third party leaves → member removed, lastOpSeq UNCHANGED, '
        'system row + ops_log applied=true with opSeq=null', () async {
      final leaverSigning = await makeSigningService();
      final peerC = await leaverSigning.publicKeyHex();
      final g = await setupReceivedGroup(
        initialOpSeq: 1,
        leaverPub: peerC,
      );
      final leftAt = DateTime.utc(2026, 5, 21, 12);
      final envelope = await buildSignedMemberLeaveEnvelope(
        leaverSigning: leaverSigning,
        chatId: g.chatId,
        leftAt: leftAt,
        lamport: 5,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: peerC, envelope: envelope));
      await drainMicrotasks();

      // peerC no longer active.
      expect(await groupMembersDao.isActiveMember(g.chatId, peerC), isFalse);

      // lastOpSeq UNCHANGED — leave does not bump opSeq.
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 1);

      // System message present with truncated leaver + " left", kind=member_leave.
      final msgs = await dao.watchMessages(g.chatId).first;
      final sys = msgs.where((m) => m.kind == 'member_leave').toList();
      expect(sys, hasLength(1));
      expect(sys.first.senderPubkeyHex, peerC);
      expect(sys.first.body, '${_shortPub(peerC)} left');

      // ops_log applied=true with kind='leave', opSeq=null, targetPubkeyHex=null,
      // signerPubkeyHex=peerC.
      final ops = await groupOpsLogDao.forChat(g.chatId);
      final leaveOps = ops.where((o) => o.kind == 'leave').toList();
      expect(leaveOps, hasLength(1));
      expect(leaveOps.first.applied, isTrue);
      expect(leaveOps.first.opSeq, isNull);
      expect(leaveOps.first.targetPubkeyHex, isNull);
      expect(leaveOps.first.signerPubkeyHex, peerC);
    });

    test('sig fail → dropped; ops_log applied=false; signer still active',
        () async {
      final leaverSigning = await makeSigningService();
      final peerC = await leaverSigning.publicKeyHex();
      final g = await setupReceivedGroup(
        initialOpSeq: 1,
        leaverPub: peerC,
      );
      final envelope = await buildSignedMemberLeaveEnvelope(
        leaverSigning: leaverSigning,
        chatId: g.chatId,
        leftAt: DateTime.utc(2026, 5, 21, 12),
        tamperSig: true,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: peerC, envelope: envelope));
      await drainMicrotasks();

      // Signer still active; no system message inserted.
      expect(await groupMembersDao.isActiveMember(g.chatId, peerC), isTrue);
      final msgs = await dao.watchMessages(g.chatId).first;
      expect(msgs.where((m) => m.kind == 'member_leave'), isEmpty);

      // lastOpSeq unchanged.
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 1);

      // ops_log applied=false.
      final ops = await groupOpsLogDao.forChat(g.chatId);
      final leaveOps = ops.where((o) => o.kind == 'leave').toList();
      expect(leaveOps, hasLength(1));
      expect(leaveOps.first.applied, isFalse);
      expect(leaveOps.first.opSeq, isNull);
      expect(leaveOps.first.targetPubkeyHex, isNull);
      expect(leaveOps.first.signerPubkeyHex, peerC);
    });

    test('signer is not currently an active member → dropped; '
        'no ops_log row; no state change', () async {
      // Pre-seed group {creator, myPub} only. peerC was NEVER in the group.
      final g = await setupReceivedGroup(initialOpSeq: 1);
      final leaverSigning = await makeSigningService();
      final peerC = await leaverSigning.publicKeyHex();
      final envelope = await buildSignedMemberLeaveEnvelope(
        leaverSigning: leaverSigning,
        chatId: g.chatId,
        leftAt: DateTime.utc(2026, 5, 21, 12),
      );
      relay.emit(DeliverFrame(fromPubkeyHex: peerC, envelope: envelope));
      await drainMicrotasks();

      // No member row for peerC.
      final all = await groupMembersDao.allMembers(g.chatId);
      expect(all.map((m) => m.memberPubkeyHex), isNot(contains(peerC)));

      // No system message, no ops_log row, no opSeq change.
      final msgs = await dao.watchMessages(g.chatId).first;
      expect(msgs.where((m) => m.kind == 'member_leave'), isEmpty);
      final ops = await groupOpsLogDao.forChat(g.chatId);
      expect(ops.where((o) => o.kind == 'leave'), isEmpty);
      final chat = await dao.getChat(g.chatId);
      expect(chat!.lastOpSeq, 1);
    });

    test('idempotent double-leave: second delivery is dropped (signer no longer '
        'active); only one applied=true ops_log row exists', () async {
      final leaverSigning = await makeSigningService();
      final peerC = await leaverSigning.publicKeyHex();
      final g = await setupReceivedGroup(
        initialOpSeq: 1,
        leaverPub: peerC,
      );
      final leftAt = DateTime.utc(2026, 5, 21, 12);
      final envelope = await buildSignedMemberLeaveEnvelope(
        leaverSigning: leaverSigning,
        chatId: g.chatId,
        leftAt: leftAt,
      );
      // First delivery.
      relay.emit(DeliverFrame(fromPubkeyHex: peerC, envelope: envelope));
      await drainMicrotasks();
      // Second delivery (same envelope).
      relay.emit(DeliverFrame(fromPubkeyHex: peerC, envelope: envelope));
      await drainMicrotasks();

      // peerC inactive.
      expect(await groupMembersDao.isActiveMember(g.chatId, peerC), isFalse);

      // Exactly one applied=true ops_log row for kind='leave'.
      final ops = await groupOpsLogDao.forChat(g.chatId);
      final leaveOps = ops.where((o) => o.kind == 'leave').toList();
      expect(leaveOps, hasLength(1));
      expect(leaveOps.first.applied, isTrue);

      // Exactly one system message.
      final msgs = await dao.watchMessages(g.chatId).first;
      expect(msgs.where((m) => m.kind == 'member_leave'), hasLength(1));
    });

    test('unknown chat → dropped (no ops_log row)', () async {
      final leaverSigning = await makeSigningService();
      final peerC = await leaverSigning.publicKeyHex();
      final unknownChatId = '44' * 16;
      final envelope = await buildSignedMemberLeaveEnvelope(
        leaverSigning: leaverSigning,
        chatId: unknownChatId,
        leftAt: DateTime.utc(2026, 5, 21, 12),
      );
      relay.emit(DeliverFrame(fromPubkeyHex: peerC, envelope: envelope));
      await drainMicrotasks();

      expect(await dao.getChat(unknownChatId), isNull);
      final ops = await groupOpsLogDao.forChat(unknownChatId);
      expect(ops, isEmpty);
    });

    test('lamport advances on accepted leave (participates in ordering)',
        () async {
      final leaverSigning = await makeSigningService();
      final peerC = await leaverSigning.publicKeyHex();
      final g = await setupReceivedGroup(
        initialOpSeq: 1,
        leaverPub: peerC,
      );
      final envelope = await buildSignedMemberLeaveEnvelope(
        leaverSigning: leaverSigning,
        chatId: g.chatId,
        leftAt: DateTime.utc(2026, 5, 21, 12),
        lamport: 5,
      );
      relay.emit(DeliverFrame(fromPubkeyHex: peerC, envelope: envelope));
      await drainMicrotasks();

      // After observing inv.lamport=5, the inserted message's lamport
      // should be 5 (observe semantics: max(local, incoming)).
      final msgs = await dao.watchMessages(g.chatId).first;
      final sys = msgs.where((m) => m.kind == 'member_leave').toList();
      expect(sys, hasLength(1));
      expect(sys.first.lamport, 5);
    });
  });

  group('bundle-exchange state persists across restart (T3.4)', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hb_msg_service_test_');
      dbFile = File('${tempDir.path}/hb_v3.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('session 2 over the same DB does not re-send our bundle and does not '
        're-queue messages', () async {
      // ---- Session 1: full bundle exchange ----
      final db1 = AppDatabase.forTesting(NativeDatabase(dbFile));
      final dao1 = ChatsDao(db1);
      final peerBundleDao1 = PeerBundleStateDao(db1);
      final crypto1 = _FakeCrypto();
      final relay1 = _FakeRelay();
      final service1 = MessageService(
        crypto: crypto1,
        relay: relay1,
        dao: dao1,
        peerBundleDao: peerBundleDao1,
        outboxDao: OutboxDao(db1),
        myPubkeyHex: myPub,
        groupMembersDao: GroupMembersDao(db1),
        groupOpsLogDao: GroupOpsLogDao(db1),
        signing: signing,
        contactsRepository: ContactsRepository(db1),
        profileDao: ProfileDao(db1),
      );

      await service1.openChat(peerPub);
      relay1.emit(DeliverFrame(
        fromPubkeyHex: peerPub,
        envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
      ));
      await drainMicrotasks();

      // Sanity: session 1 marked both flags in PeerBundleStateDao.
      final row1 = await peerBundleDao1.get(peerPub);
      expect(row1?.bundleSentAt, isNotNull);
      expect(row1?.peerBundleReceivedAt, isNotNull);

      await service1.dispose();
      await relay1.dispose();
      await db1.close();

      // ---- Session 2: fresh in-process objects over same DB file ----
      final db2 = AppDatabase.forTesting(NativeDatabase(dbFile));
      final dao2 = ChatsDao(db2);
      final peerBundleDao2 = PeerBundleStateDao(db2);
      final crypto2 = _FakeCrypto();
      final relay2 = _FakeRelay();
      final service2 = MessageService(
        crypto: crypto2,
        relay: relay2,
        dao: dao2,
        peerBundleDao: peerBundleDao2,
        outboxDao: OutboxDao(db2),
        myPubkeyHex: myPub,
        groupMembersDao: GroupMembersDao(db2),
        groupOpsLogDao: GroupOpsLogDao(db2),
        signing: signing,
        contactsRepository: ContactsRepository(db2),
        profileDao: ProfileDao(db2),
      );

      // openChat in session 2 must NOT emit a bundle because bundleSentAt
      // is already non-null — the whole point of T3.5.
      await service2.openChat(peerPub);
      expect(relay2.sent, isEmpty);

      // sendText must NOT queue because peerBundleReceivedAt is already non-null;
      // it should encrypt and send immediately.
      await service2.sendText(peerPubkeyHex: peerPub, body: 'after restart');
      expect(crypto2.encryptCalls, 1);
      final msgFrames = relay2.sent
          .where((f) => f.envelope.first == EnvelopeTag.message)
          .toList();
      expect(msgFrames.length, 1);

      await service2.dispose();
      await relay2.dispose();
      await db2.close();
    });
  });
}
