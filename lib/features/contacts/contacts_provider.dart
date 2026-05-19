import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../data/contacts_repository.dart';
import '../../data/contacts_repository_legacy.dart';
import '../../data/models/contact.dart' as model;

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => ContactsRepository(ref.watch(appDatabaseProvider)),
);

/// Async one-shot migration: copy legacy SharedPreferences contacts into
/// the drift table, then clear the legacy blob. Idempotent — re-running
/// after migration completes is a no-op.
final contactsMigrationProvider = FutureProvider<void>((ref) async {
  final repo = ref.watch(contactsRepositoryProvider);
  final existing = await repo.loadAll();
  if (existing.isNotEmpty) return; // already migrated (or fresh install with contacts)
  final legacy = await LegacyContactsReader.readAll();
  for (final c in legacy) {
    await repo.add(c);
  }
  await LegacyContactsReader.clear();
});

final contactsListProvider = FutureProvider<List<model.Contact>>((ref) async {
  await ref.watch(contactsMigrationProvider.future); // gate on migration
  final repo = ref.watch(contactsRepositoryProvider);
  return repo.loadAll();
});
