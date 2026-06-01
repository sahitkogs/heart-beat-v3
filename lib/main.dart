import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'chat/chat_providers.dart';
import 'features/chat/chat_list_screen.dart';
import 'features/presence/presence_provider.dart';
import 'features/chat/chat_thread_screen.dart';
import 'features/chat/chat_thread_provider.dart';
import 'features/contacts/add_contact_screen.dart';
import 'features/contacts/contact_link.dart';
import 'features/contacts/contacts_provider.dart';
import 'features/profile/display_name_setup_screen.dart';
import 'features/sharing/pending_share_provider.dart';
import 'firebase_options.dart';
import 'services/background_message_handler.dart';
import 'services/notifications_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_provider.dart';

/// Global navigator key used by the notification tap handler to push the
/// chat thread from a `BuildContext`-less callback (NotificationsService).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void _openChatThread(String chatId) {
  final state = rootNavigatorKey.currentState;
  if (state == null) {
    // Navigator isn't mounted yet — possible during cold-launch before
    // MaterialApp builds. The cold-launch path handles this case via
    // initialRoute below.
    return;
  }
  state.push(
    MaterialPageRoute(
      builder: (_) => ChatThreadScreen(chatId: chatId),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // ignore: avoid_print
    print('[main] Firebase initialized');

    // Background handler MUST be registered before runApp so Android can
    // dispatch into our isolate when the app is killed.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    // Foreground handler: persist the message silently — no banner — and
    // let drift's watch() refresh the chat UI.
    FirebaseMessaging.onMessage.listen((msg) {
      firebaseMessagingForegroundHandler(msg).catchError((Object e) {
        // ignore: avoid_print
        print('[main] foreground fcm handler error: $e');
      });
    });
  } catch (e, st) {
    // ignore: avoid_print
    print('[main] Firebase init FAILED (continuing without push): $e\n$st');
  }

  try {
    await NotificationsService.instance.init(onTap: _openChatThread);
    // ignore: avoid_print
    print('[main] NotificationsService initialized');
  } catch (e, st) {
    // ignore: avoid_print
    print('[main] NotificationsService init FAILED: $e\n$st');
  }

  // Cold-launch from a tapped notification: the app process was killed,
  // user tapped, OS started us. The payload is available via FLN; we
  // schedule the chat-thread push after the first frame builds.
  String? coldLaunchChatId;
  try {
    coldLaunchChatId = await NotificationsService.instance.getLaunchPayload();
  } catch (e) {
    // ignore: avoid_print
    print('[main] getLaunchPayload error: $e');
  }

  // Cold-launch from a tapped heartbeat://add deep link: the OS started us
  // with the initial URI. Parse it into a ContactLink (null if the `k` param
  // isn't a valid pubkey) and thread it through the same way as
  // coldLaunchChatId so StartupRouter can push the prefilled AddContactScreen.
  ContactLink? coldLaunchContact;
  try {
    final initialUri = await AppLinks().getInitialLink();
    if (initialUri != null) coldLaunchContact = ContactLink.parse(initialUri);
  } catch (e) {
    // ignore: avoid_print
    print('[main] getInitialLink error: $e');
  }

  // Cold-launch from a tapped "Share to heart•beat" (ACTION_SEND text/plain):
  // the OS started us with the shared text in the initial media. Read it and
  // thread it through the same way as coldLaunchContact so StartupRouter can
  // seed pendingShareTextProvider — landing Chats-home in forward mode.
  String? coldLaunchShareText;
  try {
    final media = await ReceiveSharingIntent.instance.getInitialMedia();
    final txt = media
        .where((m) => m.type == SharedMediaType.text)
        .map((m) => m.path)
        .where((s) => s.isNotEmpty)
        .join('\n');
    if (txt.isNotEmpty) coldLaunchShareText = txt;
  } catch (e) {
    // ignore: avoid_print
    print('[main] getInitialMedia error: $e');
  } finally {
    // Always clear the cached initial media so it isn't re-delivered on the
    // next (non-share) cold launch — even if reading/parsing above threw.
    try {
      await ReceiveSharingIntent.instance.reset();
    } catch (_) {/* nothing cached, or platform unsupported */}
  }

  runApp(ProviderScope(
      child: HeartbeatV3App(
    coldLaunchChatId: coldLaunchChatId,
    coldLaunchContact: coldLaunchContact,
    coldLaunchShareText: coldLaunchShareText,
  )));
}

class HeartbeatV3App extends ConsumerStatefulWidget {
  const HeartbeatV3App({
    super.key,
    this.coldLaunchChatId,
    this.coldLaunchContact,
    this.coldLaunchShareText,
  });

  /// Chat id (direct = peer pubkey hex, group = group hex id) carried over
  /// by a notification that woke the process from a fully-killed state.
  /// Null on a regular launch.
  final String? coldLaunchChatId;

  /// Add-contact link carried over by a heartbeat://add deep link that woke
  /// the process from a fully-killed state. Null on a regular launch.
  final ContactLink? coldLaunchContact;

  /// Text shared INTO the app (ACTION_SEND) that woke the process from a
  /// fully-killed state. Null on a regular launch. Seeds
  /// pendingShareTextProvider so Chats-home opens in forward mode.
  final String? coldLaunchShareText;

  @override
  ConsumerState<HeartbeatV3App> createState() => _HeartbeatV3AppState();
}

