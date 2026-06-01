import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/chats_dao.dart';
import 'package:app_v3/data/outbox_dao.dart';
import 'package:app_v3/chat/outbox_retransmitter.dart' show OutboxRetransmitter;
import 'package:app_v3/features/diagnostics/integrity_report.dart';

void main() {
  late AppDatabase db;
  late OutboxDao outbox;
  late ChatsDao chats;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxDao(db);
    chats = ChatsDao(db);
  });

  tearDown(() async => db.close());

  test('clean DB reports nothing and isClean', () async {
    final report = await computeIntegrityReport(db);
    expect(report.stuckOutbox, 0);
    expect(report.orphanedSent, 0);
    expect(report.stuckPeers, isEmpty);
    expect(report.isClean, isTrue);
  });

  test('outbox row older than maxAge is stuck and its peer is flagged',
      () async {
    final now = DateTime.now();
    // 25h ago: past the 24h expiry window but still pending (sweeper missed it).
    final stale = now.subtract(const Duration(hours: 25));
    await outbox.insert(
      msgId: 'stuck1',
      peerPubkeyHex: 'peerStuck',
      envelopeBytes: [1, 2, 3],
      createdAt: stale,
      nextRetryAt: now, // still pending, due
    );
    // A fresh row (well within the window) must NOT count.
    await outbox.insert(
      msgId: 'fresh1',
      peerPubkeyHex: 'peerFresh',
      envelopeBytes: [4],
      createdAt: now,
      nextRetryAt: now,
    );

    final report = await computeIntegrityReport(db);
    expect(report.stuckOutbox, 1);
    expect(report.stuckPeers, contains('peerStuck'));
    expect(report.stuckPeers, isNot(contains('peerFresh')));
    expect(report.isClean, isFalse);
  });

  test('stuckPeers de-duplicates multiple stuck rows for one peer', () async {
    final now = DateTime.now();
    final stale = now.subtract(OutboxRetransmitter.maxAge + const Duration(hours: 1));
    await outbox.insert(
      msgId: 's1', peerPubkeyHex: 'peerX', envelopeBytes: [1],
      createdAt: stale, nextRetryAt: now,
    );
    await outbox.insert(
      msgId: 's2', peerPubkeyHex: 'peerX', envelopeBytes: [2],
      createdAt: stale, nextRetryAt: now,
    );

    final report = await computeIntegrityReport(db);
    expect(report.stuckOutbox, 2);
    expect(report.stuckPeers, ['peerX']);
  });

  test('sent message with no outbox row is orphaned; one with an outbox row is not',
      () async {
    final now = DateTime.now();
    // Orphaned: outbound tick-tracked, marked sent, no outbox row (sent into
    // the void, unconfirmed). knownTicks=true marks it as a genuine outbound
    // row that went through the delivery-tracking path.
    await chats.insertMessage(MessagesCompanion.insert(
      id: 'orphan1', chatId: 'peerA', senderPubkeyHex: 'me',
      body: 'lost?', lamport: 1, sentAt: now,
      knownTicks: const Value(true),
      // deliveryState defaults to sent (index 0).
    ));
    // Not orphaned: sent but still has a live outbox row (being retried).
    await chats.insertMessage(MessagesCompanion.insert(
      id: 'inflight1', chatId: 'peerA', senderPubkeyHex: 'me',
      body: 'retrying', lamport: 2, sentAt: now,
      knownTicks: const Value(true),
    ));
    await outbox.insert(
      msgId: 'inflight1', peerPubkeyHex: 'peerA', envelopeBytes: [1],
      createdAt: now, nextRetryAt: now,
    );
    // Not orphaned: advanced to delivered.
    await chats.insertMessage(MessagesCompanion.insert(
      id: 'delivered1', chatId: 'peerA', senderPubkeyHex: 'me',
      body: 'ok', lamport: 3, sentAt: now,
      knownTicks: const Value(true),
      deliveryState: const Value(DeliveryState.delivered),
    ));

    final report = await computeIntegrityReport(db);
    expect(report.orphanedSent, 1);
    expect(report.isClean, isFalse);
  });

  test('inbound (received) rows are never counted as orphanedSent', () async {
    final now = DateTime.now();
    // An INBOUND message: it came from a peer, so we never sent it, it never
    // gets an outbox row, and it never advances delivery_state (which defaults
    // to sent/0). Crucially knownTicks stays false — inbound rows never write
    // that column. Before the known_ticks gate this row was miscounted as a
    // huge source of phantom "orphaned sent" entries.
    await chats.insertMessage(MessagesCompanion.insert(
      id: 'inbound1', chatId: 'peerA', senderPubkeyHex: 'peerA',
      body: 'hi from peer', lamport: 1, sentAt: now,
      receivedAt: Value(now),
      // deliveryState defaults to sent (0); knownTicks defaults to false.
    ));
    expect(await chats.countOrphanedSent(), 0);
    final report = await computeIntegrityReport(db);
    expect(report.orphanedSent, 0);
    expect(report.isClean, isTrue);
  });

  test('outbound tick-tracked sent-with-no-outbox row IS counted', () async {
    final now = DateTime.now();
    await chats.insertMessage(MessagesCompanion.insert(
      id: 'out1', chatId: 'peerA', senderPubkeyHex: 'me',
      body: 'real send', lamport: 1, sentAt: now,
      knownTicks: const Value(true),
      // deliveryState defaults to sent (0); no outbox row.
    ));
    expect(await chats.countOrphanedSent(), 1);
  });

  test('countOrphanedSent on ChatsDao counts only outbound tick-tracked '
      'sent-with-no-outbox', () async {
    final now = DateTime.now();
    // 'a': outbound, tick-tracked, sent, no outbox row -> counted.
    await chats.insertMessage(MessagesCompanion.insert(
      id: 'a', chatId: 'p', senderPubkeyHex: 'me',
      body: 'x', lamport: 1, sentAt: now,
      knownTicks: const Value(true),
    ));
    // 'b': outbound, tick-tracked, read -> not counted.
    await chats.insertMessage(MessagesCompanion.insert(
      id: 'b', chatId: 'p', senderPubkeyHex: 'me',
      body: 'y', lamport: 2, sentAt: now,
      knownTicks: const Value(true),
      deliveryState: const Value(DeliveryState.read),
    ));
    // 'c': inbound (knownTicks false), default sent state -> NOT counted.
    await chats.insertMessage(MessagesCompanion.insert(
      id: 'c', chatId: 'p', senderPubkeyHex: 'p',
      body: 'z', lamport: 3, sentAt: now,
      receivedAt: Value(now),
    ));
    expect(await chats.countOrphanedSent(), 1);
  });
}
