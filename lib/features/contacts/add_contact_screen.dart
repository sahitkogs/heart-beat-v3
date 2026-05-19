import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/models/contact.dart';
import 'contacts_provider.dart';
import 'scan_handler.dart';

class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  bool _handled = false;
  String? _statusMessage;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return; // first detection wins
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstWhere((_) => true, orElse: () => '');
    if (raw.isEmpty) return;

    final result = ScanHandler.parse(raw);
    if (!result.isValid) {
      setState(() {
        _statusMessage = 'Invalid QR: ${result.error}';
      });
      return;
    }

    _handled = true;
    final repo = await ref.read(contactsRepositoryProvider.future);
    await repo.add(Contact(pubkeyHex: result.pubkeyHex!, addedAt: DateTime.now()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact added')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add contact')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          if (_statusMessage != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Material(
                color: Colors.red.shade100,
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
