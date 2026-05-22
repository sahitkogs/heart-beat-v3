import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/chat_providers.dart';
import '../../data/app_database.dart';
import '../../data/models/contact.dart' as model;
import '../../services/notifications_service.dart';
import '../../util/display_name.dart';
import '../contacts/contacts_provider.dart';
import '../contacts/contacts_screen.dart';
import '../identity/identity_screen.dart';
import '../notifications/fcm_provider.dart';
import 'chat_thread_screen.dart';
import 'select_contact_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  bool _searchVisible = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Lifecycle wiring moved here from the retired HomeScreen (T3.3):
    // trigger the POST_NOTIFICATIONS permission prompt after the first
    // frame so the OS dialog overlays a rendered UI, and kick off FCM
    // registration once identity exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationsService.instance.requestPermission();
      ref.read(fcmRegistrationProvider.future).catchError((Object e) {
        // ignore: avoid_print
        print('[ChatListScreen] fcm registration failed: $e');
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => setState(() {
              _searchVisible = !_searchVisible;
              if (!_searchVisible) _searchController.clear();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Contacts',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ContactsScreen(),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'My profile',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const IdentityScreen(),
            )),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New conversation',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const SelectContactScreen(),
        )),
        child: const Icon(Icons.edit),
      ),
      body: Column(
        children: [
          if (_searchVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search chats',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          Expanded(
            child: chatsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: _buildList,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Chat> chats) {
    if (chats.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No chats yet. Tap the pencil button to start one.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final query = _searchController.text.trim().toLowerCase();
    final contactsAsync = ref.watch(contactsListProvider);
    final contacts = contactsAsync.maybeWhen(
      data: (list) => {for (final c in list) c.pubkeyHex: c},
      orElse: () => <String, model.Contact>{},
    );
    final filtered = query.isEmpty
        ? chats
        : chats.where((chat) {
            final title = chat.kind == 'group'
                ? (chat.groupName ?? '')
                : resolveName(chat.chatId, contacts[chat.chatId]);
            return title.toLowerCase().contains(query);
          }).toList();
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No chats matching "$query"',
              textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, i) => const Divider(height: 1),
      itemBuilder: (_, i) => _ChatTile(chat: filtered[i], contacts: contacts),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  const _ChatTile({required this.chat, required this.contacts});
  final Chat chat;
  final Map<String, model.Contact> contacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (chat.kind == 'group') {
      return _buildGroupTile(context, ref);
    }
    return _buildDirectTile(context);
  }

  Widget _buildGroupTile(BuildContext context, WidgetRef ref) {
    final name = chat.groupName ?? '(unnamed group)';
    final initial = name.substring(0, 1).toUpperCase();
    final preview = chat.lastMessagePreview ?? 'No messages yet';
    final timestamp = chat.lastMessageAt != null
        ? _formatTimestamp(chat.lastMessageAt!)
        : '';
    final isLeft = chat.leftAt != null;

    return ListTile(
      leading: CircleAvatar(child: Text(initial)),
      title: Text(
        name,
        style: isLeft ? const TextStyle(color: Colors.grey) : null,
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isLeft ? const TextStyle(color: Colors.grey) : null,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(timestamp, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          if (isLeft)
            const Text(
              'Left',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            )
          else
            FutureBuilder<int>(
              future: ref
                  .read(groupMembersDaoProvider)
                  .activeMembers(chat.chatId)
                  .then((l) => l.length),
              builder: (_, snap) => Text(
                '${snap.data ?? 0}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(chatId: chat.chatId),
        ),
      ),
    );
  }

  Widget _buildDirectTile(BuildContext context) {
    final pk = chat.chatId;
    final contact = contacts[pk];
    final title = resolveName(pk, contact);
    final subtitle = chat.lastMessagePreview ?? 'No messages yet';
    final trailing = chat.lastMessageAt != null
        ? _formatTimestamp(chat.lastMessageAt!)
        : '';
    final initial = title.isNotEmpty ? title.substring(0, 1).toUpperCase() : '?';
    return ListTile(
      leading: CircleAvatar(child: Text(initial)),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(trailing, style: Theme.of(context).textTheme.bodySmall),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(chatId: chat.chatId),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) {
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
