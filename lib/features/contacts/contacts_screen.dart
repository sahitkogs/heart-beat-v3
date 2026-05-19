import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_contact_screen.dart';
import 'contacts_provider.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
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
              return ListTile(
                title: Text(
                  '${c.pubkeyHex.substring(0, 8)}…${c.pubkeyHex.substring(56)}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                subtitle: Text('added ${c.addedAt.toLocal()}'),
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
