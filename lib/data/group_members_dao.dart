import 'package:drift/drift.dart';
import 'app_database.dart';

part 'group_members_dao.g.dart';

@DriftAccessor(tables: [GroupMembers])
class GroupMembersDao extends DatabaseAccessor<AppDatabase>
    with _$GroupMembersDaoMixin {
  GroupMembersDao(super.db);

  Future<void> insertMember({
    required String chatId,
    required String memberPubkeyHex,
    required String addedByPubkeyHex,
    required DateTime addedAt,
  }) async {
    await into(groupMembers).insert(
      GroupMembersCompanion.insert(
        chatId: chatId,
        memberPubkeyHex: memberPubkeyHex,
        addedAt: addedAt,
        addedByPubkeyHex: addedByPubkeyHex,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> markRemoved({
    required String chatId,
    required String memberPubkeyHex,
    required DateTime removedAt,
  }) async {
    await (update(groupMembers)
          ..where((t) =>
              t.chatId.equals(chatId) &
              t.memberPubkeyHex.equals(memberPubkeyHex)))
        .write(GroupMembersCompanion(removedAt: Value(removedAt)));
  }

  Future<List<GroupMember>> activeMembers(String chatId) =>
      (select(groupMembers)
            ..where((t) => t.chatId.equals(chatId) & t.removedAt.isNull()))
          .get();

  Future<List<GroupMember>> allMembers(String chatId) =>
      (select(groupMembers)..where((t) => t.chatId.equals(chatId))).get();

  Future<bool> isActiveMember(String chatId, String memberPubkeyHex) async {
    final row = await (select(groupMembers)
          ..where((t) =>
              t.chatId.equals(chatId) &
              t.memberPubkeyHex.equals(memberPubkeyHex) &
              t.removedAt.isNull()))
        .getSingleOrNull();
    return row != null;
  }

  Stream<List<GroupMember>> watchActiveMembers(String chatId) =>
      (select(groupMembers)
            ..where((t) => t.chatId.equals(chatId) & t.removedAt.isNull()))
          .watch();
}
