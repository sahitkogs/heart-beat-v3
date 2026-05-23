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

  /// Drop the entire bundle-exchange state row for a peer. Called when the
  /// contact is deleted so a future re-pairing (e.g. paste-hex after a delete,
  /// or after the peer rotated their identity by reinstalling) starts a clean
  /// X3DH handshake instead of inheriting `bundleSentAt`/`peerBundleReceivedAt`
  /// from the prior pairing.
  Future<void> deleteByPubkey(String peerPubkeyHex) async {
    await (delete(peerBundleState)
          ..where((t) => t.peerPubkeyHex.equals(peerPubkeyHex)))
        .go();
  }
}
