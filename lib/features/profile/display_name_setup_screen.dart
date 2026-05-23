import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/chat_providers.dart';
import '../../core/widgets/wordmark.dart';

/// Blocking modal pushed by StartupRouter when profile.displayName is
/// missing. Spec §4.1 — user cannot dismiss or go back; must enter a
/// non-empty name to proceed to the Chats list.
class DisplayNameSetupScreen extends ConsumerStatefulWidget {
  const DisplayNameSetupScreen({super.key});

  @override
  ConsumerState<DisplayNameSetupScreen> createState() =>
      _DisplayNameSetupScreenState();
}

class _DisplayNameSetupScreenState
    extends ConsumerState<DisplayNameSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final dao = ref.read(profileDaoProvider);
    await dao.setDisplayName(_controller.text.trim());
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/chats');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Set your name'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Center(child: Wordmark(size: 48)),
                const SizedBox(height: 48),
                const Text(
                  'Pick a name people will see. You can change it later.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  maxLength: 40,
                  inputFormatters: [LengthLimitingTextInputFormatter(40)],
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
