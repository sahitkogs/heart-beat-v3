// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'peer_bundle_state_dao.dart';

// ignore_for_file: type=lint
mixin _$PeerBundleStateDaoMixin on DatabaseAccessor<AppDatabase> {
  $PeerBundleStateTable get peerBundleState => attachedDatabase.peerBundleState;
  PeerBundleStateDaoManager get managers => PeerBundleStateDaoManager(this);
}

class PeerBundleStateDaoManager {
  final _$PeerBundleStateDaoMixin _db;
  PeerBundleStateDaoManager(this._db);
  $$PeerBundleStateTableTableManager get peerBundleState =>
      $$PeerBundleStateTableTableManager(
        _db.attachedDatabase,
        _db.peerBundleState,
      );
}
