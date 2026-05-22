import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/contact.dart' as model;
import '../../util/display_name.dart';
import '../contacts/contacts_provider.dart';
import 'chat_thread_screen.dart';
import 'message_service_provider.dart';

class NewGroupScreen extends ConsumerStatefulWidget {
  const NewGroupScreen({super.key});

  @override
  ConsumerState<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends ConsumerState<NewGroupScreen> {
  final _nameCtrl = TextEditingController();
  final Set<String> _selected = {};
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      _nameCtrl.text.trim().isNotEmpty &&
      _selected.isNotEmpty &&
      _selected.length <= 7 &&
      !_creating;

  Future<void> _onCreate() async {
    setState(() => _creating = true);
    try {
      final ms = await ref.read(messageServiceProvider.future);
      final chatId = await ms.createGroup(
        name: _nameCtrl.text.trim(),
        memberPubkeysHex: _selected.toList(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatThreadScreen(chatId: chatId),
          ),
        );
      }
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message.toString())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _nameCtrl,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'Enter a name for this group',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
          ),
          Expanded(
            child: contactsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading contacts: $e')),
              data: (contacts) {
                if (contacts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No contacts yet. Add contacts first.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, i) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final model.Contact c = contacts[i];
                    final label = resolveName(c.pubkeyHex, c);
                    final checked = _selected.contains(c.pubkeyHex);
                    return CheckboxListTile(
                      value: checked,
                      title: Text(label),
                      subtitle: Text(
                        shortPubkey(c.pubkeyHex),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selected.add(c.pubkeyHex);
                          } else {
                            _selected.remove(c.pubkeyHex);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canCreate ? _onCreate : null,
                  child: _creating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
