import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/group_members_dao.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late GroupMembersDao dao;
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = GroupMembersDao(db);
  });
  tearDown(() async => db.close());

  test('activeMembers empty initially', () async {
    expect(await dao.activeMembers('g1'), isEmpty);
  });

  test('insertMember + activeMembers', () async {
    final t = DateTime.utc(2026, 5, 21);
    await dao.insertMember(chatId: 'g1', memberPubkeyHex: 'A', addedByPubkeyHex: 'A', addedAt: t);
    await dao.insertMember(chatId: 'g1', memberPubkeyHex: 'B', addedByPubkeyHex: 'A', addedAt: t);
    final active = await dao.activeMembers('g1');
    expect(active.map((m) => m.memberPubkeyHex).toSet(), {'A', 'B'});
  });

  test('markRemoved excludes from activeMembers', () async {
    final t = DateTime.utc(2026, 5, 21);
    await dao.insertMember(chatId: 'g1', memberPubkeyHex: 'A', addedByPubkeyHex: 'A', addedAt: t);
    await dao.insertMember(chatId: 'g1', memberPubkeyHex: 'B', addedByPubkeyHex: 'A', addedAt: t);
    await dao.markRemoved(chatId: 'g1', memberPubkeyHex: 'B', removedAt: t);
    final active = await dao.activeMembers('g1');
    expect(active.map((m) => m.memberPubkeyHex).toList(), ['A']);
    final all = await dao.allMembers('g1');
    expect(all.length, 2);
  });

  test('isActiveMember', () async {
    final t = DateTime.utc(2026, 5, 21);
    await dao.insertMember(chatId: 'g1', memberPubkeyHex: 'A', addedByPubkeyHex: 'A', addedAt: t);
    expect(await dao.isActiveMember('g1', 'A'), isTrue);
    expect(await dao.isActiveMember('g1', 'Z'), isFalse);
    await dao.markRemoved(chatId: 'g1', memberPubkeyHex: 'A', removedAt: t);
    expect(await dao.isActiveMember('g1', 'A'), isFalse);
  });

  test('insertMember is idempotent', () async {
    final t = DateTime.utc(2026, 5, 21);
    await dao.insertMember(chatId: 'g1', memberPubkeyHex: 'A', addedByPubkeyHex: 'A', addedAt: t);
    await dao.insertMember(chatId: 'g1', memberPubkeyHex: 'A', addedByPubkeyHex: 'A', addedAt: t);
    final all = await dao.allMembers('g1');
    expect(all.length, 1);
  });
}
