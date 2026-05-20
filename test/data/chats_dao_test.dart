import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/chats_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ChatsDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ChatsDao(db);
  });

  tearDown(() => db.close());

  test('ensureChat is idempotent', () async {
    await dao.ensureChat('peer1');
    await dao.ensureChat('peer1');
    final chats = await dao.watchChats().first;
    expect(chats.length, 1);
  });

  test('bumpLamport monotonically increments', () async {
    await dao.ensureChat('peer1');
    expect(await dao.bumpLamport('peer1'), 1);
    expect(await dao.bumpLamport('peer1'), 2);
    expect(await dao.bumpLamport('peer1'), 3);
  });

  test('observeLamport advances to remote when remote is higher', () async {
    await dao.ensureChat('peer1');
    await dao.bumpLamport('peer1'); // local=1
    final next = await dao.observeLamport('peer1', 10);
    expect(next, 10);
    final after = await dao.bumpLamport('peer1');
    expect(after, 11);
  });

  test('observeLamport keeps local when local is higher', () async {
    await dao.ensureChat('peer1');
    await dao.bumpLamport('peer1'); // 1
    await dao.bumpLamport('peer1'); // 2
    final next = await dao.observeLamport('peer1', 1);
    expect(next, 2);
  });

  group('bundle exchange state (schema v4)', () {
    test('fresh chat row has nullable bundle timestamps', () async {
      await dao.ensureChat('peer1');
      final row = await dao.getChat('peer1');
      expect(row, isNotNull);
      expect(row!.bundleSentAt, isNull);
      expect(row.peerBundleReceivedAt, isNull);
    });

    test('markBundleSent persists a timestamp', () async {
      await dao.ensureChat('peer1');
      final t = DateTime.utc(2026, 5, 20, 12);
      await dao.markBundleSent('peer1', at: t);
      final row = await dao.getChat('peer1');
      expect(row!.bundleSentAt, t);
      expect(row.peerBundleReceivedAt, isNull);
    });

    test('markPeerBundleReceived persists a timestamp', () async {
      await dao.ensureChat('peer1');
      final t = DateTime.utc(2026, 5, 20, 13);
      await dao.markPeerBundleReceived('peer1', at: t);
      final row = await dao.getChat('peer1');
      expect(row!.peerBundleReceivedAt, t);
      expect(row.bundleSentAt, isNull);
    });

    test('clearBundleSent resets bundleSentAt to null', () async {
      await dao.ensureChat('peer1');
      await dao.markBundleSent('peer1', at: DateTime.utc(2026, 5, 20));
      await dao.clearBundleSent('peer1');
      final row = await dao.getChat('peer1');
      expect(row!.bundleSentAt, isNull);
    });

    test('getChat returns null for unknown peer', () async {
      expect(await dao.getChat('ghost'), isNull);
    });

    test('mark* on missing chat row is a silent no-op', () async {
      await dao.markBundleSent('ghost');
      await dao.markPeerBundleReceived('ghost');
      expect(await dao.getChat('ghost'), isNull);
    });
  });

  test('watchMessages emits ordered by lamport', () async {
    await dao.ensureChat('peer1');
    await dao.insertMessage(MessagesCompanion.insert(
      id: 'm1',
      chatId: 'peer1',
      senderPubkeyHex: 'a',
      body: 'hi',
      lamport: 2,
      sentAt: DateTime.utc(2026, 5, 18, 10),
    ));
    await dao.insertMessage(MessagesCompanion.insert(
      id: 'm2',
      chatId: 'peer1',
      senderPubkeyHex: 'b',
      body: 'hey',
      lamport: 1,
      sentAt: DateTime.utc(2026, 5, 18, 11),
    ));
    final msgs = await dao.watchMessages('peer1').first;
    expect(msgs.map((m) => m.id).toList(), ['m2', 'm1']);
  });
}
