import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/chat_providers.dart';
import '../../data/app_database.dart';
import '../../data/models/contact.dart' as model;
import '../../util/display_name.dart';
import '../chat/message_service_provider.dart';
import '../identity/identity_provider.dart';
import 'contacts_provider.dart';

/// Open the rename dialog for [contact]. Returns true if the user saved a
/// new non-empty display name.
///
/// On Save, writes via ContactsRepository.updateDisplayName and invalidates
/// `contactsListProvider` so every consumer (Contacts list, chat list, chat
/// thread header, group rows) re-resolves.
Future<bool> openRenameContactDialog(
  BuildContext context,
  WidgetRef ref,
  model.Contact contact,
) async {
  final controller = TextEditingController(
    text: contact.displayName ?? contact.claimedName ?? '',
  );
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final canSave = controller.text.trim().isNotEmpty;
        return AlertDialog(
          title: const Text('Rename contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) =>
                    canSave ? Navigator.of(ctx).pop(true) : null,
              ),
              const SizedBox(height: 4),
              Text(
                shortPubkey(contact.pubkeyHex),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: canSave ? () => Navigator.of(ctx).pop(true) : null,
              child: const Text('Save'),
            ),
          ],
        );
      });
    },
  );

  if (saved != true) return false;
  final newName = controller.text.trim();
  if (newName.isEmpty) return false;
  await ref
      .read(contactsRepositoryProvider)
      .updateDisplayName(contact.pubkeyHex, newName);
  ref.invalidate(contactsListProvider);
  return true;
}

/// Open the delete dialog for [contact] with the soft/hard radio choice.
/// Returns:
///   - null  → user cancelled
///   - false → soft delete (Contacts row only)
///   - true  → hard delete (Contacts row + direct chat + history +
///             cascade-remove from groups the local user admins)
///
/// Crypto sessions and membership in non-admin groups are intentionally
/// left untouched in both branches.
Future<bool?> openDeleteContactDialog(
  BuildContext context,
  WidgetRef ref,
  model.Contact contact,
) async {
  // Capture the messenger before any await so we don't have to revalidate
  // BuildContext after the dialog/teardown completes.
  final messenger = ScaffoldMessenger.of(context);
  final me = ref.read(identityProvider).valueOrNull?.publicKeyHex;
  final chatsDao = ref.read(chatsDaoProvider);
  final groupMembersDao = ref.read(groupMembersDaoProvider);

  // Find groups I admin where the target is an active member.
  final allChats = await chatsDao.watchChats().first;
  final affectedGroups = <Chat>[];
  if (me != null && me.isNotEmpty) {
    for (final g in allChats) {
      if (g.kind != 'group' || g.creatorPubkeyHex != me) continue;
      if (await groupMembersDao.isActiveMember(g.chatId, contact.pubkeyHex)) {
        affectedGroups.add(g);
      }
    }
  }

  if (!context.mounted) return null;
  final label = resolveName(contact.pubkeyHex, contact);
  bool hard = true;

  final confirmed = await showDialog<bool?>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text('Delete $label?'),
        content: SingleChildScrollView(
          child: RadioGroup<bool>(
            groupValue: hard,
            onChanged: (v) => setState(() => hard = v ?? true),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RadioListTile<bool>(
                  value: false,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Remove from Contacts only'),
                  subtitle: Text(
                    'Keeps the direct chat and message history. The chat '
                    'tile reverts to the raw hex until you re-add.',
                  ),
                ),
                RadioListTile<bool>(
                  value: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Delete contact, chat, and history'),
                  subtitle: Text(
                    affectedGroups.isEmpty
                        ? 'Deletes the direct chat and all messages. '
                            'Groups they share with you are not affected.'
                        : 'Deletes the direct chat and all messages, and '
                            'removes them from ${affectedGroups.length} '
                            'group(s) you admin: '
                            '${affectedGroups.map((g) => g.groupName ?? '(unnamed)').join(', ')}.',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(hard),
            child: const Text('Delete'),
          ),
        ],
      );
    }),
  );

  if (confirmed == null) return null;

  if (confirmed) {
    try {
      if (affectedGroups.isNotEmpty) {
        final svc = await ref.read(messageServiceProvider.future);
        for (final g in affectedGroups) {
          try {
            await svc.removeMemberFromGroup(
              chatId: g.chatId,
              targetPubkeyHex: contact.pubkeyHex,
            );
          } catch (e) {
            messenger.showSnackBar(SnackBar(
              content: Text(
                'Group "${g.groupName ?? g.chatId}" removal failed: $e',
              ),
            ));
          }
        }
      }
      await chatsDao.deleteDirectChat(contact.pubkeyHex);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Chat teardown failed: $e')),
      );
    }
  }

  try {
    final svc = await ref.read(messageServiceProvider.future);
    await svc.forgetPeer(contact.pubkeyHex);
  } catch (e) {
    // Best-effort: even if crypto cleanup fails (DB closed, peer never had a
    // session yet, etc.) we still drop the contact row so the UI reflects
    // the user's intent. A future re-pair will overwrite any stale state.
    debugPrint('forgetPeer failed for ${contact.pubkeyHex}: $e');
  }
  await ref.read(contactsRepositoryProvider).deleteContact(contact.pubkeyHex);
  ref.invalidate(contactsListProvider);
  messenger.showSnackBar(SnackBar(
    content: Text(
      confirmed ? 'Deleted $label and chat' : 'Removed $label from contacts',
    ),
  ));
  return confirmed;
}
