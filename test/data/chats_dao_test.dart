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
