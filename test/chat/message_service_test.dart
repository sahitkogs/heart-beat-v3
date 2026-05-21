import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_v3/chat/group_envelope.dart';
import 'package:app_v3/chat/message_service.dart';
import 'package:app_v3/chat/pre_key_bootstrap.dart';
import 'package:app_v3/core/hex_codec.dart';
import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/chats_dao.dart';
import 'package:app_v3/data/group_members_dao.dart';
import 'package:app_v3/data/group_ops_log_dao.dart';
import 'package:app_v3/data/peer_bundle_state_dao.dart';
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
}

void main() {
  // The restart test opens two AppDatabase instances over the same file —
  // suppress drift's "multiple databases" warning so real failures stay
  // visible.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late ChatsDao dao;
  late PeerBundleStateDao peerBundleDao;
  late GroupMembersDao groupMembersDao;
  late GroupOpsLogDao groupOpsLogDao;
  late SigningService signing;
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
    groupMembersDao = GroupMembersDao(db);
    groupOpsLogDao = GroupOpsLogDao(db);
    signing = await makeSigningService();
    crypto = _FakeCrypto();
    relay = _FakeRelay();
    service = MessageService(
      crypto: crypto,
      relay: relay,
      dao: dao,
      peerBundleDao: peerBundleDao,
      myPubkeyHex: myPub,
      groupMembersDao: groupMembersDao,
      groupOpsLogDao: groupOpsLogDao,
      signing: signing,
    );
  });

  tearDown(() async {
    await service.dispose();
    await relay.dispose();
    await db.close();
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
        myPubkeyHex: myPub,
        wake: wake,
        groupMembersDao: groupMembersDao,
        groupOpsLogDao: groupOpsLogDao,
        signing: signing,
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

    test('happy path: recipient_offline triggers wake with the queued envelope',
        () async {
      await setUpWith(() => const WakeResult(WakeStatus.ok));
      await bootstrap();

      await wakeService.sendText(peerPubkeyHex: peerPub, body: 'while offline');
      final sentMessage = relay.sent
          .lastWhere((f) => f.envelope.first == EnvelopeTag.message)
          .envelope;

      // Server says peer is offline AFTER the message was already handed off.
      relay.emit(ErrorFrame(
        code: 'recipient_offline',
        message: '',
        toPubkeyHex: peerPub,
      ));
      await drainMicrotasks();

      expect(wake.calls, hasLength(1));
      expect(wake.calls.single.peer, peerPub);
      expect(wake.calls.single.sender, myPub);
      expect(wake.calls.single.envelope, sentMessage,
          reason: 'wake should carry the original encrypted envelope so the '
              'background isolate can decrypt it cold');
    });

    test('no in-flight envelope: bundle-send recipient_offline clears '
        'bundleSent and skips wake', () async {
      await setUpWith(() => const WakeResult(WakeStatus.ok));
      // openChat sends our bundle but there is no message in-flight.
      await wakeService.openChat(peerPub);

      // The bundle send sets bundleSentAt in PeerBundleStateDao.
      final stateBefore = await peerBundleDao.get(peerPub);
      expect(stateBefore?.bundleSentAt, isNotNull,
          reason: 'bundleSentAt must be set after openChat sends our bundle');

      // Relay reports the bundle recipient was offline — no message queue.
      relay.emit(ErrorFrame(
        code: 'recipient_offline',
        message: '',
        toPubkeyHex: peerPub,
      ));
      await drainMicrotasks();

      // bundleSentAt must be cleared so the next openChat will retry.
      final stateAfter = await peerBundleDao.get(peerPub);
      expect(stateAfter?.bundleSentAt, isNull,
          reason: 'clearBundleSent must be called when bundle send fails');

      // No wake dispatch — there was no message envelope to bridge.
      expect(wake.calls, isEmpty);
    });

    test('bundle-send recovery: after a failed bundle send, the next openChat '
        'retries', () async {
      await setUpWith(() => const WakeResult(WakeStatus.ok));
      await wakeService.openChat(peerPub);
      relay.emit(ErrorFrame(
        code: 'recipient_offline',
        message: '',
        toPubkeyHex: peerPub,
      ));
      await drainMicrotasks();

      final bundlesBefore = relay.sent
          .where((f) => f.envelope.first == EnvelopeTag.preKeyBundle)
          .length;

      // Re-enter the chat (e.g., user navigates away and back).
      await wakeService.openChat(peerPub);

      final bundlesAfter = relay.sent
          .where((f) => f.envelope.first == EnvelopeTag.preKeyBundle)
          .length;
      expect(bundlesAfter, bundlesBefore + 1,
          reason: 'second openChat should re-send the bundle now that the '
              'first attempt is known to have failed');
    });

    test('FCM error: wake is still dispatched once (status surfaced via logs)',
        () async {
      await setUpWith(() => const WakeResult(
            WakeStatus.fcmError,
            detail: 'FCM unavailable',
          ));
      await bootstrap();
      await wakeService.sendText(peerPubkeyHex: peerPub, body: 'errored');

      relay.emit(ErrorFrame(
        code: 'recipient_offline',
        message: '',
        toPubkeyHex: peerPub,
      ));
      await drainMicrotasks();

      expect(wake.calls, hasLength(1));
      // No retry, no exception — failure is logged structurally and the
      // message stays in Alice's DB. (See "Known limitations carried into
      // Phase 10.4+" in the roadmap.)
    });

    test('inbound from peer clears the wake queue (peer is online again)',
        () async {
      await setUpWith(() => const WakeResult(WakeStatus.ok));
      await bootstrap();
      await wakeService.sendText(peerPubkeyHex: peerPub, body: 'stale1');
      await wakeService.sendText(peerPubkeyHex: peerPub, body: 'stale2');

      // Peer replies — proves online.
      relay.emit(DeliverFrame(
        fromPubkeyHex: peerPub,
        envelope: EnvelopeWire.wrapMessage(
          [0xCC, ...InnerEnvelope.buildText(
            chatId: peerPub,
            lamport: 1,
            body: 'back online',
          )],
        ),
      ));
      await drainMicrotasks();

      // After the reply, a late `recipient_offline` for the peer should
      // find an empty queue and not dispatch any wake.
      relay.emit(ErrorFrame(
        code: 'recipient_offline',
        message: '',
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
        myPubkeyHex: myPub,
        groupMembersDao: groupMembersDao,
        groupOpsLogDao: groupOpsLogDao,
        signing: signing,
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
        myPubkeyHex: myPub,
        groupMembersDao: GroupMembersDao(db1),
        groupOpsLogDao: GroupOpsLogDao(db1),
        signing: signing,
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
        myPubkeyHex: myPub,
        groupMembersDao: GroupMembersDao(db2),
        groupOpsLogDao: GroupOpsLogDao(db2),
        signing: signing,
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
