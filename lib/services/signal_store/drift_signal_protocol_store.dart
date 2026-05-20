import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart' as lsl;

import '../../data/app_database.dart';
import 'drift_identity_key_store.dart';
import 'drift_pre_key_store.dart';
import 'drift_session_store.dart';
import 'drift_signed_pre_key_store.dart';

/// Drop-in replacement for `lsl.InMemorySignalProtocolStore` backed by drift.
/// Persists across app launches; safe to instantiate fresh in a background
/// isolate as long as it gets the same `AppDatabase` file.
///
/// Note: `lsl.SignalProtocolStore` does NOT include `SenderKeyStore` — group
/// messaging uses a separate path. Sender-key persistence lands in Phase 10.4.
class DriftSignalProtocolStore implements lsl.SignalProtocolStore {
  DriftSignalProtocolStore(AppDatabase db)
      : identityKeyStore = DriftIdentityKeyStore(db),
        preKeyStore = DriftPreKeyStore(db),
        signedPreKeyStore = DriftSignedPreKeyStore(db),
        sessionStore = DriftSessionStore(db);

  final DriftIdentityKeyStore identityKeyStore;
  final DriftPreKeyStore preKeyStore;
  final DriftSignedPreKeyStore signedPreKeyStore;
  final DriftSessionStore sessionStore;

  // ---- IdentityKeyStore ----

  @override
  Future<lsl.IdentityKeyPair> getIdentityKeyPair() =>
      identityKeyStore.getIdentityKeyPair();

  @override
  Future<int> getLocalRegistrationId() =>
      identityKeyStore.getLocalRegistrationId();

  @override
  Future<bool> saveIdentity(
          lsl.SignalProtocolAddress address, lsl.IdentityKey? identityKey) =>
      identityKeyStore.saveIdentity(address, identityKey);

  @override
  Future<bool> isTrustedIdentity(lsl.SignalProtocolAddress address,
          lsl.IdentityKey? identityKey, lsl.Direction direction) =>
      identityKeyStore.isTrustedIdentity(address, identityKey, direction);

  @override
  Future<lsl.IdentityKey?> getIdentity(lsl.SignalProtocolAddress address) =>
      identityKeyStore.getIdentity(address);

  // ---- PreKeyStore ----

  @override
  Future<lsl.PreKeyRecord> loadPreKey(int preKeyId) =>
      preKeyStore.loadPreKey(preKeyId);

  @override
  Future<void> storePreKey(int preKeyId, lsl.PreKeyRecord record) =>
      preKeyStore.storePreKey(preKeyId, record);

  @override
  Future<bool> containsPreKey(int preKeyId) =>
      preKeyStore.containsPreKey(preKeyId);

  @override
  Future<void> removePreKey(int preKeyId) =>
      preKeyStore.removePreKey(preKeyId);

  // ---- SignedPreKeyStore ----

  @override
  Future<lsl.SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) =>
      signedPreKeyStore.loadSignedPreKey(signedPreKeyId);

  @override
  Future<List<lsl.SignedPreKeyRecord>> loadSignedPreKeys() =>
      signedPreKeyStore.loadSignedPreKeys();

  @override
  Future<void> storeSignedPreKey(
          int signedPreKeyId, lsl.SignedPreKeyRecord record) =>
      signedPreKeyStore.storeSignedPreKey(signedPreKeyId, record);

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) =>
      signedPreKeyStore.containsSignedPreKey(signedPreKeyId);

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) =>
      signedPreKeyStore.removeSignedPreKey(signedPreKeyId);

  // ---- SessionStore ----

  @override
  Future<lsl.SessionRecord> loadSession(lsl.SignalProtocolAddress address) =>
      sessionStore.loadSession(address);

  @override
  Future<List<int>> getSubDeviceSessions(String name) =>
      sessionStore.getSubDeviceSessions(name);

  @override
  Future<void> storeSession(
          lsl.SignalProtocolAddress address, lsl.SessionRecord record) =>
      sessionStore.storeSession(address, record);

  @override
  Future<bool> containsSession(lsl.SignalProtocolAddress address) =>
      sessionStore.containsSession(address);

  @override
  Future<void> deleteSession(lsl.SignalProtocolAddress address) =>
      sessionStore.deleteSession(address);

  @override
  Future<void> deleteAllSessions(String name) =>
      sessionStore.deleteAllSessions(name);
}
