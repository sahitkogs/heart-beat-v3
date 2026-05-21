// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_members_dao.dart';

// ignore_for_file: type=lint
mixin _$GroupMembersDaoMixin on DatabaseAccessor<AppDatabase> {
  $GroupMembersTable get groupMembers => attachedDatabase.groupMembers;
  GroupMembersDaoManager get managers => GroupMembersDaoManager(this);
}

class GroupMembersDaoManager {
  final _$GroupMembersDaoMixin _db;
  GroupMembersDaoManager(this._db);
  $$GroupMembersTableTableManager get groupMembers =>
      $$GroupMembersTableTableManager(_db.attachedDatabase, _db.groupMembers);
}
