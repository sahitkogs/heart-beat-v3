import 'package:drift/drift.dart';

import 'app_database.dart';
import 'models/contact.dart' as model;

/// Persists scanned contacts in the drift SQLite database. Public API
/// identical to the Phase 10.1 SharedPreferences-backed version, with one
/// breaking change: construction is now plain (DI via Riverpod) — the
/// `static Future<ContactsRepository> create()` factory is gone.
class ContactsRepository {
  ContactsRepository(this._db);

  final AppDatabase _db;

  Future<List<model.Contact>> loadAll() async {
    final rows = await _db.select(_db.contacts).get();
    return rows
        .map((r) => model.Contact(pubkeyHex: r.pubkeyHex, addedAt: r.addedAt))
        .toList();
  }

  Future<void> add(model.Contact c) async {
    await _db.into(_db.contacts).insert(
          ContactsCompanion.insert(
            pubkeyHex: c.pubkeyHex,
            addedAt: c.addedAt,
          ),
          mode: InsertMode.insertOrIgnore, // idempotent on pubkeyHex
        );
  }
}
