import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_header.dart';
import '../../core/widgets/wordmark.dart';
import '../../util/display_name.dart';
import '../chat/chat_thread_screen.dart';
import 'add_contact_screen.dart';
import 'contact_actions.dart';
import 'contacts_provider.dart';

enum _ContactMenuAction { rename, delete }

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsListProvider);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const AppHeader(),
          ),
        ),
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (contacts) {
          if (contacts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No contacts yet. Tap + to scan someone\'s QR.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: contacts.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = contacts[i];
              final title = resolveName(c.pubkeyHex, c);
              return ListTile(
                leading: InitialAvatar(label: title),
                title: Text(title),
                subtitle: Text(
                  shortPubkey(c.pubkeyHex),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                trailing: PopupMenuButton<_ContactMenuAction>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Contact options',
                  onSelected: (action) async {
                    switch (action) {
                      case _ContactMenuAction.rename:
                        await openRenameContactDialog(context, ref, c);
                        break;
                      case _ContactMenuAction.delete:
                        await openDeleteContactDialog(context, ref, c);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _ContactMenuAction.rename,
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Rename'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _ContactMenuAction.delete,
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          'Delete contact',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ChatThreadScreen(chatId: c.pubkeyHex),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AddContactScreen(),
          ));
          // Refresh the list when returning.
          ref.invalidate(contactsListProvider);
        },
        child: const Icon(Icons.qr_code_scanner),
      ),
    );
  }
}
