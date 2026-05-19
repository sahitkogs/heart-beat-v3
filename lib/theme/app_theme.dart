import 'package:flutter/material.dart';

/// Minimal Material 3 theme for v3. Same paper-and-ink spirit as the
/// v1/v2 editorial palette but kept lighter — v3 starts as a tool, not
/// an editorial product.
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFB23A28), // terracotta accent
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFFAF6EF), // off-white paper
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFFAF6EF),
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
