import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/contact.dart';

/// Persists the user's scanned-contacts list in SharedPreferences.
/// Phase 10.1 only — moves to a drift table in Phase 10.2 when we need
/// to associate contacts with chats and message history.
class ContactsRepository {
  ContactsRepository._(this._prefs);

  static const String _key = 'hb_v3_contacts';

  final SharedPreferences _prefs;

  /// Async constructor required because SharedPreferences.getInstance() is async.
  static Future<ContactsRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ContactsRepository._(prefs);
  }

  Future<List<Contact>> loadAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Contact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(Contact c) async {
    final current = await loadAll();
    if (current.any((e) => e.pubkeyHex == c.pubkeyHex)) {
      return; // idempotent
    }
    final updated = [...current, c];
    await _prefs.setString(
      _key,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }
}
