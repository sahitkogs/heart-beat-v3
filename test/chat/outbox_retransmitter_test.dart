import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_v3/chat/outbox_retransmitter.dart';
import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/chats_dao.dart';
import 'package:app_v3/data/outbox_dao.dart';

/// Captures send attempts so tests can inject success/failure outcomes.
class _RecordingSender implements RetransmitSender {
  final calls = <_Sent>[];
  bool fail = false;
  @override
  Future<void> sendOnce(String peer, List<int> envelopeBytes) async {
    calls.add(_Sent(peer, envelopeBytes));
    if (fail) throw Exception('send failed');
  }
}

class _Sent {
  _Sent(this.peer, this.bytes);
  final String peer;
  final List<int> bytes;
}

void main() {
  late AppDatabase db;
  late OutboxDao outbox;
  late ChatsDao chats;
  late _RecordingSender sender;
  late OutboxRetransmitter rx;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxDao(db);
    chats = ChatsDao(db);
    sender = _RecordingSender();
    rx = OutboxRetransmitter(outbox: outbox, chats: chats, sender: sender);
  });

  tearDown(() async {
    rx.stop();
    await db.close();
  });

  Future<String> seed({
    required DateTime createdAt,
    required DateTime nextRetryAt,
  }) async {
    final id = 'm-${createdAt.microsecondsSinceEpoch}';
    await chats.insertMessage(MessagesCompanion.insert(
      id: id, chatId: 'peerA', senderPubkeyHex: 'me',
      body: 'x', lamport: 1, sentAt: createdAt,
    ));
    await outbox.insert(
      msgId: id, peerPubkeyHex: 'peerA', envelopeBytes: [1, 2, 3],
      createdAt: createdAt, nextRetryAt: nextRetryAt,
    );
    return id;
  }

  test('sweep retransmits only rows past nextRetryAt', () async {
    final t = DateTime.now();
    final dueId = await seed(
      createdAt: t.subtract(const Duration(minutes: 5)),
      nextRetryAt: t.subtract(const Duration(seconds: 1)),
    );
    final notDueId = await seed(
      createdAt: t,
      nextRetryAt: t.add(const Duration(minutes: 1)),
    );
    await rx.sweepOnceForTest(now: t);
    expect(sender.calls.map((c) => c.peer).toList(), ['peerA']);
    expect(sender.calls.single.bytes, [1, 2, 3]);

    // dueId stays in the outbox (push success doesn't delete it — that's
    // the receipt's job), but its attempt + nextRetryAt have advanced.
    final dueRow = await outbox.findByMsgId(dueId);
    expect(dueRow!.attempt, 1);
    expect(dueRow.nextRetryAt.isAfter(t), isTrue);
    // notDueId untouched.
    expect((await outbox.findByMsgId(notDueId))!.attempt, 0);
  });

  test('ladder picks 30s / 60s / 5m / 30m / 1h then sticks at 1h', () {
    final t = DateTime(2026, 5, 26, 12, 0, 0);
    expect(OutboxRetransmitter.nextRetryAt(attempt: 1, now: t),
        t.add(const Duration(seconds: 30)));
    expect(OutboxRetransmitter.nextRetryAt(attempt: 2, now: t),
        t.add(const Duration(seconds: 60)));
    expect(OutboxRetransmitter.nextRetryAt(attempt: 3, now: t),
        t.add(const Duration(minutes: 5)));
    expect(OutboxRetransmitter.nextRetryAt(attempt: 4, now: t),
        t.add(const Duration(minutes: 30)));
    expect(OutboxRetransmitter.nextRetryAt(attempt: 5, now: t),
        t.add(const Duration(hours: 1)));
    expect(OutboxRetransmitter.nextRetryAt(attempt: 99, now: t),
        t.add(const Duration(hours: 1)));
  });

  test('24h expiry marks the row failed and removes it from outbox', () async {
    final t = DateTime.now();
    final id = await seed(
      createdAt: t.subtract(const Duration(hours: 25)),
      nextRetryAt: t.subtract(const Duration(seconds: 1)),
    );
    await rx.sweepOnceForTest(now: t);
    expect(await outbox.findByMsgId(id), isNull);
    expect((await chats.findMessageById(id))!.deliveryState,
        DeliveryState.failed);
  });

  test('send failure still bumps attempt — caller retries next sweep', () async {
    final t = DateTime.now();
    final id = await seed(
      createdAt: t,
      nextRetryAt: t.subtract(const Duration(seconds: 1)),
    );
    sender.fail = true;
    await rx.sweepOnceForTest(now: t);
    final row = await outbox.findByMsgId(id);
    expect(row!.attempt, 1);
    expect(row.nextRetryAt.isAfter(t), isTrue);
  });

  group('10.4.3c — receipt rows', () {
    Future<String> seedReceipt({
      required DateTime createdAt,
      required DateTime nextRetryAt,
      String peer = 'peerA',
    }) async {
      final id = 'receipt-${createdAt.microsecondsSinceEpoch}';
      await outbox.insert(
        msgId: id,
        peerPubkeyHex: peer,
        envelopeBytes: const [9, 9, 9],
        createdAt: createdAt,
        nextRetryAt: nextRetryAt,
        kind: 'receipt',
      );
      return id;
    }

    test('successful send deletes the receipt row (no waiting for ack)',
        () async {
      final t = DateTime.now();
      final id = await seedReceipt(
        createdAt: t,
        nextRetryAt: t.subtract(const Duration(seconds: 1)),
      );
      await rx.sweepOnceForTest(now: t);
      expect(sender.calls, hasLength(1));
      expect(await outbox.findByMsgId(id), isNull);
    });

    test('failed send leaves the receipt row + bumps attempt via 5/10/30/5m',
        () async {
      final t = DateTime.now();
      final id = await seedReceipt(
        createdAt: t,
        nextRetryAt: t.subtract(const Duration(seconds: 1)),
      );
      sender.fail = true;
      await rx.sweepOnceForTest(now: t);
      final row = await outbox.findByMsgId(id);
      expect(row, isNotNull);
      expect(row!.attempt, 1);
      // First retry slot is 5s after now (matches nextReceiptRetryAt(1)).
      expect(row.nextRetryAt, t.add(const Duration(seconds: 5)));
    });

    test('receipt ladder picks 5s / 10s / 30s / 5m then sticks at 5m', () {
      final t = DateTime(2026, 5, 26, 12, 0, 0);
      expect(OutboxRetransmitter.nextReceiptRetryAt(attempt: 1, now: t),
          t.add(const Duration(seconds: 5)));
      expect(OutboxRetransmitter.nextReceiptRetryAt(attempt: 2, now: t),
          t.add(const Duration(seconds: 10)));
      expect(OutboxRetransmitter.nextReceiptRetryAt(attempt: 3, now: t),
          t.add(const Duration(seconds: 30)));
      expect(OutboxRetransmitter.nextReceiptRetryAt(attempt: 4, now: t),
          t.add(const Duration(minutes: 5)));
      expect(OutboxRetransmitter.nextReceiptRetryAt(attempt: 99, now: t),
          t.add(const Duration(minutes: 5)));
    });

    test('24h expiry silently drops receipt — no chats.updateDeliveryState',
        () async {
      // A receipt isn't tied to a specific outbound message row on this
      // device, so the existing 24h text path (mark messages.deliveryState
      // = failed) is wrong. Receipt rows just disappear.
      final t = DateTime.now();
      final id = await seedReceipt(
        createdAt: t.subtract(const Duration(hours: 25)),
        nextRetryAt: t.subtract(const Duration(seconds: 1)),
      );
      await rx.sweepOnceForTest(now: t);
      expect(await outbox.findByMsgId(id), isNull);
      // The receipt's synthetic id is not a real messages.id, so updating
      // its delivery_state would be a no-op AT BEST — but more importantly
      // would be conceptually wrong. Assert nothing exploded.
      expect(sender.calls, isEmpty); // expired before any send
    });

    test('mixed text+receipt rows: each follows its own ladder', () async {
      final t = DateTime.now();
      final textId = await seed(
        createdAt: t,
        nextRetryAt: t.subtract(const Duration(seconds: 1)),
      );
      final receiptId = await seedReceipt(
        createdAt: t,
        nextRetryAt: t.subtract(const Duration(seconds: 1)),
      );
      sender.fail = true;
      await rx.sweepOnceForTest(now: t);
      final textRow = await outbox.findByMsgId(textId);
      final receiptRow = await outbox.findByMsgId(receiptId);
      // Text uses 30s ladder slot, receipt uses 5s.
      expect(textRow!.nextRetryAt, t.add(const Duration(seconds: 30)));
      expect(receiptRow!.nextRetryAt, t.add(const Duration(seconds: 5)));
    });
  });
}
