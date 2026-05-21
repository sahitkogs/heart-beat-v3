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

  test('ensureDirectChat is idempotent', () async {
    await dao.ensureDirectChat('peer1');
    await dao.ensureDirectChat('peer1');
    final chats = await dao.watchChats().first;
    expect(chats.length, 1);
  });

  test('bumpLamport monotonically increments', () async {
    await dao.ensureDirectChat('peer1');
    expect(await dao.bumpLamport('peer1'), 1);
    expect(await dao.bumpLamport('peer1'), 2);
    expect(await dao.bumpLamport('peer1'), 3);
  });

  test('observeLamport advances to remote when remote is higher', () async {
    await dao.ensureDirectChat('peer1');
    await dao.bumpLamport('peer1'); // local=1
    final next = await dao.observeLamport('peer1', 10);
    expect(next, 10);
    final after = await dao.bumpLamport('peer1');
    expect(after, 11);
  });

  test('observeLamport keeps local when local is higher', () async {
    await dao.ensureDirectChat('peer1');
    await dao.bumpLamport('peer1'); // 1
    await dao.bumpLamport('peer1'); // 2
    final next = await dao.observeLamport('peer1', 1);
    expect(next, 2);
  });

  // Bundle-exchange state tests (markBundleSent, markPeerBundleReceived,
  // clearBundleSent, mark-on-missing-row) were moved to
  // test/data/peer_bundle_state_dao_test.dart in T3.1 and are fully covered
  // there. They have been removed from this file to avoid duplication.

  test('getChat returns null for unknown peer', () async {
    expect(await dao.getChat('ghost'), isNull);
  });

  test('watchMessages emits ordered by lamport', () async {
    await dao.ensureDirectChat('peer1');
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

  group('group chat methods (T3.4)', () {
    test('insertGroupChat creates a group chat', () async {
      final now = DateTime.utc(2026, 5, 21);
      await dao.insertGroupChat(
        chatId: 'g1',
        groupName: 'Family',
        creatorPubkeyHex: 'A',
        createdAt: now,
        initialOpSeq: 1,
      );
      final c = await dao.getChat('g1');
      expect(c, isNotNull);
      expect(c!.kind, 'group');
      expect(c.groupName, 'Family');
      expect(c.creatorPubkeyHex, 'A');
      expect(c.lastOpSeq, 1);
    });

    test('bumpLastOpSeq updates lastOpSeq', () async {
      final now = DateTime.utc(2026, 5, 21);
      await dao.insertGroupChat(
        chatId: 'g1',
        groupName: 'Family',
        creatorPubkeyHex: 'A',
        createdAt: now,
        initialOpSeq: 1,
      );
      await dao.bumpLastOpSeq('g1', 5);
      expect((await dao.getChat('g1'))!.lastOpSeq, 5);
    });

    test('setLeftAt populates leftAt', () async {
      final now = DateTime.utc(2026, 5, 21);
      await dao.insertGroupChat(
        chatId: 'g1',
        groupName: 'Family',
        creatorPubkeyHex: 'A',
        createdAt: now,
        initialOpSeq: 1,
      );
      final t = DateTime.utc(2026, 5, 22);
      await dao.setLeftAt('g1', t);
      expect((await dao.getChat('g1'))!.leftAt, t);
    });

    test('insertGroupChat is idempotent on duplicate chatId', () async {
      final now = DateTime.utc(2026, 5, 21);
      await dao.insertGroupChat(
        chatId: 'g1',
        groupName: 'First',
        creatorPubkeyHex: 'A',
        createdAt: now,
        initialOpSeq: 1,
      );
      await dao.insertGroupChat(
        chatId: 'g1',
        groupName: 'Second',
        creatorPubkeyHex: 'B',
        createdAt: now,
        initialOpSeq: 9,
      );
      // First insert wins (insertOrIgnore).
      final c = await dao.getChat('g1');
      expect(c!.groupName, 'First');
      expect(c.creatorPubkeyHex, 'A');
    });
  });
}
