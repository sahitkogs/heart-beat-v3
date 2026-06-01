import 'package:flutter/material.dart';

class Composer extends StatefulWidget {
  const Composer({super.key, required this.onSend, this.initialText});

  final Future<void> Function(String text) onSend;

  /// Optional text to pre-seed the composer with on first build (e.g. text
  /// forwarded INTO heart•beat via share). Seeded once in initState so it
  /// doesn't clobber what the user types on later rebuilds.
  final String? initialText;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialText;
    if (seed != null && seed.isNotEmpty) {
      _controller.text = seed;
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: Theme.of(context).colorScheme.primary,
              onPressed: _sending ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
