import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// "heart•beat" wordmark with the accent dot. Use [size] to scale.
///
/// Defaults `color` to `Theme.of(context).colorScheme.onSurface` so it
/// adapts to dark mode automatically; pass a `color` to override.
class Wordmark extends StatelessWidget {
  const Wordmark({
    super.key,
    this.size = 28,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    final style = TextStyle(
      fontFamily: 'serif',
      fontWeight: FontWeight.w600,
      color: c,
      height: 1.0,
      fontSize: size,
      letterSpacing: -0.5,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('heart', style: style),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.12),
          child: Container(
            width: size * 0.22,
            height: size * 0.22,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Text('beat', style: style),
      ],
    );
  }
}

/// Italic serif "label" used as section headings ("your *chats*").
class AccentItalic extends StatelessWidget {
  const AccentItalic(
    this.text, {
    super.key,
    this.size = 28,
    this.color,
  });

  final String text;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'serif',
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        color: c,
        fontSize: size,
        height: 1.1,
      ),
    );
  }
}

/// Round avatar showing the first letter of a name (or '?' if empty).
/// Dark-mode aware: uses `paperShade` bg on light, `surfaceDark` on dark.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.label,
    this.size = 36,
  });

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceDark : AppColors.paperShade;
    final fg = isDark ? AppColors.inkOnDark : AppColors.ink;
    final border = isDark ? AppColors.ruleDark : AppColors.rule;
    final letter = label.trim().isEmpty
        ? '?'
        : label.trim().substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: 'serif',
          fontWeight: FontWeight.w600,
          color: fg,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}

/// Pill-shaped status chip ("LEFT", "ADMIN", etc.).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = StatusPillTone.accent,
  });

  final String label;
  final StatusPillTone tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = switch (tone) {
      StatusPillTone.accent => (
          bg: AppColors.accent.withValues(alpha: 0.18),
          fg: isDark ? AppColors.accent : AppColors.accentDeep,
          border: AppColors.accent.withValues(alpha: 0.45),
        ),
      StatusPillTone.muted => (
          bg: isDark ? AppColors.surfaceDark : AppColors.paperShade,
          fg: isDark ? AppColors.inkSoftOnDark : AppColors.inkSoft,
          border: isDark ? AppColors.ruleDark : AppColors.rule,
        ),
      StatusPillTone.green => (
          bg: AppColors.green.withValues(alpha: 0.16),
          fg: AppColors.green,
          border: AppColors.green.withValues(alpha: 0.45),
        ),
      StatusPillTone.danger => (
          bg: Theme.of(context).colorScheme.error.withValues(alpha: 0.14),
          fg: Theme.of(context).colorScheme.error,
          border: Theme.of(context).colorScheme.error.withValues(alpha: 0.45),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'sans-serif',
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.6,
          color: palette.fg,
        ),
      ),
    );
  }
}

enum StatusPillTone { accent, muted, green, danger }
