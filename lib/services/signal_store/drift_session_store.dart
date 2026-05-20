import 'package:drift/drift.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart' as lsl;

import '../../data/app_database.dart';

/// Drift-backed `SessionStore`. Address is encoded as `"pubkeyHex:deviceId"`
/// so drift can key by a single TEXT column without a composite PK.
class DriftSessionStore with lsl.SessionStore {
  DriftSessionStore(this._db);

  final AppDatabase _db;

  static String _encode(lsl.SignalProtocolAddress address) =>
      '${address.getName()}:${address.getDeviceId()}';

  @override
  Future<lsl.SessionRecord> loadSession(
      lsl.SignalProtocolAddress address) async {
    final row = await (_db.select(_db.signalSessions)
          ..where((t) => t.address.equals(_encode(address))))
        .getSingleOrNull();
    if (row == null) {
      // Mirrors the in-memory reference impl: callers expect a fresh empty
      // record when no session exists yet (libsignal builds onto it).
      return lsl.SessionRecord();
    }
    return lsl.SessionRecord.fromSerialized(Uint8List.fromList(row.record));
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    // Match all addresses whose `pubkey:deviceId` prefix is "<name>:" and
    // collect every deviceId EXCEPT the primary device (1) — mirrors the
    // reference impl's exclusion rule.
    final prefix = '$name:';
    final rows = await (_db.select(_db.signalSessions)
          ..where((t) => t.address.like('$prefix%')))
        .get();
    return rows
        .map((r) => int.parse(r.address.substring(prefix.length)))
        .where((deviceId) => deviceId != 1)
        .toList(growable: false);
  }

  @override
  Future<void> storeSession(
      lsl.SignalProtocolAddress address, lsl.SessionRecord record) async {
    await _db.into(_db.signalSessions).insertOnConflictUpdate(
          SignalSessionsCompanion.insert(
            address: _encode(address),
            record: record.serialize(),
          ),
        );
  }

  @override
  Future<bool> containsSession(lsl.SignalProtocolAddress address) async {
    final row = await (_db.select(_db.signalSessions)
          ..where((t) => t.address.equals(_encode(address))))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> deleteSession(lsl.SignalProtocolAddress address) async {
    await (_db.delete(_db.signalSessions)
          ..where((t) => t.address.equals(_encode(address))))
        .go();
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    await (_db.delete(_db.signalSessions)
          ..where((t) => t.address.like('$name:%')))
        .go();
  }
}
