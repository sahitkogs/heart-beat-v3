import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import 'presence_provider.dart';
import 'presence_status.dart';

/// Small reachability dot next to a contact's name. Green = online,
/// amber = seen within 24h, hollow grey = stale, empty = unknown.
/// Reachability only — NOT identity verification.
class PresenceBadge extends ConsumerWidget {
  const PresenceBadge({super.key, required this.pubkeyHex, this.size = 10});

  final String pubkeyHex;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(presenceProvider)[pubkeyHex];
    final status = presenceStatusFor(info, DateTime.now());
    final onSurface = Theme.of(context).colorScheme.onSurface;
    switch (status) {
      case PresenceStatus.online:
        return _dot(AppColors.green, filled: true);
      case PresenceStatus.recent:
        return _dot(const Color(0xFFC8862B), filled: true);
      case PresenceStatus.stale:
        return _dot(onSurface.withValues(alpha: 0.35), filled: false);
      case PresenceStatus.unknown:
        return SizedBox(width: size, height: size);
    }
  }

  Widget _dot(Color color, {required bool filled}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : Colors.transparent,
          border: filled ? null : Border.all(color: color, width: 1.5),
        ),
      );
}
