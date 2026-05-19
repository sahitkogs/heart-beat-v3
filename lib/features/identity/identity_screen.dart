import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'identity_provider.dart';

class IdentityScreen extends ConsumerWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(identityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My identity')),
      body: identityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (identity) => _IdentityBody(pubkeyHex: identity.publicKeyHex),
      ),
    );
  }
}

class _IdentityBody extends StatelessWidget {
  const _IdentityBody({required this.pubkeyHex});
  final String pubkeyHex;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Show this to someone you want to chat with. They scan it from their Add Contact screen.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Center(
              child: QrImageView(
                data: pubkeyHex,
                version: QrVersions.auto,
                size: 260,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            SelectableText(
              pubkeyHex,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: pubkeyHex));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy hex'),
            ),
          ],
        ),
      ),
    );
  }
}
