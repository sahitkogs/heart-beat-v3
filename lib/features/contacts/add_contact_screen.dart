import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models/contact.dart';
import '../../theme/app_colors.dart';
import '../../util/display_name.dart';
import '../identity/identity_provider.dart';
import 'contacts_provider.dart';
import 'scan_handler.dart';

/// Stage machine for the add-contact flow:
///   - chooseMethod: initial chooser (Scan QR vs Paste hex)
///   - scanQr: camera scanner view
///   - nameContact: post-scan name prompt (required nickname, pubkey read-only)
///   - pasteHex: paste form (required nickname + hex)
///   - shareBack: post-save reciprocal pairing hint (your QR + hex)
enum _Stage { chooseMethod, scanQr, nameContact, pasteHex, shareBack }

class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key, this.initialHex, this.initialName});

  /// When non-null, the screen opens directly on the paste-hex stage with
  /// these values pre-populated (used by deep-link routing).
  final String? initialHex;
  final String? initialName;

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  _Stage _stage = _Stage.chooseMethod;
  bool _handled = false;
  String? _statusMessage;
  String? _permissionError;
  MobileScannerController? _controller;

  final TextEditingController _pasteCtrl = TextEditingController();
  final TextEditingController _nicknameCtrl = TextEditingController();
  String? _pasteError;
  bool _saving = false;

  /// Pubkey captured from the camera scan, surfaced read-only on the
  /// nameContact stage so the user can name the contact before save.
  String? _scannedHex;

  /// Label of the just-added contact (resolveName output). Shown on the
  /// shareBack stage to personalize the prompt.
  String? _savedContactLabel;

  @override
  void initState() {
    super.initState();
    if (widget.initialHex != null && widget.initialHex!.isNotEmpty) {
      _pasteCtrl.text = widget.initialHex!;
      _nicknameCtrl.text = widget.initialName ?? '';
      _stage = _Stage.pasteHex;
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerStateChanged);
    _controller?.dispose();
    _pasteCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  void _gotoStage(_Stage s) {
    if (_stage == s) return;
    setState(() {
      _stage = s;
      _statusMessage = null;
      _pasteError = null;
    });
    if (s == _Stage.scanQr) {
      _startScanner();
    } else {
      _stopScanner();
    }
  }

  void _startScanner() {
    if (_controller != null) return;
    _controller = MobileScannerController();
    _controller!.barcodes.listen((capture) => _onDetect(capture));
    _controller!.addListener(_onControllerStateChanged);
    _controller!.start();
  }

  void _stopScanner() {
    final c = _controller;
    if (c == null) return;
    c.removeListener(_onControllerStateChanged);
    c.dispose();
    _controller = null;
    _handled = false;
  }

  void _onControllerStateChanged() {
    final error = _controller?.value.error;
    if (error != null && mounted && _stage == _Stage.scanQr) {
      setState(() {
        _permissionError = error.toString();
      });
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || _stage != _Stage.scanQr) return;
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
    _stopScanner();
    if (!mounted) return;
    setState(() {
      _scannedHex = result.pubkeyHex!;
      _nicknameCtrl.clear();
      _stage = _Stage.nameContact;
      _statusMessage = null;
    });
  }

  Future<void> _saveScannedKey() async {
    if (_saving) return;
    final hex = _scannedHex;
    final nick = _nicknameCtrl.text.trim();
    if (hex == null || nick.isEmpty) return;
    setState(() => _saving = true);
    await _saveAndAdvance(hex, nickname: nick);
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
    final nick = _nicknameCtrl.text.trim();
    if (nick.isEmpty) return;
    final result = ScanHandler.parse(_pasteCtrl.text);
    if (!result.isValid) {
      setState(() => _pasteError = result.error);
      return;
    }
    setState(() {
      _saving = true;
      _pasteError = null;
    });
    await _saveAndAdvance(result.pubkeyHex!, nickname: nick);
  }

  /// Persist the new contact and transition to the shareBack stage.
  ///
  /// Trust model note: a camera scan implies face-to-face confirmation that
  /// the pubkey belongs to the person nearby. A pasted pubkey derives its
  /// trust from the out-of-band channel used to share it (call, iMessage,
  /// email). If that channel is compromised, a swap is undetectable until a
  /// future fingerprint check. See [[v3-paste-pubkey-pairing]] memory.
  Future<void> _saveAndAdvance(
    String pubkeyHex, {
    required String? nickname,
  }) async {
    final repo = ref.read(contactsRepositoryProvider);
    final nick =
        nickname != null && nickname.isNotEmpty ? nickname : null;
    await repo.add(Contact(
      pubkeyHex: pubkeyHex,
      addedAt: DateTime.now(),
      displayName: nick,
    ));
    if (!mounted) return;
    // For the shareBack greeting we want to address the user by the label
    // we just persisted — falls back to truncated hex if they didn't type
    // a nickname.
    final label = resolveName(
        pubkeyHex,
        Contact(
          pubkeyHex: pubkeyHex,
          addedAt: DateTime.now(),
          displayName: nick,
        ));
    _stopScanner();
    setState(() {
      _savedContactLabel = label;
      _stage = _Stage.shareBack;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle()),
        leading: _stage == _Stage.chooseMethod || _stage == _Stage.shareBack
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _gotoStage(_Stage.chooseMethod),
              ),
      ),
      body: switch (_stage) {
        _Stage.chooseMethod => _buildChooser(),
        _Stage.scanQr => _buildCameraBody(),
        _Stage.nameContact => _buildNameContact(),
        _Stage.pasteHex => _buildPasteBody(),
        _Stage.shareBack => _buildShareBack(),
      },
    );
  }

  String _appBarTitle() {
    return switch (_stage) {
      _Stage.chooseMethod => 'Add contact',
      _Stage.scanQr => 'Scan QR code',
      _Stage.nameContact => 'Name this contact',
      _Stage.pasteHex => 'Paste hex code',
      _Stage.shareBack => 'Contact saved',
    };
  }

  Widget _buildChooser() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Text(
            'How do you want to add your contact?',
            style: TextStyle(fontSize: 16),
          ),
        ),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: const Icon(Icons.qr_code_scanner),
          ),
          title: const Text('Scan QR code'),
          subtitle: const Text(
              "Use the camera to scan the other person's QR code."),
          onTap: () => _gotoStage(_Stage.scanQr),
        ),
        const Divider(height: 1),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: const Icon(Icons.content_paste),
          ),
          title: const Text('Paste hex code'),
          subtitle: const Text(
              'A 64-character hex string shared via message, email, etc.'),
          onTap: () => _gotoStage(_Stage.pasteHex),
        ),
      ],
    );
  }

  Widget _buildCameraBody() {
    if (_permissionError != null) {
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
              onPressed: () => _gotoStage(_Stage.pasteHex),
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste hex instead'),
            ),
          ],
        ),
      );
    }
    final c = _controller;
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        MobileScanner(controller: c),
        if (_statusMessage != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
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
            controller: _nicknameCtrl,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Nickname',
              hintText: 'What to call this person',
              helperText: 'Required',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
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
            onPressed: (_saving || _nicknameCtrl.text.trim().isEmpty)
                ? null
                : _savePastedKey,
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

  Widget _buildNameContact() {
    final hex = _scannedHex ?? '';
    final canSave = !_saving && _nicknameCtrl.text.trim().isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Give this contact a name',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Used everywhere in the app. You can rename later from Contacts.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nicknameCtrl,
            maxLength: 40,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nickname',
              hintText: 'What to call this person',
              helperText: 'Required',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => canSave ? _saveScannedKey() : null,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scanned pubkey',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  hex,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canSave ? _saveScannedKey : null,
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

  Widget _buildShareBack() {
    final identityAsync = ref.watch(identityProvider);
    return identityAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (identity) {
        final myHex = identity.publicKeyHex;
        final contactLabel = _savedContactLabel ?? 'your contact';
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.check_circle,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Contact added',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Now share your own code with $contactLabel so they can add you back.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: myHex,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: AppColors.paper,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                myHex,
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
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: myHex));
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Hex copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy my hex'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }
}
