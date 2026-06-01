import '../../data/app_database.dart';
import '../../data/chats_dao.dart';
import '../../data/outbox_dao.dart';
import '../../chat/outbox_retransmitter.dart' show OutboxRetransmitter;

/// Read-only audit of message-delivery records. Surfaces records that may
/// have been lost or left unconfirmed ("every record is kept").
class IntegrityReport {
  const IntegrityReport({
    required this.stuckOutbox,
    required this.orphanedSent,
    required this.stuckPeers,
  });

  /// Pending outbox rows older than the 24h expiry window. The sweeper should
  /// have expired these; if they linger, retransmission has stalled.
  final int stuckOutbox;

  /// Messages we marked `sent` that have no delivery receipt AND no live
  /// outbox row — sent into the void, never confirmed.
  final int orphanedSent;

  /// Distinct peer pubkeys owning >= 1 stuck outbox row — the re-kick targets.
  final List<String> stuckPeers;

  bool get isClean => stuckOutbox == 0 && orphanedSent == 0;
}

/// Pure, read-only scan of the existing outbox + messages tables. Performs no
/// writes, no migration, and no table creation.
Future<IntegrityReport> computeIntegrityReport(AppDatabase db) async {
  final outbox = OutboxDao(db);
  final chats = ChatsDao(db);

  final now = DateTime.now();
  final cutoff = now.subtract(OutboxRetransmitter.maxAge);

  // Stuck outbox: pending rows older than the 24h expiry cutoff.
  final stuckRows = await outbox.olderThanStillPending(cutoff);
  final stuckPeers = <String>{
    for (final row in stuckRows) row.peerPubkeyHex,
  }.toList();

  // Orphaned sent: messages stuck in `sent` with no outbox row backing them.
  final orphanedSent = await chats.countOrphanedSent();

  return IntegrityReport(
    stuckOutbox: stuckRows.length,
    orphanedSent: orphanedSent,
    stuckPeers: stuckPeers,
  );
}
