import 'package:drift/drift.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart' as lsl;

import '../../data/app_database.dart';

/// Drift-backed `IdentityKeyStore`. The local identity (own key pair +
/// registration id + device id) is held as a singleton row (id == 0) in
/// `signal_identity`; trusted peer identities live one row per peer in
/// `signal_peer_identities`.
class DriftIdentityKeyStore extends lsl.IdentityKeyStore {
  DriftIdentityKeyStore(this._db);

  static const int _localIdentityRowId = 0;

  final AppDatabase _db;

  /// Returns true when the local identity row has been seeded — callers can
  /// use this to decide whether to generate a fresh identity on first launch.
  Future<bool> hasLocalIdentity() async {
    final row = await (_db.select(_db.signalIdentity)
          ..where((t) => t.id.equals(_localIdentityRowId)))
        .getSingleOrNull();
    return row != null;
  }

  /// Seeds (or overwrites) the local identity. Called once during libsignal
  /// bootstrap; not part of the `IdentityKeyStore` contract.
  Future<void> saveLocalIdentity({
    required lsl.IdentityKeyPair identityKeyPair,
    required int registrationId,
    required int deviceId,
  }) async {
    await _db.into(_db.signalIdentity).insertOnConflictUpdate(
          SignalIdentityCompanion.insert(
            id: const Value(_localIdentityRowId),
            identityKeyPair: identityKeyPair.serialize(),
            registrationId: registrationId,
            deviceId: deviceId,
          ),
        );
  }

  /// Returns the device id stored alongside the local identity. Outside the
  /// `IdentityKeyStore` contract but useful for the higher-level service.
  Future<int> getLocalDeviceId() async {
    final row = await (_db.select(_db.signalIdentity)
          ..where((t) => t.id.equals(_localIdentityRowId)))
        .getSingle();
    return row.deviceId;
  }

  @override
  Future<lsl.IdentityKeyPair> getIdentityKeyPair() async {
    final row = await (_db.select(_db.signalIdentity)
          ..where((t) => t.id.equals(_localIdentityRowId)))
        .getSingle();
    return lsl.IdentityKeyPair.fromSerialized(
        Uint8List.fromList(row.identityKeyPair));
  }

  @override
  Future<int> getLocalRegistrationId() async {
    final row = await (_db.select(_db.signalIdentity)
          ..where((t) => t.id.equals(_localIdentityRowId)))
        .getSingle();
    return row.registrationId;
  }

  @override
  Future<bool> saveIdentity(
    lsl.SignalProtocolAddress address,
    lsl.IdentityKey? identityKey,
  ) async {
    if (identityKey == null) return false;
    final peerKey = address.getName();
    final existing = await (_db.select(_db.signalPeerIdentities)
          ..where((t) => t.peerPubkeyHex.equals(peerKey)))
        .getSingleOrNull();
    final newBlob = identityKey.serialize();
    if (existing != null && _bytesEqual(existing.identityKey, newBlob)) {
      // Identity unchanged — libsignal expects `false` to mean "no rotation".
      return false;
    }
    await _db.into(_db.signalPeerIdentities).insertOnConflictUpdate(
          SignalPeerIdentitiesCompanion.insert(
            peerPubkeyHex: peerKey,
            identityKey: newBlob,
          ),
        );
    return existing != null;
  }

  @override
  Future<bool> isTrustedIdentity(
    lsl.SignalProtocolAddress address,
    lsl.IdentityKey? identityKey,
    lsl.Direction direction,
  ) async {
    if (identityKey == null) return false;
    final row = await (_db.select(_db.signalPeerIdentities)
          ..where((t) => t.peerPubkeyHex.equals(address.getName())))
        .getSingleOrNull();
    // Trust-on-first-use: unknown peer is trusted on the first encounter, so
    // the session can be built. Subsequent encounters must match the stored
    // key bit-for-bit (and respect the row's `trusted` flag).
    if (row == null) return true;
    if (!row.trusted) return false;
    return _bytesEqual(row.identityKey, identityKey.serialize());
  }

  @override
  Future<lsl.IdentityKey?> getIdentity(
      lsl.SignalProtocolAddress address) async {
    final row = await (_db.select(_db.signalPeerIdentities)
          ..where((t) => t.peerPubkeyHex.equals(address.getName())))
        .getSingleOrNull();
    if (row == null) return null;
    return lsl.IdentityKey.fromBytes(Uint8List.fromList(row.identityKey), 0);
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
