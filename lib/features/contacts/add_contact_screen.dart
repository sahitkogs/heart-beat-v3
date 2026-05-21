import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/contact.dart';
import 'contacts_provider.dart';
import 'scan_handler.dart';

enum _Mode { camera, paste }

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

  _Mode _mode = _Mode.camera;
  final TextEditingController _pasteCtrl = TextEditingController();
  String? _pasteError;
  bool _saving = false;

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
      setState(() {
        _permissionError = error.toString();
        // Camera unavailable — drop into paste mode so the user can still pair.
        _mode = _Mode.paste;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerStateChanged);
    _controller.dispose();
    _pasteCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || _mode != _Mode.camera) return;
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
    await _saveAndPop(result.pubkeyHex!);
  }

  // Persist `pubkeyHex` and navigate back. Shared by the camera scan path
  // and the paste-pubkey path; the validation upstream is the same
  // (ScanHandler.parse) so both paths put the same 64-char lowercase hex in.
  //
  // Trust model note: a camera scan implies face-to-face confirmation that
  // the pubkey belongs to the person nearby. A pasted pubkey derives its
  // trust from the out-of-band channel used to share it (call, iMessage,
  // email). If that channel is compromised, a swap is undetectable until a
  // future fingerprint check. Acceptable for v3's two-party use; see
  // [[v3-paste-pubkey-pairing]] memory before raising the bar.
  Future<void> _saveAndPop(String pubkeyHex) async {
    final repo = ref.read(contactsRepositoryProvider);
    await repo.add(Contact(pubkeyHex: pubkeyHex, addedAt: DateTime.now()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact added')),
    );
    Navigator.of(context).pop();
  }

  void _switchMode(_Mode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _statusMessage = null;
      _pasteError = null;
    });
    if (mode == _Mode.camera && _permissionError == null) {
      _controller.start();
    } else {
      _controller.stop();
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) return;
    setState(() {
      _pasteCtrl.text = text.trim();
      _pasteCtrl.selection = TextSelection.collapsed(
        offset: _pasteCtrl.text.length,
      );
      _pasteError = null;
    });
  }

  Future<void> _savePastedKey() async {
    if (_saving) return;
    final result = ScanHandler.parse(_pasteCtrl.text);
    if (!result.isValid) {
      setState(() => _pasteError = result.error);
      return;
    }
    setState(() {
      _saving = true;
      _pasteError = null;
    });
    await _saveAndPop(result.pubkeyHex!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add contact'),
        actions: [
          IconButton(
            tooltip: _mode == _Mode.camera ? 'Paste pubkey' : 'Use camera',
            icon: Icon(
              _mode == _Mode.camera ? Icons.content_paste : Icons.qr_code_scanner,
            ),
            onPressed: () => _switchMode(
              _mode == _Mode.camera ? _Mode.paste : _Mode.camera,
            ),
          ),
        ],
      ),
      body: _mode == _Mode.paste ? _buildPasteBody() : _buildCameraBody(),
    );
  }

  Widget _buildCameraBody() {
    if (_permissionError != null) {
      // Defensive: _onControllerStateChanged should have already flipped us
      // into paste mode, but if the user manually toggled back, surface the
      // permission state with a route into paste mode.
      return Padding(
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
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _switchMode(_Mode.paste),
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste pubkey instead'),
            ),
          ],
        ),
      );
    }
    return Stack(
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
    );
  }

  Widget _buildPasteBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paste your contact’s pubkey',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'A 64-character hex string. Get it from your contact via call, '
            'message, or email — any channel you trust.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _pasteCtrl,
            maxLines: 3,
            minLines: 2,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Pubkey (hex)',
              hintText: '64 lowercase hex characters',
              border: const OutlineInputBorder(),
              errorText: _pasteError,
            ),
            onChanged: (_) {
              if (_pasteError != null) {
                setState(() => _pasteError = null);
              }
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving ? null : _pasteFromClipboard,
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste from clipboard'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _savePastedKey,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save contact'),
          ),
        ],
      ),
    );
  }
}
