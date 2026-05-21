// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_ops_log_dao.dart';

// ignore_for_file: type=lint
mixin _$GroupOpsLogDaoMixin on DatabaseAccessor<AppDatabase> {
  $GroupOpsLogTable get groupOpsLog => attachedDatabase.groupOpsLog;
  GroupOpsLogDaoManager get managers => GroupOpsLogDaoManager(this);
}

class GroupOpsLogDaoManager {
  final _$GroupOpsLogDaoMixin _db;
  GroupOpsLogDaoManager(this._db);
  $$GroupOpsLogTableTableManager get groupOpsLog =>
      $$GroupOpsLogTableTableManager(_db.attachedDatabase, _db.groupOpsLog);
}
