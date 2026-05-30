import 'package:flutter/material.dart';

/// Paper-and-ink palette ported from v1 (heart-beat/app/lib/core/theme.dart),
/// extended with dark-mode tokens for v3.
///
/// Light tokens (paper/ink) and accent are shared across both themes;
/// dark tokens (bgDark / surfaceDark / inkOnDark / inkSoftOnDark / ruleDark)
/// are dark-mode only. Accent is unchanged across modes — 6.1:1 contrast on
/// bgDark passes WCAG AA.
class AppColors {
  AppColors._();

  // Light surfaces
  static const paper = Color(0xFFF4EDE0);
  static const paperShade = Color(0xFFEBE2D1);
  static const paperDeep = Color(0xFFE2D6BD);

  // Ink (light theme text)
  static const ink = Color(0xFF2B231C);
  static const inkSoft = Color(0xFF6F5F4F);
  static const inkFaint = Color(0xFFA89882);

  // Accents (shared)
  static const accent = Color(0xFFB85C3C);
  static const accentDeep = Color(0xFF8F4530);
  static const green = Color(0xFF6B7F5A);

  // Rules / strokes (light)
  static const rule = Color(0xFFD8CCB6);
  static const ctaInk = Color(0xFF1B1612);

  // Dark surfaces
  static const bgDark = Color(0xFF161412);
  static const surfaceDark = Color(0xFF1F1B19);

  // Dark ink
  static const inkOnDark = Color(0xFFECE3D2);
  static const inkSoftOnDark = Color(0xFFA89882);

  // Dark rules
  static const ruleDark = Color(0xFF2E2924);
}
