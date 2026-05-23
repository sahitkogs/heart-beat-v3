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
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: Wordmark(size: 48)),
                    const SizedBox(height: 32),
                    const Text(
                      'Pick a name people will see. You can change it later.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _controller,
                      autofocus: true,
                      maxLength: 40,
                      inputFormatters: [LengthLimitingTextInputFormatter(40)],
                      decoration: InputDecoration(
                        labelText: 'Display name',
                        border: const OutlineInputBorder(),
                        counterText: '',
                        suffixIcon: _saving
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.arrow_forward),
                                color:
                                    Theme.of(context).colorScheme.primary,
                                tooltip: 'Continue',
                                onPressed: _save,
                              ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a name'
                          : null,
                      onFieldSubmitted: (_) => _save(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
