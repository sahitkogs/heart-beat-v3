import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_v3/chat/delivery_receipt_debouncer.dart';
import 'package:app_v3/chat/group_envelope.dart';
import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/outbox_dao.dart';

/// Records the envelopes the debouncer ships, so tests can assert without
/// touching a real CryptoService / RelayClient.
class _RecordingSender implements ReceiptSender {
  final calls = <_Call>[];
  String? displayName;
  bool failNext = false;
  @override
  Future<String?> currentDisplayName() async => displayName;
  @override
  Future<void> encryptAndSend(String peer, List<int> envelopeBytes) async {
    if (failNext) {
      failNext = false;
      throw StateError('relay disconnected');
    }
    calls.add(_Call(peer, envelopeBytes));
  }
}

class _Call {
  _Call(this.peer, this.bytes);
  final String peer;
  final List<int> bytes;
}

void main() {
  late _RecordingSender sender;
  late DeliveryReceiptDebouncer deb;

  setUp(() {
    sender = _RecordingSender();
    deb = DeliveryReceiptDebouncer(sender);
  });

  tearDown(() => deb.dispose());

  test('delivered within 250ms is batched into one envelope', () async {
    deb.enqueueDelivered(peer: 'A', msgId: 'm1');
    deb.enqueueDelivered(peer: 'A', msgId: 'm2');
    deb.enqueueDelivered(peer: 'A', msgId: 'm3');
    expect(sender.calls, isEmpty); // not yet flushed

    await Future<void>.delayed(const Duration(milliseconds: 320));
    expect(sender.calls, hasLength(1));
    final parsed = InnerEnvelope.parse(sender.calls.single.bytes)
        as DeliveryReceiptEnvelope;
    expect(parsed.msgIds, ['m1', 'm2', 'm3']);
    expect(parsed.kind, ReceiptKind.delivered);
  });

  test('multi-peer batches stay independent', () async {
    deb.enqueueDelivered(peer: 'A', msgId: 'a1');
    deb.enqueueDelivered(peer: 'B', msgId: 'b1');
    await Future<void>.delayed(const Duration(milliseconds: 320));
    expect(sender.calls, hasLength(2));
    final peers = sender.calls.map((c) => c.peer).toSet();
    expect(peers, {'A', 'B'});
  });

  test('enqueueRead flushes immediately and bypasses the 250ms timer', () async {
    deb.enqueueRead(peer: 'A', msgIds: ['m1', 'm2']);
    await pumpEventQueue();
    expect(sender.calls, hasLength(1));
    final parsed = InnerEnvelope.parse(sender.calls.single.bytes)
        as DeliveryReceiptEnvelope;
    expect(parsed.kind, ReceiptKind.read);
    expect(parsed.msgIds, ['m1', 'm2']);
  });

  test('enqueueRead with empty list is a no-op', () async {
    deb.enqueueRead(peer: 'A', msgIds: []);
    await pumpEventQueue();
    expect(sender.calls, isEmpty);
  });

  group('10.4.3c — receipt outbox', () {
    late AppDatabase db;
    late OutboxDao outbox;
    late DeliveryReceiptDebouncer debWithOutbox;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      outbox = OutboxDao(db);
      debWithOutbox = DeliveryReceiptDebouncer(sender, outbox: outbox);
    });

    tearDown(() async {
      debWithOutbox.dispose();
      await db.close();
    });

    test('successful send leaves zero outbox rows', () async {
      debWithOutbox.enqueueRead(peer: 'A', msgIds: ['m1', 'm2']);
      await pumpEventQueue();
      expect(sender.calls, hasLength(1));
      // Row was inserted then deleted — net zero.
      final due = await outbox.dueBefore(
          DateTime.now().add(const Duration(days: 1)));
      expect(due, isEmpty);
    });

    test('failed send leaves a receipt row in outbox for retry', () async {
      sender.failNext = true;
      debWithOutbox.enqueueRead(peer: 'A', msgIds: ['m1']);
      await pumpEventQueue();
      expect(sender.calls, isEmpty); // send threw before recording
      // Row remains with kind='receipt' and the receipt envelope inside.
      final rows = await outbox.dueBefore(
          DateTime.now().add(const Duration(days: 1)));
      expect(rows, hasLength(1));
      expect(rows.single.kind, 'receipt');
      expect(rows.single.peerPubkeyHex, 'A');
      final inner = InnerEnvelope.parse(rows.single.envelopeBytes)
          as DeliveryReceiptEnvelope;
      expect(inner.kind, ReceiptKind.read);
      expect(inner.msgIds, ['m1']);
    });

    test('delivered batch failure persists a single batched receipt row',
        () async {
      sender.failNext = true;
      debWithOutbox.enqueueDelivered(peer: 'A', msgId: 'm1');
      debWithOutbox.enqueueDelivered(peer: 'A', msgId: 'm2');
      await Future<void>.delayed(const Duration(milliseconds: 320));
      // One row, but it carries BOTH msgIds (batched receipt).
      final rows = await outbox.dueBefore(
          DateTime.now().add(const Duration(days: 1)));
      expect(rows, hasLength(1));
      final inner = InnerEnvelope.parse(rows.single.envelopeBytes)
          as DeliveryReceiptEnvelope;
      expect(inner.kind, ReceiptKind.delivered);
      expect(inner.msgIds, ['m1', 'm2']);
    });
  });

  test('null outbox (stub mode for legacy callers) does not crash on send',
      () async {
    // Constructed without an outbox — existing pre-10.4.3c behaviour is
    // preserved: receipts are best-effort fire-and-forget with no retry.
    final legacy = DeliveryReceiptDebouncer(sender);
    legacy.enqueueRead(peer: 'A', msgIds: ['m1']);
    await pumpEventQueue();
    expect(sender.calls, hasLength(1));
    legacy.dispose();
  });
}
