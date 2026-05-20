import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/identity_provider.dart';
import 'chat_thread_provider.dart';
import 'composer.dart';
import 'message_bubble.dart';
import 'message_service_provider.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.peerPubkeyHex});

  final String peerPubkeyHex;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  bool _openInvoked = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(identityProvider).valueOrNull?.publicKeyHex ?? '';
    final messagesAsync = ref.watch(chatThreadProvider(widget.peerPubkeyHex));
    final messageSvcAsync = ref.watch(messageServiceProvider);

    // Once the MessageService resolves, kick off a one-shot openChat() so
    // both sides exchange PreKey bundles even before the user types.
    messageSvcAsync.whenData((svc) {
      if (!_openInvoked) {
        _openInvoked = true;
        svc.openChat(widget.peerPubkeyHex);
      }
    });

    final pk = widget.peerPubkeyHex;
    final title = pk.length >= 16
        ? '${pk.substring(0, 8)}…${pk.substring(pk.length - 8)}'
        : pk;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        ),
      ),
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
                    return MessageBubble(
                      body: m.body,
                      fromMe: m.senderPubkeyHex == me,
                      timestamp: m.sentAt,
                    );
                  },
                );
              },
            ),
          ),
          messageSvcAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Chat unavailable: $e',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            data: (svc) => Composer(
              onSend: (text) => svc.sendText(
                peerPubkeyHex: widget.peerPubkeyHex,
                body: text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
