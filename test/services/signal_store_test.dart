import 'dart:io';

import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/services/signal_store/drift_identity_key_store.dart';
import 'package:app_v3/services/signal_store/drift_pre_key_store.dart';
import 'package:app_v3/services/signal_store/drift_sender_key_store.dart';
import 'package:app_v3/services/signal_store/drift_session_store.dart';
import 'package:app_v3/services/signal_store/drift_signal_protocol_store.dart';
import 'package:app_v3/services/signal_store/drift_signed_pre_key_store.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart' as lsl;

void main() {
  // The restart test intentionally opens two AppDatabase instances over the
  // same file. Without this flag drift logs a "multiple databases" warning
  // that obscures real failures in test output.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('DriftIdentityKeyStore', () {
    late AppDatabase db;
    late DriftIdentityKeyStore store;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      store = DriftIdentityKeyStore(db);
    });

    tearDown(() async => db.close());

    test('hasLocalIdentity is false until seeded', () async {
      expect(await store.hasLocalIdentity(), isFalse);
    });

    test('saveLocalIdentity then read back returns same keypair + ids',
        () async {
      final kp = lsl.generateIdentityKeyPair();
      final regId = lsl.generateRegistrationId(false);
      await store.saveLocalIdentity(
        identityKeyPair: kp,
        registrationId: regId,
        deviceId: 1,
      );
      expect(await store.hasLocalIdentity(), isTrue);

      final loaded = await store.getIdentityKeyPair();
      expect(loaded.serialize(), kp.serialize());
      expect(await store.getLocalRegistrationId(), regId);
      expect(await store.getLocalDeviceId(), 1);
    });

    test('saveIdentity stores peer key; isTrustedIdentity matches', () async {
      final peerKp = lsl.generateIdentityKeyPair();
      final peerKey = peerKp.getPublicKey();
      final address = lsl.SignalProtocolAddress('bob-pubkey', 1);

      // First save returns false (no previous entry to rotate).
      expect(await store.saveIdentity(address, peerKey), isFalse);
      expect(await store.isTrustedIdentity(
            address,
            peerKey,
            lsl.Direction.sending,
          ), isTrue);

      final fetched = await store.getIdentity(address);
      expect(fetched?.serialize(), peerKey.serialize());
    });

    test('isTrustedIdentity is true for unknown peer (TOFU)', () async {
      final peerKp = lsl.generateIdentityKeyPair();
      final address = lsl.SignalProtocolAddress('unknown-peer', 1);
      expect(
        await store.isTrustedIdentity(
          address,
          peerKp.getPublicKey(),
          lsl.Direction.sending,
        ),
        isTrue,
      );
    });
  });

  group('DriftPreKeyStore', () {
    late AppDatabase db;
    late DriftPreKeyStore store;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      store = DriftPreKeyStore(db);
    });

    tearDown(() async => db.close());

    test('store + load round-trips bytes', () async {
      final prekey = lsl.generatePreKeys(42, 1).single;
      await store.storePreKey(prekey.id, prekey);
      expect(await store.containsPreKey(prekey.id), isTrue);

      final loaded = await store.loadPreKey(prekey.id);
      expect(loaded.serialize(), prekey.serialize());
    });

    test('loadPreKey throws InvalidKeyIdException on miss', () async {
      expect(
        () => store.loadPreKey(999),
        throwsA(isA<lsl.InvalidKeyIdException>()),
      );
    });

    test('remove deletes the row', () async {
      final prekey = lsl.generatePreKeys(7, 1).single;
      await store.storePreKey(prekey.id, prekey);
      await store.removePreKey(prekey.id);
      expect(await store.containsPreKey(prekey.id), isFalse);
    });
  });

  group('DriftSignedPreKeyStore', () {
    late AppDatabase db;
    late DriftSignedPreKeyStore store;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      store = DriftSignedPreKeyStore(db);
    });

    tearDown(() async => db.close());

    test('store + load + loadAll', () async {
      final identityKp = lsl.generateIdentityKeyPair();
      final spk = lsl.generateSignedPreKey(identityKp, 3);
      await store.storeSignedPreKey(spk.id, spk);

      expect(await store.containsSignedPreKey(spk.id), isTrue);
      final loaded = await store.loadSignedPreKey(spk.id);
      expect(loaded.serialize(), spk.serialize());

      final all = await store.loadSignedPreKeys();
      expect(all.length, 1);
    });

    test('loadSignedPreKey throws on miss', () async {
      expect(
        () => store.loadSignedPreKey(999),
        throwsA(isA<lsl.InvalidKeyIdException>()),
      );
    });
  });

  group('DriftSessionStore', () {
    late AppDatabase aliceDb;
    late DriftSignalProtocolStore aliceStore;
    late AppDatabase bobDb;
    late DriftSignalProtocolStore bobStore;

    Future<void> bootstrapStore(
      DriftSignalProtocolStore composite, {
      required int preKeyId,
      required int signedPreKeyId,
    }) async {
      final kp = lsl.generateIdentityKeyPair();
      final regId = lsl.generateRegistrationId(false);
      await composite.identityKeyStore.saveLocalIdentity(
        identityKeyPair: kp,
        registrationId: regId,
        deviceId: 1,
      );
      final preKey = lsl.generatePreKeys(preKeyId, 1).single;
      await composite.preKeyStore.storePreKey(preKey.id, preKey);
      final signedPreKey = lsl.generateSignedPreKey(kp, signedPreKeyId);
      await composite.signedPreKeyStore
          .storeSignedPreKey(signedPreKey.id, signedPreKey);
    }

    setUp(() async {
      aliceDb = AppDatabase.forTesting(NativeDatabase.memory());
      aliceStore = DriftSignalProtocolStore(aliceDb);
      await bootstrapStore(aliceStore, preKeyId: 1, signedPreKeyId: 1);

      bobDb = AppDatabase.forTesting(NativeDatabase.memory());
      bobStore = DriftSignalProtocolStore(bobDb);
      await bootstrapStore(bobStore, preKeyId: 2, signedPreKeyId: 2);
    });

    tearDown(() async {
      await aliceDb.close();
      await bobDb.close();
    });

    test(
        'session built by SessionBuilder is persisted; reload returns same bytes',
        () async {
      // Build Bob's PreKey bundle as Alice would receive it over the wire.
      final bobKp = await bobStore.getIdentityKeyPair();
      final bobPreKey = await bobStore.loadPreKey(2);
      final bobSpk = await bobStore.loadSignedPreKey(2);
      final bobBundle = lsl.PreKeyBundle(
        await bobStore.getLocalRegistrationId(),
        1,
        bobPreKey.id,
        bobPreKey.getKeyPair().publicKey,
        bobSpk.id,
        bobSpk.getKeyPair().publicKey,
        bobSpk.signature,
        bobKp.getPublicKey(),
      );

      final bobAddress = lsl.SignalProtocolAddress('bob-pubkey', 1);
      final builder = lsl.SessionBuilder.fromSignalStore(aliceStore, bobAddress);
      await builder.processPreKeyBundle(bobBundle);

      // Session was stored. Read it back through a FRESH store on the same DB.
      expect(await aliceStore.containsSession(bobAddress), isTrue);

      final freshStore = DriftSessionStore(aliceDb);
      final reloaded = await freshStore.loadSession(bobAddress);
      final original = await aliceStore.loadSession(bobAddress);
      expect(reloaded.serialize(), original.serialize());
    });

    test('deleteSession removes the row', () async {
      final addr = lsl.SignalProtocolAddress('peer', 2);
      // Manually inject a serialized record so we don't need the full flow.
      await aliceStore.sessionStore.storeSession(addr, lsl.SessionRecord());
      expect(await aliceStore.sessionStore.containsSession(addr), isTrue);
      await aliceStore.sessionStore.deleteSession(addr);
      expect(await aliceStore.sessionStore.containsSession(addr), isFalse);
    });
  });

  group('DriftSenderKeyStore', () {
    test('storeSenderKey throws (group messaging stub)', () async {
      final store = DriftSenderKeyStore();
      expect(
        () => store.storeSenderKey(
          lsl.SenderKeyName(
              'group', lsl.SignalProtocolAddress('alice-pubkey', 1)),
          lsl.SenderKeyRecord(),
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  group('persistence across DB close+reopen (simulated restart)', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hb_signal_store_test_');
      dbFile = File('${tempDir.path}/hb_v3.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('identity + prekey + signedprekey survive DB close+reopen', () async {
      // ---- Session 1: write ----
      final db1 = AppDatabase.forTesting(NativeDatabase(dbFile));
      final store1 = DriftSignalProtocolStore(db1);
      final kp = lsl.generateIdentityKeyPair();
      final regId = lsl.generateRegistrationId(false);
      await store1.identityKeyStore.saveLocalIdentity(
        identityKeyPair: kp,
        registrationId: regId,
        deviceId: 1,
      );
      final prekey = lsl.generatePreKeys(11, 1).single;
      await store1.preKeyStore.storePreKey(prekey.id, prekey);
      final spk = lsl.generateSignedPreKey(kp, 22);
      await store1.signedPreKeyStore.storeSignedPreKey(spk.id, spk);
      await db1.close();

      // ---- Session 2: read back ----
      final db2 = AppDatabase.forTesting(NativeDatabase(dbFile));
      final store2 = DriftSignalProtocolStore(db2);

      final loadedKp = await store2.getIdentityKeyPair();
      expect(loadedKp.serialize(), kp.serialize());
      expect(await store2.getLocalRegistrationId(), regId);

      final loadedPrekey = await store2.loadPreKey(11);
      expect(loadedPrekey.serialize(), prekey.serialize());

      final loadedSpk = await store2.loadSignedPreKey(22);
      expect(loadedSpk.serialize(), spk.serialize());

      await db2.close();
    });
  });
}
