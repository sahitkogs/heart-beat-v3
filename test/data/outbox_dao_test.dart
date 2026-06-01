import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/outbox_dao.dart';

void main() {
  late AppDatabase db;
  late OutboxDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = OutboxDao(db);
  });

  tearDown(() async => db.close());

  test('insert + findByMsgId round-trip', () async {
    final now = DateTime.now();
    await dao.insert(
      msgId: 'm1', peerPubkeyHex: 'peerA',
      envelopeBytes: [1, 2, 3],
      createdAt: now, nextRetryAt: now.add(const Duration(seconds: 30)),
    );
    final row = await dao.findByMsgId('m1');
    expect(row, isNotNull);
    expect(row!.peerPubkeyHex, 'peerA');
    expect(row.envelopeBytes, [1, 2, 3]);
    expect(row.attempt, 0);
  });

  test('findByMsgId returns null for missing', () async {
    expect(await dao.findByMsgId('nope'), isNull);
  });

  test('dueBefore returns only rows past nextRetryAt, ordered by createdAt', () async {
    final t0 = DateTime(2026, 5, 26, 12, 0, 0);
    await dao.insert(msgId: 'a', peerPubkeyHex: 'p', envelopeBytes: [1],
        createdAt: t0, nextRetryAt: t0.add(const Duration(seconds: 10)));
    await dao.insert(msgId: 'b', peerPubkeyHex: 'p', envelopeBytes: [2],
        createdAt: t0.add(const Duration(seconds: 1)),
        nextRetryAt: t0.add(const Duration(seconds: 60)));
    await dao.insert(msgId: 'c', peerPubkeyHex: 'p', envelopeBytes: [3],
        createdAt: t0.add(const Duration(seconds: 2)),
        nextRetryAt: t0.add(const Duration(seconds: 5)));

    final due = await dao.dueBefore(t0.add(const Duration(seconds: 30)));
    expect(due.map((r) => r.msgId).toList(), ['a', 'c']);
  });

  test('bumpAttempt updates attempt + nextRetryAt', () async {
    final now = DateTime.now();
    await dao.insert(msgId: 'm', peerPubkeyHex: 'p', envelopeBytes: [9],
        createdAt: now, nextRetryAt: now);
    final next = now.add(const Duration(minutes: 5));
    await dao.bumpAttempt('m', next);
    final row = await dao.findByMsgId('m');
    expect(row!.attempt, 1);
    expect(row.nextRetryAt, next);
  });

  test('deleteByMsgId removes the row', () async {
    final now = DateTime.now();
    await dao.insert(msgId: 'm', peerPubkeyHex: 'p', envelopeBytes: [1],
        createdAt: now, nextRetryAt: now);
    await dao.deleteByMsgId('m');
    expect(await dao.findByMsgId('m'), isNull);
  });

  test('markPeerFailed deletes only that peer\'s rows', () async {
    final now = DateTime.now();
    await dao.insert(msgId: 'p1m1', peerPubkeyHex: 'peerA', envelopeBytes: [1],
        createdAt: now, nextRetryAt: now);
    await dao.insert(msgId: 'p1m2', peerPubkeyHex: 'peerA', envelopeBytes: [2],
        createdAt: now, nextRetryAt: now);
    await dao.insert(msgId: 'p2m1', peerPubkeyHex: 'peerB', envelopeBytes: [3],
        createdAt: now, nextRetryAt: now);

    final dropped = await dao.markPeerFailed('peerA');
    expect(dropped, 2);
    expect(await dao.findByMsgId('p1m1'), isNull);
    expect(await dao.findByMsgId('p1m2'), isNull);
    expect(await dao.findByMsgId('p2m1'), isNotNull);
  });

  test('kickPeer resets nextRetryAt to now for that peer only', () async {
    final future = DateTime.now().add(const Duration(hours: 1));
    await dao.insert(
      msgId: 'm1', peerPubkeyHex: 'peerA', envelopeBytes: [1],
      createdAt: DateTime.now(), nextRetryAt: future,
    );
    await dao.insert(
      msgId: 'm2', peerPubkeyHex: 'peerB', envelopeBytes: [2],
      createdAt: DateTime.now(), nextRetryAt: future,
    );

    final now = DateTime.now();
    final kicked = await dao.kickPeer('peerA', now);
    expect(kicked, 1);

    final due = await dao.dueBefore(now.add(const Duration(seconds: 1)));
    expect(due.map((r) => r.msgId), contains('m1'));
    expect(due.map((r) => r.msgId), isNot(contains('m2')));
  });
}
