import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/wordmark.dart';
import '../../util/display_name.dart';
import '../contacts/add_contact_screen.dart';
import '../contacts/contacts_provider.dart';
import '../presence/presence_badge.dart';
import 'chat_thread_screen.dart';
import 'new_group_screen.dart';

/// Full-screen route opened by the Chats FAB. WhatsApp-pattern composer:
/// "New group" + "New contact" action rows at the top, followed by the
/// existing contact list. Tap a contact to start a direct chat.
class SelectContactScreen extends ConsumerWidget {
  const SelectContactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: contactsAsync.maybeWhen(
          data: (contacts) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select contact'),
              Text(
                '${contacts.length} contact${contacts.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          orElse: () => const Text('Select contact'),
        ),
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (contacts) {
          final sorted = [...contacts]..sort((a, b) =>
              resolveName(a.pubkeyHex, a).toLowerCase().compareTo(
                  resolveName(b.pubkeyHex, b).toLowerCase()));
          return ListView(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: const Icon(Icons.group_add),
                ),
                title: const Text('New group'),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NewGroupScreen(),
                  ));
                  // After returning from group creation, close the
                  // composer so the user lands back on the Chats list.
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: const Icon(Icons.person_add),
                ),
                title: const Text('New contact'),
                trailing: const Icon(Icons.qr_code_scanner),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AddContactScreen(),
                  ));
                  ref.invalidate(contactsListProvider);
                },
              ),
              const Divider(height: 1),
              if (sorted.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'CONTACTS ON HEARTBEAT',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.05,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ...sorted.map((c) {
                final name = resolveName(c.pubkeyHex, c);
                return ListTile(
                  leading: InitialAvatar(label: name),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(name)),
                      const SizedBox(width: 6),
                      PresenceBadge(pubkeyHex: c.pubkeyHex),
                    ],
                  ),
                  subtitle: Text(
                    shortPubkey(c.pubkeyHex),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => ChatThreadScreen(chatId: c.pubkeyHex),
                    ));
                  },
                );
              }),
              if (sorted.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No contacts yet. Tap "New contact" to add one.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
