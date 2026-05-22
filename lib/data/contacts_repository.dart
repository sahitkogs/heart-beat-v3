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
        .map((r) => model.Contact(
              pubkeyHex: r.pubkeyHex,
              addedAt: r.addedAt,
              displayName: r.displayName,
              claimedName: r.claimedName,
            ))
        .toList();
  }

  Future<void> add(model.Contact c) async {
    await _db.into(_db.contacts).insert(
          ContactsCompanion.insert(
            pubkeyHex: c.pubkeyHex,
            addedAt: c.addedAt,
            displayName: Value(c.displayName),
            claimedName: Value(c.claimedName),
          ),
          mode: InsertMode.insertOrIgnore, // idempotent on pubkeyHex
        );
  }

  /// Idempotent overwrite of [claimedName] for [pubkeyHex]. No-op if the
  /// contact row doesn't exist (callers must check existence first per
  /// spec §3.3 — names from non-contacts are silently dropped).
  Future<void> updateClaimedName(String pubkeyHex, String claimedName) async {
    await (_db.update(_db.contacts)
          ..where((t) => t.pubkeyHex.equals(pubkeyHex)))
        .write(ContactsCompanion(claimedName: Value(claimedName)));
  }

  /// Overwrite the user-chosen local [displayName] for [pubkeyHex]. Drives
  /// the rename-contact dialog on ContactsScreen. The new value beats any
  /// claimedName per spec §3.2 resolution order.
  Future<void> updateDisplayName(String pubkeyHex, String displayName) async {
    await (_db.update(_db.contacts)
          ..where((t) => t.pubkeyHex.equals(pubkeyHex)))
        .write(ContactsCompanion(displayName: Value(displayName)));
  }

  /// Drop the contact row. Crypto state (libsignal sessions/identities) and
  /// group membership rows are NOT touched here — orchestration of the chat
  /// teardown and group-admin cascade lives in the UI delete flow.
  Future<void> deleteContact(String pubkeyHex) async {
    await (_db.delete(_db.contacts)
          ..where((t) => t.pubkeyHex.equals(pubkeyHex)))
        .go();
  }
}
