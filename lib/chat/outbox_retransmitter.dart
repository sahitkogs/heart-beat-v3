import 'dart:async';

import '../data/app_database.dart';
import '../data/chats_dao.dart';
import '../data/outbox_dao.dart';

/// Indirection so tests can intercept the actual send.
abstract class RetransmitSender {
  Future<void> sendOnce(String peer, List<int> envelopeBytes);
}

/// Periodic background sweeper for the outbox. Every [sweepInterval] it
/// reads [OutboxDao.dueBefore] and retransmits each due row, advancing the
/// row's `attempt` and `nextRetryAt` per the [nextRetryAt] ladder. Rows
/// older than [maxAge] are dropped from the outbox and flipped to
/// `delivery_state == failed` so the UI can show a tap-to-retry tick.
class OutboxRetransmitter {
  OutboxRetransmitter({
    required this.outbox,
    required this.chats,
    required this.sender,
  });

  final OutboxDao outbox;
  final ChatsDao chats;
  final RetransmitSender sender;
  Timer? _sweepTimer;
  bool _sweeping = false;

  static const sweepInterval = Duration(seconds: 10);
  static const maxAge = Duration(hours: 24);

  /// Ladder per spec §7g — 30s / 60s / 5m / 30m / 1h / 1h …
  /// `attempt` is the post-bump attempt count (1-based: the value we'll
  /// write into the row after the retry just happened).
  static DateTime nextRetryAt({required int attempt, required DateTime now}) {
    const ladder = <Duration>[
      Duration(seconds: 30),
      Duration(seconds: 60),
      Duration(minutes: 5),
      Duration(minutes: 30),
      Duration(hours: 1),
    ];
    final idx = (attempt - 1).clamp(0, ladder.length - 1);
    return now.add(ladder[idx]);
  }

  /// 10.4.3c — receipt rows use a tighter ladder than text since they're
  /// cheap to re-send and a slow tick read poorly. 5s / 10s / 30s / 5m / 5m…
  static DateTime nextReceiptRetryAt(
      {required int attempt, required DateTime now}) {
    const ladder = <Duration>[
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 30),
      Duration(minutes: 5),
    ];
    final idx = (attempt - 1).clamp(0, ladder.length - 1);
    return now.add(ladder[idx]);
  }

  void start() {
    _sweepTimer ??= Timer.periodic(sweepInterval, (_) => _sweep());
  }

  void stop() {
    _sweepTimer?.cancel();
    _sweepTimer = null;
  }

  /// Synchronous, test-friendly entry. Production `_sweep` calls the same
  /// body with `DateTime.now()`.
  Future<void> sweepOnceForTest({required DateTime now}) => _sweepAt(now);

  /// Presence-triggered flush: kick every pending row for [peerPubkeyHex] to
  /// due-now, then run one sweep so they go out immediately. Safe to call
  /// repeatedly — the sweep + receipt dedup prevents duplicate delivery.
  Future<void> flushForPeer(String peerPubkeyHex) async {
    final now = DateTime.now();
    final kicked = await outbox.kickPeer(peerPubkeyHex, now);
    if (kicked == 0) return;
    // ignore: avoid_print
    print('[OR] flush_for_peer peer=$peerPubkeyHex kicked=$kicked');
    await _sweepAt(now);
  }

  Future<void> _sweep() => _sweepAt(DateTime.now());

  Future<void> _sweepAt(DateTime now) async {
    if (_sweeping) return; // a sweep is already in flight; due rows persist and
                           // will be picked up by the in-flight or next sweep.
    _sweeping = true;
    try {
      await _sweepBody(now);
    } finally {
      _sweeping = false;
    }
  }

  Future<void> _sweepBody(DateTime now) async {
    final due = await outbox.dueBefore(now);
    for (final row in due) {
      final isReceipt = row.kind == 'receipt';

      // 24h expiry. For text rows we mark the underlying messages row
      // failed so the UI can surface a retry tick. Receipt rows have no
      // corresponding messages row of their own (the synthetic id is just
      // a retry token), so they just disappear.
      if (now.difference(row.createdAt) > maxAge) {
        if (!isReceipt) {
          await chats.updateDeliveryState(row.msgId, DeliveryState.failed);
        }
        await outbox.deleteByMsgId(row.msgId);
        // ignore: avoid_print
        print('[OR] expired kind=${row.kind} msgId=${row.msgId} '
            'attempt=${row.attempt}');
        continue;
      }

      var sent = false;
      try {
        await sender.sendOnce(row.peerPubkeyHex, row.envelopeBytes);
        sent = true;
        // ignore: avoid_print
        print('[OR] retransmit kind=${row.kind} msgId=${row.msgId} '
            'attempt=${row.attempt + 1}');
      } catch (e) {
        // ignore: avoid_print
        print('[OR] retransmit_fail kind=${row.kind} '
            'msgId=${row.msgId} err=$e');
      }

      if (isReceipt && sent) {
        // Receipts have no remote ack — successful send IS the terminal
        // state. Drop the row so we don't keep firing duplicates.
        await outbox.deleteByMsgId(row.msgId);
        continue;
      }

      // Both kinds: on send failure, bump attempt + reschedule per the
      // kind's ladder. Text rows that DID send still bump too — they wait
      // for an inbound delivery_receipt to drop the row.
      final newAttempt = row.attempt + 1;
      final next = isReceipt
          ? nextReceiptRetryAt(attempt: newAttempt, now: now)
          : nextRetryAt(attempt: newAttempt, now: now);
      await outbox.bumpAttempt(row.msgId, next);
    }
  }
}
