import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/contact.dart';

/// One-shot reader of the Phase 10.1 SharedPreferences contacts blob.
/// After v3 Phase 10.2 migration completes, this file remains but is only
/// called once at startup; if it returns an empty list, migration has
/// nothing to do.
class LegacyContactsReader {
  static const String _key = 'hb_v3_contacts';

  static Future<List<Contact>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Contact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
