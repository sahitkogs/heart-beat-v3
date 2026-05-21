import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/group_ops_log_dao.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late GroupOpsLogDao dao;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = GroupOpsLogDao(db);
  });
  tearDown(() async => db.close());

  test('forChat returns empty initially', () async {
    expect(await dao.forChat('g1'), isEmpty);
  });

  test('append + forChat returns the row (applied=true)', () async {
    await dao.append(
      id: 'op1',
      chatId: 'g1',
      opSeq: 1,
      kind: 'create',
      signerPubkeyHex: 'creator',
      signatureHex: 'deadbeef',
      applied: true,
    );
    final rows = await dao.forChat('g1');
    expect(rows.length, 1);
    expect(rows.first.kind, 'create');
    expect(rows.first.applied, isTrue);
    expect(rows.first.signerPubkeyHex, 'creator');
  });

  test('append + forChat records rejected ops too', () async {
    await dao.append(
      id: 'op2',
      chatId: 'g1',
      opSeq: 5,
      kind: 'add',
      targetPubkeyHex: 'someone',
      signerPubkeyHex: 'notCreator',
      signatureHex: 'baadf00d',
      applied: false,
    );
    final rows = await dao.forChat('g1');
    expect(rows.length, 1);
    expect(rows.first.applied, isFalse);
    expect(rows.first.targetPubkeyHex, 'someone');
  });

  test('forChat orders by receivedAt ascending', () async {
    await dao.append(
      id: 'a', chatId: 'g1', opSeq: 1, kind: 'create',
      signerPubkeyHex: 's', signatureHex: 'x', applied: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await dao.append(
      id: 'b', chatId: 'g1', opSeq: 2, kind: 'add',
      targetPubkeyHex: 't', signerPubkeyHex: 's', signatureHex: 'y', applied: true,
    );
    final rows = await dao.forChat('g1');
    expect(rows.map((r) => r.id).toList(), ['a', 'b']);
  });

  test('append is idempotent on duplicate id', () async {
    await dao.append(
      id: 'op1', chatId: 'g1', kind: 'leave',
      signerPubkeyHex: 's', signatureHex: 'sig', applied: true,
    );
    await dao.append(
      id: 'op1', chatId: 'g1', kind: 'leave',
      signerPubkeyHex: 's', signatureHex: 'sig', applied: true,
    );
    final rows = await dao.forChat('g1');
    expect(rows.length, 1);
  });

  test('append allows null opSeq (for member_leave)', () async {
    await dao.append(
      id: 'leave1', chatId: 'g1', kind: 'leave',
      signerPubkeyHex: 'leaver', signatureHex: 'sig', applied: true,
    );
    final rows = await dao.forChat('g1');
    expect(rows.first.opSeq, isNull);
  });
}
