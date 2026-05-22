import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/chat_providers.dart';
import '../../data/app_database.dart';
import '../../services/notifications_service.dart';
import '../notifications/fcm_provider.dart';
import 'chat_thread_screen.dart';
import 'new_group_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
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
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.group_add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewGroupScreen()),
        ),
      ),
      body: chatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (chats) {
          if (chats.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No chats yet. Open a contact to start one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, i) => const Divider(height: 1),
            itemBuilder: (_, i) => _ChatTile(chat: chats[i]),
          );
        },
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  const _ChatTile({required this.chat});
  final Chat chat;

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
        style: isLeft
            ? const TextStyle(color: Colors.grey)
            : null,
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
    final title = '${pk.substring(0, 8)}…${pk.substring(pk.length - 8)}';
    final subtitle = chat.lastMessagePreview ?? 'No messages yet';
    final trailing = chat.lastMessageAt != null
        ? _formatTimestamp(chat.lastMessageAt!)
        : '';
    return ListTile(
      title: Text(title, style: const TextStyle(fontFamily: 'monospace')),
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
