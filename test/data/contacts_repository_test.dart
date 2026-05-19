import 'package:app_v3/data/app_database.dart';
import 'package:app_v3/data/contacts_repository.dart';
import 'package:app_v3/data/models/contact.dart' as model;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ContactsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ContactsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('loadAll returns empty initially', () async {
    expect(await repo.loadAll(), isEmpty);
  });

  test('add then loadAll returns the contact', () async {
    final c = model.Contact(
      pubkeyHex: 'aa' * 32,
      addedAt: DateTime.utc(2026, 5, 18, 12),
    );
    await repo.add(c);
    final list = await repo.loadAll();
    expect(list.length, 1);
    expect(list.first.pubkeyHex, c.pubkeyHex);
  });

  test('adding same pubkey is idempotent', () async {
    final c = model.Contact(
      pubkeyHex: 'aa' * 32,
      addedAt: DateTime.utc(2026, 5, 18, 12),
    );
    await repo.add(c);
    await repo.add(c);
    expect((await repo.loadAll()).length, 1);
  });

  test('contacts persist across repository instances on same DB', () async {
    final c = model.Contact(
      pubkeyHex: 'aa' * 32,
      addedAt: DateTime.utc(2026, 5, 18, 12),
    );
    await repo.add(c);
    final repo2 = ContactsRepository(db);
    expect((await repo2.loadAll()).length, 1);
  });
}
