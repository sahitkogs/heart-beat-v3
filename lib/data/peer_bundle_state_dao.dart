import 'package:drift/drift.dart';
import 'app_database.dart';

part 'peer_bundle_state_dao.g.dart';

@DriftAccessor(tables: [PeerBundleState])
class PeerBundleStateDao extends DatabaseAccessor<AppDatabase>
    with _$PeerBundleStateDaoMixin {
  PeerBundleStateDao(super.db);

  Future<PeerBundleStateData?> get(String peerPubkeyHex) =>
      (select(peerBundleState)
            ..where((t) => t.peerPubkeyHex.equals(peerPubkeyHex)))
          .getSingleOrNull();

  Future<void> markBundleSent(String peerPubkeyHex, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    await into(peerBundleState).insertOnConflictUpdate(
      PeerBundleStateCompanion.insert(
        peerPubkeyHex: peerPubkeyHex,
        bundleSentAt: Value(now),
      ),
    );
  }

  Future<void> markPeerBundleReceived(String peerPubkeyHex,
      {DateTime? at}) async {
    final now = at ?? DateTime.now();
    await into(peerBundleState).insertOnConflictUpdate(
      PeerBundleStateCompanion.insert(
        peerPubkeyHex: peerPubkeyHex,
        peerBundleReceivedAt: Value(now),
      ),
    );
  }

  Future<void> clearBundleSent(String peerPubkeyHex) async {
    await (update(peerBundleState)
          ..where((t) => t.peerPubkeyHex.equals(peerPubkeyHex)))
        .write(const PeerBundleStateCompanion(bundleSentAt: Value(null)));
  }
}
