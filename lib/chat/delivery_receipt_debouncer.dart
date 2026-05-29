import 'dart:async';

import 'package:uuid/uuid.dart';

import '../data/outbox_dao.dart';
import 'group_envelope.dart';
import 'outbox_retransmitter.dart';

const _uuid = Uuid();

/// Indirection the debouncer talks through, so tests can swap a recorder for
/// the real `MessageService._encryptAndSend` + `_currentDisplayName`.
abstract class ReceiptSender {
  Future<String?> currentDisplayName();
  Future<void> encryptAndSend(String peer, List<int> envelopeBytes);
}

class _PendingBatch {
  _PendingBatch();
  final msgIds = <String>{};
  Timer? timer;
}

/// Per-peer accumulator that batches `delivered` msgIds within a 250 ms
/// window. `read` flushes immediately because reads are already batched at
/// the source (chat-thread visibility collects all unread ids in one shot).
class DeliveryReceiptDebouncer {
  DeliveryReceiptDebouncer(this._sender, {OutboxDao? outbox}) : _outbox = outbox;

  final ReceiptSender? _sender;
  // 10.4.3c — when present, every receipt is persisted to outbox before the
  // first send attempt. Successful sends delete the row immediately;
  // failures leave it for the OutboxRetransmitter (5s/10s/30s/5m ladder).
  // Null in legacy stub mode where retry is intentionally disabled.
  final OutboxDao? _outbox;
  final _byPeer = <String, _PendingBatch>{};
  static const _deliveredDelay = Duration(milliseconds: 250);

  void enqueueDelivered({required String peer, required String msgId}) {
    if (_sender == null) return; // stub mode (Task 7 default)
    final batch = _byPeer.putIfAbsent(peer, _PendingBatch.new);
    batch.msgIds.add(msgId);
    batch.timer ??= Timer(_deliveredDelay, () => _flushDelivered(peer));
  }

  void enqueueRead({required String peer, required List<String> msgIds}) {
    if (msgIds.isEmpty) return;
    if (_sender == null) return; // stub mode
    // Fire-and-forget; failures are logged but not awaited (caller is a UI
    // visibility hook, must not block the frame).
    _send(peer, List<String>.from(msgIds), ReceiptKind.read);
  }

  Future<void> _flushDelivered(String peer) async {
    final batch = _byPeer.remove(peer);
    if (batch == null || batch.msgIds.isEmpty) return;
    batch.timer?.cancel();
    await _send(peer, batch.msgIds.toList(), ReceiptKind.delivered);
  }

  Future<void> _send(
      String peer, List<String> msgIds, ReceiptKind kind) async {
    final sender = _sender;
    if (sender == null) return;
    final myName = await sender.currentDisplayName();
    final envBytes = InnerEnvelope.buildDeliveryReceipt(
      chatId: peer,
      msgIds: msgIds,
      kind: kind,
      at: DateTime.now(),
      senderDisplayName: myName,
    );

    // 10.4.3c — persist BEFORE the first send so a relay-disconnect failure
    // doesn't drop the receipt on the floor (matches WhatsApp semantics —
    // delivered/read state must survive the recipient bouncing offline).
    // The synthetic msgId is a uuid: receipt rows aren't keyed by any
    // referenced inner.msgId because a single envelope can batch many.
    final outboxRowId = _uuid.v4();
    final outbox = _outbox;
    if (outbox != null) {
      final now = DateTime.now();
      await outbox.insert(
        msgId: outboxRowId,
        peerPubkeyHex: peer,
        envelopeBytes: envBytes,
        createdAt: now,
        nextRetryAt:
            OutboxRetransmitter.nextReceiptRetryAt(attempt: 1, now: now),
        kind: 'receipt',
      );
    }

    try {
      await sender.encryptAndSend(peer, envBytes);
      // Success → drain the receipt row (no remote ack needed; receipts
      // are themselves the ack).
      if (outbox != null) {
        await outbox.deleteByMsgId(outboxRowId);
      }
    } catch (e, st) {
      // ignore: avoid_print
      print(outbox == null
          ? '[DRD] receipt_send_fail peer=$peer kind=$kind err=$e\n$st'
          : '[DRD] receipt_queued_for_retry peer=$peer kind=$kind '
              'rowId=$outboxRowId err=$e');
    }
  }

  /// Test-only — drain every pending batch synchronously.
  Future<void> flushAllForTest() async {
    final peers = _byPeer.keys.toList();
    for (final p in peers) {
      await _flushDelivered(p);
    }
  }

  void dispose() {
    for (final b in _byPeer.values) {
      b.timer?.cancel();
    }
    _byPeer.clear();
  }
}