class _HeartbeatV3AppState extends ConsumerState<HeartbeatV3App>
    with WidgetsBindingObserver {
  // Cold-launch routing is owned by StartupRouter (not duplicated here)
  // so the chat-thread push and the '/chats' replacement don't race.

  /// Warm (app-already-running) heartbeat://add deep link subscription.
  StreamSubscription<Uri>? _linkSub;

  /// Warm (app-already-running) "Share to heart•beat" text subscription.
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Warm deep links: while the app is running, a tapped heartbeat://add
    // link arrives here. Parse it and push the prefilled AddContactScreen on
    // top of whatever is currently shown. Subscribed once; cancelled in
    // dispose(). The cold-launch initial URI is handled separately in main().
    _linkSub = AppLinks().uriLinkStream.listen((uri) {
      final contact = ContactLink.parse(uri);
      if (contact == null) return;
      rootNavigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => AddContactScreen(
          initialHex: contact.pubkeyHex,
          initialName: contact.name,
        ),
      ));
    });

    // Warm share intents: while the app is running, text shared INTO
    // heart•beat (ACTION_SEND) arrives here. Seed pendingShareTextProvider so
    // Chats-home shows the forward banner, then bring Chats-home to the front
    // (popUntil first route — '/chats' is the first route after StartupRouter's
    // pushReplacementNamed). Subscribed once; cancelled in dispose(). The
    // cold-launch initial media is handled separately in main().
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen((media) {
      final txt = media
          .where((m) => m.type == SharedMediaType.text)
          .map((m) => m.path)
          .where((s) => s.isNotEmpty)
          .join('\n');
      if (txt.isEmpty) return;
      if (!mounted) return;
      ref.read(pendingShareTextProvider.notifier).state = txt;
      rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _shareSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// T13.BUG.3 — when the app comes back to the foreground, invalidate the
  /// drift-backed providers so a fresh query picks up rows written by the
  /// FCM background isolate (whose AppDatabase instance is separate, so its
  /// inserts don't notify our main-isolate stream watchers).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // StreamProviders re-subscribe to drift's watch() on invalidate, so the
      // newly-emitted snapshot reflects current row state.
      ref.invalidate(chatsStreamProvider);
      ref.invalidate(chatThreadProvider);
      ref.invalidate(chatProvider);
      ref.invalidate(groupActiveMembersProvider);
      ref.invalidate(contactsListProvider);
      ref.read(presenceProvider.notifier).startPolling();
    } else if (state == AppLifecycleState.paused) {
      ref.read(presenceProvider.notifier).stopPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'heart•beat',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      navigatorKey: rootNavigatorKey,
      routes: {
        '/chats': (_) => const ChatListScreen(),
      },
      home: StartupRouter(
        coldLaunchChatId: widget.coldLaunchChatId,
        coldLaunchContact: widget.coldLaunchContact,
        coldLaunchShareText: widget.coldLaunchShareText,
      ),
    );
  }
}

/// Reads profile.displayName once on first frame and routes the user:
///   - profile null            → DisplayNameSetupScreen
///   - profile set, no chatId  → '/chats'
///   - profile set, cold chatId → '/chats' THEN push ChatThreadScreen on top
///     (so back goes Chats → exit, matching the warm-tap behavior of
///     NotificationsService.onTap)
///
/// Owning all cold-launch routing here avoids the previous race between this
/// screen's pushReplacementNamed and a duplicate push in HeartbeatV3App.
class StartupRouter extends ConsumerStatefulWidget {
  const StartupRouter({
    super.key,
    this.coldLaunchChatId,
    this.coldLaunchContact,
    this.coldLaunchShareText,
  });

  /// Chat id (direct = peer pubkey hex, group = group hex id) carried in by
  /// a tapped notification that woke the process from a killed state. Null
  /// on a regular launch.
  final String? coldLaunchChatId;

  /// Add-contact link carried in by a heartbeat://add deep link that woke the
  /// process from a killed state. Null on a regular launch. Pushed on top of
  /// '/chats' so back returns to the chat list.
  final ContactLink? coldLaunchContact;

  /// Text shared INTO the app (ACTION_SEND) that woke the process from a
  /// killed state. Null on a regular launch. Seeds pendingShareTextProvider
  /// after '/chats' is in place so Chats-home opens in forward mode (no extra
  /// screen pushed — the banner appears because the provider is set).
  final String? coldLaunchShareText;

  @override
  ConsumerState<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends ConsumerState<StartupRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Cold-launch: no AppLifecycleState.resumed fires when the app starts
      // already-foregrounded, so kick the poller here. startPolling() is
      // idempotent (timer ??= …), so this is safe if resumed fires as well.
      ref.read(presenceProvider.notifier).startPolling();
      final dao = ref.read(profileDaoProvider);
      final row = await dao.get();
      if (!mounted) return;
      if (row == null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => const DisplayNameSetupScreen(),
        ));
        return;
      }
      final chatId = widget.coldLaunchChatId;
      final contact = widget.coldLaunchContact;
      Navigator.of(context).pushReplacementNamed('/chats');
      if (chatId != null) {
        // pushReplacementNamed above completes synchronously enough that
        // the new ChatListScreen is on the stack before we push the thread.
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatThreadScreen(chatId: chatId),
        ));
      }
      if (contact != null) {
        // Same as the chat-thread push above: lands on top of '/chats' so
        // back returns to the chat list. Coexists with a chatId push if both
        // happen to be set (AddContactScreen ends up on top).
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AddContactScreen(
            initialHex: contact.pubkeyHex,
            initialName: contact.name,
          ),
        ));
      }
      final shareText = widget.coldLaunchShareText;
      if (shareText != null) {
        // No screen to push: cold launch already lands on '/chats', and the
        // Chats-home forward banner appears because the provider is set. Done
        // after pushReplacementNamed('/chats') so the chat list is mounted.
        ref.read(pendingShareTextProvider.notifier).state = shareText;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
