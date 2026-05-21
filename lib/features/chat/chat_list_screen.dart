import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/chat_providers.dart';
import '../../data/app_database.dart';
import 'chat_thread_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
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

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat});
  final Chat chat;

  @override
  Widget build(BuildContext context) {
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
          builder: (_) => ChatThreadScreen(peerPubkeyHex: chat.chatId),
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
