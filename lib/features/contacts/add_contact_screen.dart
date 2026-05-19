import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

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
  String? _permissionError;
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
    _controller.barcodes.listen((capture) {
      _onDetect(capture);
    });
    // Listen to controller state changes to detect permission-denied errors.
    // MobileScannerController.start() catches MobileScannerException internally
    // and stores it in value.error rather than re-throwing, so we observe via
    // the ValueNotifier listener instead of catchError.
    _controller.addListener(_onControllerStateChanged);
    _controller.start();
  }

  void _onControllerStateChanged() {
    final error = _controller.value.error;
    if (error != null && mounted) {
      setState(() => _permissionError = error.toString());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerStateChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
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
    if (_permissionError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add contact')),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Camera access is required to scan a contact QR.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _permissionError!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open app settings'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Add contact')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller),
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
