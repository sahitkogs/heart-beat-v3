import 'package:drift/drift.dart';
import 'app_database.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  Future<void> insert({
    required String msgId,
    required String peerPubkeyHex,
    required List<int> envelopeBytes,
    required DateTime createdAt,
    required DateTime nextRetryAt,
    String kind = 'text',
  }) async {
    await into(outbox).insertOnConflictUpdate(
      OutboxCompanion.insert(
        msgId: msgId,
        peerPubkeyHex: peerPubkeyHex,
        envelopeBytes: Uint8List.fromList(envelopeBytes),
        createdAt: createdAt,
        nextRetryAt: nextRetryAt,
        kind: Value(kind),
      ),
    );
  }

  Future<OutboxData?> findByMsgId(String msgId) =>
      (select(outbox)..where((t) => t.msgId.equals(msgId))).getSingleOrNull();

  /// Rows whose `nextRetryAt <= now`, oldest `createdAt` first. The
  /// retransmitter consumes this list per sweep.
  Future<List<OutboxData>> dueBefore(DateTime now) =>
      (select(outbox)
            ..where((t) => t.nextRetryAt.isSmallerOrEqualValue(now))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<void> bumpAttempt(String msgId, DateTime nextRetryAt) async {
    final existing = await findByMsgId(msgId);
    final nextAttempt = (existing?.attempt ?? 0) + 1;
    await (update(outbox)..where((t) => t.msgId.equals(msgId))).write(
      OutboxCompanion(
        attempt: Value(nextAttempt),
        nextRetryAt: Value(nextRetryAt),
      ),
    );
  }

  /// Drop a single outbox row by msgId. Named `deleteByMsgId` (not `delete`)
  /// to avoid shadowing `DatabaseAccessor.delete(TableInfo)` — same naming
  /// convention as `PeerBundleStateDao.deleteByPubkey`.
  Future<void> deleteByMsgId(String msgId) async {
    await (delete(outbox)..where((t) => t.msgId.equals(msgId))).go();
  }

  /// Drops every outbox row for [peerPubkeyHex]. Returns the count. Called
  /// from `MessageService.forgetPeer` so a deleted+re-paired contact doesn't
  /// keep retransmitting against a libsignal session that no longer exists.
  Future<int> markPeerFailed(String peerPubkeyHex) async {
    return (delete(outbox)
          ..where((t) => t.peerPubkeyHex.equals(peerPubkeyHex)))
        .go();
  }
}
