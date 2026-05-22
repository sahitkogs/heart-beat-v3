import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../data/models/contact.dart' as model;
import '../../util/display_name.dart';
import '../contacts/contacts_provider.dart';
import '../identity/identity_provider.dart';
import 'chat_thread_provider.dart';
import 'message_service_provider.dart';

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GroupSettingsScreen
// ---------------------------------------------------------------------------

class GroupSettingsScreen extends ConsumerWidget {
  const GroupSettingsScreen({super.key, required this.chatId});
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(identityProvider).valueOrNull?.publicKeyHex ?? '';
    final chatAsync = ref.watch(chatProvider(chatId));

    // While chat metadata is loading or missing, show a spinner.
    final chat = chatAsync.valueOrNull;
    if (chat == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isCreator = chat.creatorPubkeyHex == me;
    final hasLeft = chat.leftAt != null;
    final membersAsync = ref.watch(groupActiveMembersProvider(chatId));

    return Scaffold(
      appBar: AppBar(title: const Text('Group settings')),
      body: Column(
        children: [
          // Header
          _GroupHeader(chat: chat, me: me, memberCount: membersAsync.valueOrNull?.length),

          const Divider(height: 1),

          // Member list (+ optional "Add member" row at top)
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading members: $e')),
              data: (members) => _MemberList(
                chatId: chatId,
                chat: chat,
                members: members,
                me: me,
                isCreator: isCreator,
                hasLeft: hasLeft,
              ),
            ),
          ),

          // "Leave group" button — only for non-creator active members.
          if (!isCreator && !hasLeft)
            _LeaveGroupButton(chatId: chatId),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header widget
// ---------------------------------------------------------------------------

class _GroupHeader extends ConsumerWidget {
  const _GroupHeader({
    required this.chat,
    required this.me,
    required this.memberCount,
  });

  final Chat chat;
  final String me;
  final int? memberCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupName = chat.groupName ?? '(unnamed group)';
    final initial = groupName.isNotEmpty ? groupName[0].toUpperCase() : '?';

    final creator = chat.creatorPubkeyHex ?? '';
    final contactsAsync = ref.watch(contactsListProvider);
    final creatorContact = contactsAsync.maybeWhen(
      data: (list) => list.where((c) => c.pubkeyHex == creator).firstOrNull,
      orElse: () => null,
    );
    final creatorLabel =
        creator == me ? 'you' : resolveName(creator, creatorContact);
    final countLabel =
        memberCount != null ? '$memberCount members' : '— members';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            child: Text(initial, style: const TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: 12),
          Text(
            groupName,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(countLabel, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            'Created by $creatorLabel',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Member list
// ---------------------------------------------------------------------------

class _MemberList extends ConsumerWidget {
  const _MemberList({
    required this.chatId,
    required this.chat,
    required this.members,
    required this.me,
    required this.isCreator,
    required this.hasLeft,
  });

  final String chatId;
  final Chat chat;
  final List<GroupMember> members;
  final String me;
  final bool isCreator;
  final bool hasLeft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsListProvider);
    final contactsByPk = contactsAsync.maybeWhen(
      data: (list) => {for (final c in list) c.pubkeyHex: c},
      orElse: () => <String, model.Contact>{},
    );
    return ListView.separated(
      itemCount: members.length + (isCreator ? 1 : 0),
      separatorBuilder: (_, sep) => const Divider(height: 1),
      itemBuilder: (context, index) {
        // The first row (index 0) for the creator is the "+ Add member" row.
        if (isCreator && index == 0) {
          return ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('+ Add member'),
            onTap: () => _pushAddMemberPicker(context, ref),
          );
        }

        final member = members[isCreator ? index - 1 : index];
        final memberIsCreator = member.memberPubkeyHex == chat.creatorPubkeyHex;
        final memberIsMe = member.memberPubkeyHex == me;
        final memberLabel = resolveName(
            member.memberPubkeyHex, contactsByPk[member.memberPubkeyHex]);

        return ListTile(
          title: Row(
            children: [
              Text(memberLabel),
              if (memberIsCreator) const _Badge(label: 'admin'),
              if (memberIsMe) const _Badge(label: 'you'),
            ],
          ),
          trailing: isCreator && !memberIsCreator
              ? PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'remove') {
                      _confirmRemove(context, ref, member);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove from group'),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  void _pushAddMemberPicker(BuildContext context, WidgetRef ref) {
    final currentMemberKeys =
        members.map((m) => m.memberPubkeyHex).toSet();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AddMemberPicker(
          chatId: chatId,
          excludedPubkeys: {
            ...currentMemberKeys,
            if (chat.creatorPubkeyHex != null) chat.creatorPubkeyHex!,
          },
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
  ) async {
    final contacts = await ref.read(contactsRepositoryProvider).loadAll();
    final memberContact = contacts
        .where((c) => c.pubkeyHex == member.memberPubkeyHex)
        .firstOrNull;
    final memberLabel = resolveName(member.memberPubkeyHex, memberContact);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove from group?'),
        content: Text(
          'Remove $memberLabel from this group? They will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      final svc = await ref.read(messageServiceProvider.future);
      await svc.removeMemberFromGroup(
        chatId: chatId,
        targetPubkeyHex: member.memberPubkeyHex,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: $e')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Leave group button
// ---------------------------------------------------------------------------

class _LeaveGroupButton extends ConsumerWidget {
  const _LeaveGroupButton({required this.chatId});
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => _confirmLeave(context, ref),
            child: const Text('Leave group'),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text(
          'You will no longer receive messages from this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      final svc = await ref.read(messageServiceProvider.future);
      await svc.leaveGroup(chatId: chatId);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave group: $e')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Add-member picker
// ---------------------------------------------------------------------------

class _AddMemberPicker extends ConsumerStatefulWidget {
  const _AddMemberPicker({
    required this.chatId,
    required this.excludedPubkeys,
  });

  final String chatId;
  final Set<String> excludedPubkeys;

  @override
  ConsumerState<_AddMemberPicker> createState() => _AddMemberPickerState();
}

class _AddMemberPickerState extends ConsumerState<_AddMemberPicker> {
  bool _adding = false;

  Future<void> _addMember(model.Contact contact) async {
    setState(() => _adding = true);
    try {
      final svc = await ref.read(messageServiceProvider.future);
      await svc.addMemberToGroup(
        chatId: widget.chatId,
        newMemberPubkeyHex: contact.pubkeyHex,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add member: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add member')),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading contacts: $e')),
        data: (contacts) {
          final eligible = contacts
              .where((c) => !widget.excludedPubkeys.contains(c.pubkeyHex))
              .toList();

          if (eligible.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No eligible contacts to add. All contacts are already members.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: eligible.length,
            separatorBuilder: (_, sep) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final contact = eligible[i];
              final label = resolveName(contact.pubkeyHex, contact);
              return ListTile(
                title: Text(label),
                subtitle: Text(
                  shortPubkey(contact.pubkeyHex),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                trailing: _adding
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _adding ? null : () => _addMember(contact),
              );
            },
          );
        },
      ),
    );
  }
}
