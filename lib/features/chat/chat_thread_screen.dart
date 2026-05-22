import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../data/models/contact.dart' as model;
import '../../util/display_name.dart';
import '../contacts/contacts_provider.dart';
import '../identity/identity_provider.dart';
import 'chat_thread_provider.dart';
import 'composer.dart';
import 'group_settings_screen.dart';
import 'message_bubble.dart';
import 'message_service_provider.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  bool _openInvoked = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(identityProvider).valueOrNull?.publicKeyHex ?? '';
    final messagesAsync = ref.watch(chatThreadProvider(widget.chatId));
    final messageSvcAsync = ref.watch(messageServiceProvider);
    final chatAsync = ref.watch(chatProvider(widget.chatId));
    final contactsAsync = ref.watch(contactsListProvider);

    final chat = chatAsync.valueOrNull;
    final isGroup = chat?.kind == 'group';
    final hasLeft = chat?.leftAt != null;
    final contactsByPk = contactsAsync.maybeWhen(
      data: (list) => {for (final c in list) c.pubkeyHex: c},
      orElse: () => <String, model.Contact>{},
    );

    // Once the MessageService resolves, kick off a one-shot openChat() for
    // direct chats so both sides exchange PreKey bundles before the user types.
    // For group chats, bundle exchange is handled per-recipient inside
    // createGroup / sendGroupText, so skip openChat.
    messageSvcAsync.whenData((svc) {
      if (!_openInvoked && !isGroup) {
        _openInvoked = true;
        svc.openChat(widget.chatId);
      }
    });

    // AppBar title: group name (tappable) or truncated pubkey (direct).
    Widget titleWidget;
    if (isGroup) {
      titleWidget = GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupSettingsScreen(chatId: widget.chatId),
          ),
        ),
        child: Text(chat!.groupName ?? '(unnamed group)'),
      );
    } else {
      titleWidget = Text(resolveName(widget.chatId, contactsByPk[widget.chatId]));
    }

    return Scaffold(
      appBar: AppBar(title: titleWidget),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (msgs) {
                if (msgs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No messages yet. Say hi.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final prev = i > 0 ? msgs[i - 1] : null;

                    // System messages: centered italic gray row, no bubble.
                    if (m.kind != 'text') {
                      return _systemRow(m.body);
                    }

                    final fromMe = m.senderPubkeyHex == me;
                    final label = isGroup
                        ? _showSenderLabel(m, prev, me, chat, contactsByPk)
                        : null;

                    return MessageBubble(
                      body: m.body,
                      fromMe: fromMe,
                      timestamp: m.sentAt,
                      senderLabel: label,
                    );
                  },
                );
              },
            ),
          ),
          _buildComposer(context, messageSvcAsync, chat, hasLeft, isGroup),
        ],
      ),
    );
  }

  /// Returns the sender label string for an incoming group bubble, or null
  /// if the label should be suppressed (same sender as previous visible bubble).
  /// Resolves the sender's name via the resolveName helper (Phase 10.4.1).
  String? _showSenderLabel(
    Message m,
    Message? prev,
    String me,
    Chat? chat,
    Map<String, model.Contact> contacts,
  ) {
    if (chat?.kind != 'group') return null;
    if (m.senderPubkeyHex == me) return null; // outgoing
    if (m.kind != 'text') return null; // system rows handled separately
    final label = resolveName(m.senderPubkeyHex, contacts[m.senderPubkeyHex]);
    if (prev == null) return label;
    // Suppress only if the previous visible incoming text bubble was same sender.
    if (prev.kind != 'text') return label;
    if (prev.senderPubkeyHex == me) return label;
    if (prev.senderPubkeyHex != m.senderPubkeyHex) return label;
    return null; // same sender consecutively — suppress repeat label
  }

  Widget _systemRow(String body) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
        child: Center(
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ),
      );

  Widget _buildComposer(
    BuildContext context,
    AsyncValue messageSvcAsync,
    Chat? chat,
    bool hasLeft,
    bool isGroup,
  ) {
    // While message service is loading, show a progress indicator.
    if (messageSvcAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      );
    }

    if (messageSvcAsync.hasError) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Chat unavailable: ${messageSvcAsync.error}',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    // If the user has left this group, show a locked banner instead of composer.
    if (hasLeft) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Center(
          child: Text(
            "You're no longer in this group",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final svc = messageSvcAsync.value!;
    return Composer(
      onSend: (text) => isGroup
          ? svc.sendGroupText(chatId: widget.chatId, body: text)
          : svc.sendText(peerPubkeyHex: widget.chatId, body: text),
    );
  }
}
