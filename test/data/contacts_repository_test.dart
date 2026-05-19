import 'package:app_v3/data/contacts_repository.dart';
import 'package:app_v3/data/models/contact.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ContactsRepository', () {
    test('loadAll returns empty list when nothing saved', () async {
      final repo = await ContactsRepository.create();
      expect(await repo.loadAll(), isEmpty);
    });

    test('add then loadAll returns the contact', () async {
      final repo = await ContactsRepository.create();
      final c = Contact(
        pubkeyHex: 'aa' * 32,
        addedAt: DateTime.utc(2026, 5, 18, 12),
      );
      await repo.add(c);
      final list = await repo.loadAll();
      expect(list.length, 1);
      expect(list.first.pubkeyHex, c.pubkeyHex);
    });

    test('adding the same pubkey is idempotent', () async {
      final repo = await ContactsRepository.create();
      final c = Contact(
        pubkeyHex: 'aa' * 32,
        addedAt: DateTime.utc(2026, 5, 18, 12),
      );
      await repo.add(c);
      await repo.add(c);
      expect((await repo.loadAll()).length, 1);
    });

    test('contacts persist across repository re-creation', () async {
      final repo1 = await ContactsRepository.create();
      await repo1.add(Contact(
        pubkeyHex: 'aa' * 32,
        addedAt: DateTime.utc(2026, 5, 18, 12),
      ));
      final repo2 = await ContactsRepository.create();
      expect((await repo2.loadAll()).length, 1);
    });
  });
}
