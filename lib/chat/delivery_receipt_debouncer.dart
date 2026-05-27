import 'dart:async';

import 'group_envelope.dart';

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
  DeliveryReceiptDebouncer(this._sender);

  final ReceiptSender? _sender;
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
    try {
      await sender.encryptAndSend(peer, envBytes);
    } catch (e, st) {
      // Best-effort. If the receipt send fails, the original sender's
      // retransmitter eventually retries the original message; we'll send
      // a fresh receipt then. No retry queue here on purpose — receipts
      // pile up infinitely if a peer is permanently offline.
      // ignore: avoid_print
      print('[DRD] receipt_send_fail peer=$peer kind=$kind err=$e\n$st');
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
