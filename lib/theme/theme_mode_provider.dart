import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores 'dark' or 'light'. Absent key → default to dark.
const String _kThemeModePrefKey = 'theme_mode';

/// StateNotifier that hydrates from shared_preferences on construction and
/// persists changes on every set. The synchronous initial value is
/// ThemeMode.dark (the default per Phase 10.4.1 UX); hydration updates the
/// state asynchronously if the user had previously chosen light.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _hydrate();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeModePrefKey);
    if (stored == 'light') {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.dark;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kThemeModePrefKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  /// Convenience for the two-state toggle in My Profile.
  Future<void> toggle() async {
    await setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
