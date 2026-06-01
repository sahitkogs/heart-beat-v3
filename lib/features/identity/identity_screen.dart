import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../chat/chat_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_mode_provider.dart';
import '../contacts/contact_link.dart';
import '../diagnostics/diagnostics_screen.dart';
import 'identity_provider.dart';

class IdentityScreen extends ConsumerWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(identityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: identityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (identity) => _IdentityBody(pubkeyHex: identity.publicKeyHex),
      ),
    );
  }
}

class _IdentityBody extends ConsumerStatefulWidget {
  const _IdentityBody({required this.pubkeyHex});
  final String pubkeyHex;

  @override
  ConsumerState<_IdentityBody> createState() => _IdentityBodyState();
}

class _IdentityBodyState extends ConsumerState<_IdentityBody> {
  final _controller = TextEditingController();
  String? _initial;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final row = await ref.read(profileDaoProvider).get();
      if (!mounted) return;
      setState(() {
        _initial = row?.displayName ?? '';
        _controller.text = _initial!;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _controller.text.trim();
    if (v.isEmpty) return;
    await ref.read(profileDaoProvider).setDisplayName(v);
    if (!mounted) return;
    setState(() => _initial = v);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _controller.text.trim();
    final dirty = _initial != null && current != _initial && current.isNotEmpty;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            FilledButton(
              onPressed: dirty ? _save : null,
              child: const Text('Save'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const _ThemeToggle(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Diagnostics'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DiagnosticsScreen(),
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Show this to someone you want to chat with. They scan it from their Add Contact screen.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Center(
              child: QrImageView(
                data: widget.pubkeyHex,
                version: QrVersions.auto,
                size: 260,
                backgroundColor: AppColors.paper,
              ),
            ),
            const SizedBox(height: 24),
            SelectableText(
              widget.pubkeyHex,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.pubkeyHex));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy hex'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final uri = ContactLink(widget.pubkeyHex, _initial).toUri();
                await Share.share(
                  'Add me on heart•beat: $uri',
                  subject: 'My heart•beat contact',
                );
              },
              icon: const Icon(Icons.ios_share),
              label: const Text('Share contact'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Dark mode'),
      subtitle: Text(isDark ? 'Currently dark' : 'Currently light'),
      secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
      value: isDark,
      onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}
