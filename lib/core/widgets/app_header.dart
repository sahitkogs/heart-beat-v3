import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/chat_providers.dart';
import '../../features/identity/identity_screen.dart';
import '../../theme/app_colors.dart';
import 'wordmark.dart';

/// Shared header used on Chats and Contacts. Renders:
///
///   [back?]  heart•beat                          (avatar)
///   ────────────────────────────────────────────
///
/// Tapping the avatar opens a bottom sheet with display name + My identity.
class AppHeader extends ConsumerWidget {
  const AppHeader({
    super.key,
    this.showBack = true,
    this.onBack,
  });

  /// Build a header for the root screen (no back arrow).
  const AppHeader.root({super.key})
      : showBack = false,
        onBack = null;

  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(profileDaoProvider).get(),
      builder: (context, snap) {
        final displayName = snap.data?.displayName ?? '?';
        return Column(
          children: [
            Row(
              children: [
                if (showBack)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Back',
                  ),
                if (showBack) const SizedBox(width: 12),
                const Wordmark(size: 22),
                const Spacer(),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _openMenu(context, displayName),
                  child: InitialAvatar(label: displayName, size: 36),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
          ],
        );
      },
    );
  }

  void _openMenu(BuildContext context, String displayName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.bgDark : AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.ruleDark : AppColors.rule,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(
                displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('My profile'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const IdentityScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
