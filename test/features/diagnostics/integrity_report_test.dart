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
    // Orphaned: marked sent, no outbox row (sent into the void, unconfirmed).
    await chats.insertMessage(MessagesCompanion.insert(
      id: 'orphan1', chatId: 'peerA', senderPubkeyHex: 'me',
      body: 'lost?', lamport: 1, sentAt: now,
      // deliveryState defaults to sent (index 0).
    ));
    // Not orphaned: sent but still has a live outbox row (being retried).
    await chats.insertMessage(MessagesCompanion.insert(
      id: 'inflight1', chatId: 'peerA', senderPubkeyHex: 'me',
      body: 'retrying', lamport: 2, sentAt: now,
    ));
    await outbox.insert(
      msgId: 'inflight1', peerPubkeyHex: 'peerA', envelopeBytes: [1],
      createdAt: now, nextRetryAt: now,
    );
    // Not orphaned: advanced to delivered.
    await chats.insertMessage(MessagesCompanion.insert(
      id: 'delivered1', chatId: 'peerA', senderPubkeyHex: 'me',
      body: 'ok', lamport: 3, sentAt: now,
      deliveryState: const Value(DeliveryState.delivered),
    ));

    final report = await computeIntegrityReport(db);
    expect(report.orphanedSent, 1);
    expect(report.isClean, isFalse);
  });

  test('countOrphanedSent on ChatsDao counts only sent-with-no-outbox', () async {
    final now = DateTime.now();
    await chats.insertMessage(MessagesCompanion.insert(
      id: 'a', chatId: 'p', senderPubkeyHex: 'me',
      body: 'x', lamport: 1, sentAt: now,
    ));
    await chats.insertMessage(MessagesCompanion.insert(
      id: 'b', chatId: 'p', senderPubkeyHex: 'me',
      body: 'y', lamport: 2, sentAt: now,
      deliveryState: const Value(DeliveryState.read),
    ));
    // 'a' is sent-with-no-outbox -> counted; 'b' is read -> not counted.
    expect(await chats.countOrphanedSent(), 1);
  });
}
