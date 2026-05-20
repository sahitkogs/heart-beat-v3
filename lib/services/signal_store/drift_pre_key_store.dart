import 'package:drift/drift.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart' as lsl;

import '../../data/app_database.dart';

/// Drift-backed `PreKeyStore`. One-time pre-keys; rows are deleted as
/// libsignal consumes them during session establishment.
class DriftPreKeyStore with lsl.PreKeyStore {
  DriftPreKeyStore(this._db);

  final AppDatabase _db;

  @override
  Future<lsl.PreKeyRecord> loadPreKey(int preKeyId) async {
    final row = await (_db.select(_db.signalPreKeys)
          ..where((t) => t.keyId.equals(preKeyId)))
        .getSingleOrNull();
    if (row == null) {
      throw lsl.InvalidKeyIdException('No such prekey: $preKeyId');
    }
    return lsl.PreKeyRecord.fromBuffer(Uint8List.fromList(row.record));
  }

  @override
  Future<void> storePreKey(int preKeyId, lsl.PreKeyRecord record) async {
    await _db.into(_db.signalPreKeys).insertOnConflictUpdate(
          SignalPreKeysCompanion.insert(
            keyId: Value(preKeyId),
            record: record.serialize(),
          ),
        );
  }

  @override
  Future<bool> containsPreKey(int preKeyId) async {
    final row = await (_db.select(_db.signalPreKeys)
          ..where((t) => t.keyId.equals(preKeyId)))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> removePreKey(int preKeyId) async {
    await (_db.delete(_db.signalPreKeys)
          ..where((t) => t.keyId.equals(preKeyId)))
        .go();
  }
}
