import 'package:drift/drift.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart' as lsl;

import '../../data/app_database.dart';

/// Drift-backed `SignedPreKeyStore`. Long-lived signed pre-keys; in 1:1
/// Heartbeat we keep a single row. Multi-peer rotation lands in 10.4/10.5.
class DriftSignedPreKeyStore with lsl.SignedPreKeyStore {
  DriftSignedPreKeyStore(this._db);

  final AppDatabase _db;

  @override
  Future<lsl.SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    final row = await (_db.select(_db.signalSignedPreKeys)
          ..where((t) => t.keyId.equals(signedPreKeyId)))
        .getSingleOrNull();
    if (row == null) {
      throw lsl.InvalidKeyIdException('No such signed prekey: $signedPreKeyId');
    }
    return lsl.SignedPreKeyRecord.fromSerialized(
        Uint8List.fromList(row.record));
  }

  @override
  Future<List<lsl.SignedPreKeyRecord>> loadSignedPreKeys() async {
    final rows = await _db.select(_db.signalSignedPreKeys).get();
    return rows
        .map((r) =>
            lsl.SignedPreKeyRecord.fromSerialized(Uint8List.fromList(r.record)))
        .toList(growable: false);
  }

  @override
  Future<void> storeSignedPreKey(
      int signedPreKeyId, lsl.SignedPreKeyRecord record) async {
    await _db.into(_db.signalSignedPreKeys).insertOnConflictUpdate(
          SignalSignedPreKeysCompanion.insert(
            keyId: Value(signedPreKeyId),
            record: record.serialize(),
          ),
        );
  }

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async {
    final row = await (_db.select(_db.signalSignedPreKeys)
          ..where((t) => t.keyId.equals(signedPreKeyId)))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    await (_db.delete(_db.signalSignedPreKeys)
          ..where((t) => t.keyId.equals(signedPreKeyId)))
        .go();
  }
}
