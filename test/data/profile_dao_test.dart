import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/profile_dao.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProfileDao dao;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ProfileDao(db);
  });
  tearDown(() async => db.close());

  test('get returns null when no row exists', () async {
    expect(await dao.get(), isNull);
  });

  test('setDisplayName creates the row on first call', () async {
    final t = DateTime.utc(2026, 5, 21);
    await dao.setDisplayName('Sahit', at: t);
    final row = await dao.get();
    expect(row, isNotNull);
    expect(row!.displayName, 'Sahit');
    expect(row.updatedAt, t);
  });

  test('setDisplayName updates the row on subsequent calls', () async {
    final t1 = DateTime.utc(2026, 5, 21);
    final t2 = DateTime.utc(2026, 5, 22);
    await dao.setDisplayName('Sahit', at: t1);
    await dao.setDisplayName('Sahit K.', at: t2);
    final row = await dao.get();
    expect(row!.displayName, 'Sahit K.');
    expect(row.updatedAt, t2);
  });

  test('watch emits on changes', () async {
    final stream = dao.watch();
    final emitted = <ProfileData?>[];
    final sub = stream.listen(emitted.add);
    // Initial null emission from watchSingleOrNull on empty table.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await dao.setDisplayName('first', at: DateTime.utc(2026, 5, 21));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await dao.setDisplayName('second', at: DateTime.utc(2026, 5, 22));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(emitted.map((p) => p?.displayName).toList(), [null, 'first', 'second']);
  });
}
