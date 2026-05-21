import 'package:drift/drift.dart';
import 'app_database.dart';

part 'group_ops_log_dao.g.dart';

@DriftAccessor(tables: [GroupOpsLog])
class GroupOpsLogDao extends DatabaseAccessor<AppDatabase>
    with _$GroupOpsLogDaoMixin {
  GroupOpsLogDao(super.db);

  Future<void> append({
    required String id,
    required String chatId,
    int? opSeq,
    required String kind,
    String? targetPubkeyHex,
    required String signerPubkeyHex,
    required String signatureHex,
    required bool applied,
  }) async {
    await into(groupOpsLog).insert(
      GroupOpsLogCompanion.insert(
        id: id,
        chatId: chatId,
        opSeq: Value(opSeq),
        kind: kind,
        targetPubkeyHex: Value(targetPubkeyHex),
        signerPubkeyHex: signerPubkeyHex,
        signatureHex: signatureHex,
        receivedAt: DateTime.now(),
        applied: applied,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<List<GroupOpsLogData>> forChat(String chatId) =>
      (select(groupOpsLog)
            ..where((t) => t.chatId.equals(chatId))
            ..orderBy([(t) => OrderingTerm.asc(t.receivedAt)]))
          .get();
}
