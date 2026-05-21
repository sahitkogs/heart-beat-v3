import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_v3/chat/message_service.dart';
import 'package:app_v3/chat/pre_key_bootstrap.dart';
import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/chats_dao.dart';
import 'package:app_v3/relay/relay_client.dart';
import 'package:app_v3/relay/relay_frames.dart';
import 'package:app_v3/services/crypto_pre_key_bundle.dart';
import 'package:app_v3/services/crypto_service.dart';
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

void main() {
  // The restart test opens two AppDatabase instances over the same file —
  // suppress drift's "multiple databases" warning so real failures stay
  // visible.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late ChatsDao dao;
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
    expect(utf8.decode(parsedMsg.ciphertext!.sublist(1)), 'queued');
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
    final ciphertext = [0xCC, ...utf8.encode('hi from peer')];
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
    expect(chats.first.peerPubkeyHex, peerPub);
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
        myPubkeyHex: myPub,
        wake: wake,
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
      // openChat sends OUR bundle (NOT pushed to _unackedByPeer).
      await wakeService.openChat(peerPub);
      final chatAfterSend = await dao.getChat(peerPub);
      expect(chatAfterSend!.bundleSentAt, isNotNull,
          reason: 'openChat should mark bundleSent immediately after relay.send');

      // Server reports the bundle send hit an offline peer.
      relay.emit(ErrorFrame(
        code: 'recipient_offline',
        message: '',
        toPubkeyHex: peerPub,
      ));
      await drainMicrotasks();

      expect(wake.calls, isEmpty,
          reason: 'bundles do not get wake-fallback — only message envelopes');
      final chatAfterErr = await dao.getChat(peerPub);
      expect(chatAfterErr!.bundleSentAt, isNull,
          reason: 'bundle delivery failed; bundleSent must reset so the next '
              'openChat retries — otherwise the peer never receives our bundle');
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
          [0xCC, ...utf8.encode('back online')],
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
      final crypto1 = _FakeCrypto();
      final relay1 = _FakeRelay();
      final service1 = MessageService(
        crypto: crypto1,
        relay: relay1,
        dao: dao1,
        myPubkeyHex: myPub,
      );

      await service1.openChat(peerPub);
      relay1.emit(DeliverFrame(
        fromPubkeyHex: peerPub,
        envelope: EnvelopeWire.wrapPreKeyBundle(peerBundle()),
      ));
      await drainMicrotasks();

      // Sanity: session 1 marked both flags in drift.
      final row1 = await dao1.getChat(peerPub);
      expect(row1?.bundleSentAt, isNotNull);
      expect(row1?.peerBundleReceivedAt, isNotNull);

      await service1.dispose();
      await relay1.dispose();
      await db1.close();

      // ---- Session 2: fresh in-process objects over same DB file ----
      final db2 = AppDatabase.forTesting(NativeDatabase(dbFile));
      final dao2 = ChatsDao(db2);
      final crypto2 = _FakeCrypto();
      final relay2 = _FakeRelay();
      final service2 = MessageService(
        crypto: crypto2,
        relay: relay2,
        dao: dao2,
        myPubkeyHex: myPub,
      );

      // openChat in session 2 must NOT emit a bundle because bundleSentAt
      // already non-null — the whole point of T3.3.
      await service2.openChat(peerPub);
      expect(relay2.sent, isEmpty);

      // sendText must NOT queue because peerBundleReceivedAt already non-null;
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
