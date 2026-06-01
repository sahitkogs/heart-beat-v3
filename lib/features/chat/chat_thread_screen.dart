import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/group_envelope.dart';
import '../../core/widgets/wordmark.dart';
import '../../data/app_database.dart';
import '../../data/models/contact.dart' as model;
import '../../util/display_name.dart';
import '../contacts/contact_actions.dart';
import '../contacts/contacts_provider.dart';
import '../identity/identity_provider.dart';
import '../presence/presence_badge.dart';
import '../presence/presence_provider.dart';
import '../presence/presence_status.dart';
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

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen>
    with WidgetsBindingObserver {
  bool _openInvoked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fire a one-shot read sweep on the first frame so direct chats opened
    // from a notification or tile mark inbound text read immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markReadIfFocused());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _markReadIfFocused();
  }

  /// Marks unread inbound messages from the peer locally read AND enqueues a
  /// `read` receipt back to them. Direct chats only — group bubbles skip
  /// receipts in this phase (spec §7l).
  Future<void> _markReadIfFocused() async {
    final svc = await ref.read(messageServiceProvider.future);
    // Hit Drift directly — chatProvider is a StreamProvider so its
    // valueOrNull is null on the first post-frame callback, which made
    // the original chat-kind guard short-circuit before any read receipt
    // could fire. getChat awaits the row read.
    final chat = await svc.dao.getChat(widget.chatId);
    if (chat == null || chat.kind != 'direct') return;
    final unread = await svc.dao.unreadInboundMsgIds(widget.chatId);
    if (unread.isEmpty) return;
    await svc.dao.markRead(unread);
    svc.receiptDebouncer.enqueueRead(
      peer: widget.chatId,
      msgIds: unread,
    );
  }

  /// Re-enqueues a failed outbound message into the outbox so the
  /// retransmitter picks it up on its next sweep (within ~10s). Resets the
  /// tick to `sent` so the user gets immediate feedback that the retry
  /// kicked off.
  Future<void> _retrySend(String msgId) async {
    final svc = await ref.read(messageServiceProvider.future);
    final msg = await svc.dao.findMessageById(msgId);
    if (msg == null) return;
    final myName = await svc.currentDisplayName();
    final jsonBytes = InnerEnvelope.buildText(
      chatId: svc.myPubkeyHex,
      lamport: msg.lamport,
      body: msg.body,
      senderDisplayName: myName,
      msgId: msgId,
    );
    final now = DateTime.now();
    await svc.outboxDao.insert(
      msgId: msgId,
      peerPubkeyHex: widget.chatId,
      envelopeBytes: jsonBytes,
      createdAt: now,
      nextRetryAt: now,
    );
    // failed is intentionally not monotonic — reset back to sent so the
    // user gets immediate UI feedback that the retry kicked off.
    await svc.dao.updateDeliveryState(msgId, DeliveryState.sent);
  }

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

    // AppBar title:
    //   - group: tap → GroupSettingsScreen (unchanged)
    //   - direct: tap → bottom sheet with rename/delete actions (T13.UX.8)
    Widget titleWidget;
    final String avatarLabel;
    if (isGroup) {
      avatarLabel = chat?.groupName ?? '?';
      titleWidget = GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupSettingsScreen(chatId: widget.chatId),
          ),
        ),
        child: Text(chat!.groupName ?? '(unnamed group)'),
      );
    } else {
      final peerContact = contactsByPk[widget.chatId];
      final peerName = resolveName(widget.chatId, peerContact);
      avatarLabel = peerName;
      // Direct-chat header: name + presence badge on the top line, with a
      // dimmed "last seen" subtitle underneath (B5).
      final lastSeen =
          lastSeenLabel(ref.watch(presenceProvider)[widget.chatId], DateTime.now());
      titleWidget = InkWell(
        onTap: () => _openDirectContactSheet(context, peerName, peerContact),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(peerName, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                PresenceBadge(pubkeyHex: widget.chatId),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 20),
              ],
            ),
            if (lastSeen.isNotEmpty)
              Text(
                lastSeen,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        // 10.4.3d UI — explicit back button (was missing on this screen
        // and users had to rely on the system gesture). Avatar moves into
        // the title row alongside the name.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
        leadingWidth: 48,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InitialAvatar(label: avatarLabel, size: 32),
            const SizedBox(width: 12),
            Flexible(child: titleWidget),
          ],
        ),
        titleSpacing: 0,
        centerTitle: false,
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
                    final prev = i > 0 ? msgs[i - 1] : null;

                    // 10.4.3d UI — date divider when the calendar day flips
                    // between the previous message and this one (or on
                    // the very first row). Format mirrors WhatsApp:
                    // Today / Yesterday / weekday for this week / full
                    // date for older.
                    final dateDivider =
                        _showDateDivider(m, prev) ? _dateRow(m.sentAt) : null;

                    Widget body;
                    // System messages: centered italic gray row, no bubble.
                    if (m.kind != 'text') {
                      body = _systemRow(m.body);
                    } else {
                      final fromMe = m.senderPubkeyHex == me;
                      final label = isGroup
                          ? _showSenderLabel(m, prev, me, chat, contactsByPk)
                          : null;

                      // Inbound bubbles don't render a tick — render plain.
                      if (!fromMe) {
                        body = MessageBubble(
                          body: m.body,
                          fromMe: false,
                          timestamp: m.sentAt,
                          senderLabel: label,
                        );
                      } else if (!m.knownTicks) {
                        // Outbound but pre-1.0.5 row — no provable delivery
                        // state ever existed, so hide the tick entirely
                        // instead of showing a misleading default `sent`.
                        body = MessageBubble(
                          body: m.body,
                          fromMe: true,
                          timestamp: m.sentAt,
                          senderLabel: label,
                        );
                      } else {
                        // Outbound + known ticks: subscribe to delivery
                        // state so the tick re-renders when a receipt
                        // advances it.
                        final svc = messageSvcAsync.valueOrNull;
                        if (svc == null) {
                          body = MessageBubble(
                            body: m.body,
                            fromMe: true,
                            timestamp: m.sentAt,
                            senderLabel: label,
                            deliveryState: m.deliveryState,
                          );
                        } else {
                          body = StreamBuilder<DeliveryState>(
                            stream: svc.dao.watchDeliveryState(m.id),
                            initialData: m.deliveryState,
                            builder: (context, snap) {
                              final state = snap.data ?? DeliveryState.sent;
                              return MessageBubble(
                                body: m.body,
                                fromMe: true,
                                timestamp: m.sentAt,
                                senderLabel: label,
                                deliveryState: state,
                                onRetryTap: state == DeliveryState.failed
                                    ? () => _retrySend(m.id)
                                    : null,
                              );
                            },
                          );
                        }
                      }
                    }

                    if (dateDivider == null) return body;
                    return Column(
                      children: [dateDivider, body],
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

  /// Bottom sheet for the direct-chat header. Shows the peer name + full
  /// pubkey hex, and offers Rename / Delete via the shared contact_actions
  /// helpers. Skips Rename/Delete entirely if there's no Contacts row (e.g.,
  /// after a prior soft-delete the chat may linger without a contact).
  ///
  /// On hard delete the chat is gone, so we pop the screen.
  Future<void> _openDirectContactSheet(
    BuildContext context,
    String peerName,
    model.Contact? peerContact,
  ) async {
    final navigator = Navigator.of(context);
    final pubkeyHex = widget.chatId;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peerName,
                      style: Theme.of(sheetCtx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      pubkeyHex,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Theme.of(sheetCtx).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (peerContact != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: const Text('Share contact'),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    await shareContact(context, peerContact);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Rename'),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    await openRenameContactDialog(
                      context,
                      ref,
                      peerContact,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(sheetCtx).colorScheme.error,
                  ),
                  title: Text(
                    'Delete contact',
                    style: TextStyle(
                      color: Theme.of(sheetCtx).colorScheme.error,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    final result = await openDeleteContactDialog(
                      context,
                      ref,
                      peerContact,
                    );
                    // Hard delete removed the chat — leave the thread.
                    if (result == true && navigator.canPop()) {
                      navigator.pop();
                    }
                  },
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Text(
                    'Not in your contacts — re-add them to rename or delete.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        );
      },
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

  Widget _systemRow(String body) => Builder(
        builder: (ctx) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
          child: Center(
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ),
        ),
      );

  // 10.4.3d UI — date dividers. Show a divider before message [m] when
  // the calendar day differs from [prev] (or [prev] is null — first row).
  // Group system-message kinds count the same as text for grouping purposes.
  bool _showDateDivider(Message m, Message? prev) {
    if (prev == null) return true;
    final a = m.sentAt.toLocal();
    final b = prev.sentAt.toLocal();
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  Widget _dateRow(DateTime at) => Builder(
        builder: (ctx) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(ctx)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _formatDateDivider(at.toLocal()),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(ctx)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      );

  static const _weekdayNames = <String>[
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  static const _monthNames = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Today / Yesterday for the last two days; weekday name for anything
  /// else in the past 6 days; "May 21, 2026" for older.
  String _formatDateDivider(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) {
      return _weekdayNames[at.weekday - 1];
    }
    return '${_monthNames[at.month - 1]} ${at.day}, ${at.year}';
  }

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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Center(
          child: Text(
            "You're no longer in this group",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
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
