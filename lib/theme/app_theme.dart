import 'package:flutter/material.dart';

const Color _kSeed = Color(0xFFB23A28); // terracotta accent (shared)
const Color _kLightPaper = Color(0xFFFAF6EF); // off-white paper
const Color _kDarkBg = Color(0xFF161412); // near-black with a warm tint
const Color _kDarkSurface = Color(0xFF1F1B19);

/// Light theme — paper-and-ink editorial spirit, same palette as v1/v2.
ThemeData buildLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _kSeed,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: _kLightPaper,
    appBarTheme: AppBarTheme(
      backgroundColor: _kLightPaper,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

/// Dark theme — warm near-black with the same terracotta seed.
ThemeData buildDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _kSeed,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: _kDarkBg,
    appBarTheme: AppBarTheme(
      backgroundColor: _kDarkBg,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: _kDarkSurface,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

/// Legacy alias for any callers still on the pre-10.4.1 API. Returns the
/// light theme (used as a fallback during cold start before the
/// themeModeProvider resolves).
ThemeData buildAppTheme() => buildLightTheme();
