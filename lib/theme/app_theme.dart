import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Italic serif display style — section headings ("your *chats*"). Mirrors
/// v1's kDisplaySerif.
const TextStyle kDisplaySerif = TextStyle(
  fontFamily: 'serif',
  fontStyle: FontStyle.italic,
  fontWeight: FontWeight.w600,
);

/// Light theme — paper-and-ink editorial spirit. Ported from v1's
/// buildHeartbeatTheme().
ThemeData buildLightTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      primary: AppColors.accent,
      onPrimary: AppColors.paper,
    ),
    textTheme: base.textTheme
        .apply(
          fontFamily: 'serif',
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        )
        .copyWith(
          headlineMedium: const TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            fontSize: 28,
            height: 1.15,
          ),
          titleLarge: const TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            fontSize: 22,
            height: 1.2,
          ),
          bodyLarge: const TextStyle(
            fontFamily: 'serif',
            color: AppColors.ink,
            fontSize: 17,
            height: 1.5,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: true,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.rule, thickness: 1),
    cardTheme: const CardThemeData(
      color: AppColors.paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.rule),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'serif',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.rule),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'serif',
          fontSize: 15,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.paper,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
  );
}

/// Dark theme — warm near-black + same terracotta accent + serif typography.
/// New for v3; v1 was light-only.
ThemeData buildDarkTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bgDark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      surface: AppColors.bgDark,
      onSurface: AppColors.inkOnDark,
      primary: AppColors.accent,
      onPrimary: AppColors.paper,
    ),
    textTheme: base.textTheme
        .apply(
          fontFamily: 'serif',
          bodyColor: AppColors.inkOnDark,
          displayColor: AppColors.inkOnDark,
        )
        .copyWith(
          headlineMedium: const TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            color: AppColors.inkOnDark,
            fontSize: 28,
            height: 1.15,
          ),
          titleLarge: const TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            color: AppColors.inkOnDark,
            fontSize: 22,
            height: 1.2,
          ),
          bodyLarge: const TextStyle(
            fontFamily: 'serif',
            color: AppColors.inkOnDark,
            fontSize: 17,
            height: 1.5,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgDark,
      foregroundColor: AppColors.inkOnDark,
      elevation: 0,
      centerTitle: true,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.ruleDark, thickness: 1),
    cardTheme: const CardThemeData(
      color: AppColors.surfaceDark,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.ruleDark),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'serif',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.inkOnDark,
        side: const BorderSide(color: AppColors.ruleDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'serif',
          fontSize: 15,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.paper,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.ruleDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.ruleDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
    ),
  );
}

/// Legacy alias for callers that haven't been migrated. Returns the light
/// theme (used as a fallback during cold start before themeModeProvider
/// resolves).
ThemeData buildAppTheme() => buildLightTheme();
