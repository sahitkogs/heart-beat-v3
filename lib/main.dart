import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat/chat_providers.dart';
import 'features/chat/chat_list_screen.dart';
import 'features/chat/chat_thread_screen.dart';
import 'features/chat/chat_thread_provider.dart';
import 'features/contacts/contacts_provider.dart';
import 'features/profile/display_name_setup_screen.dart';
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

  runApp(ProviderScope(
      child: HeartbeatV3App(coldLaunchChatId: coldLaunchChatId)));
}

class HeartbeatV3App extends ConsumerStatefulWidget {
  const HeartbeatV3App({super.key, this.coldLaunchChatId});

  /// Chat id (direct = peer pubkey hex, group = group hex id) carried over
  /// by a notification that woke the process from a fully-killed state.
  /// Null on a regular launch.
  final String? coldLaunchChatId;

  @override
  ConsumerState<HeartbeatV3App> createState() => _HeartbeatV3AppState();
}

class _HeartbeatV3AppState extends ConsumerState<HeartbeatV3App>
    with WidgetsBindingObserver {
  // Cold-launch routing is owned by StartupRouter (not duplicated here)
  // so the chat-thread push and the '/chats' replacement don't race.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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
    if (state != AppLifecycleState.resumed) return;
    // StreamProviders re-subscribe to drift's watch() on invalidate, so the
    // newly-emitted snapshot reflects current row state.
    ref.invalidate(chatsStreamProvider);
    ref.invalidate(chatThreadProvider);
    ref.invalidate(chatProvider);
    ref.invalidate(groupActiveMembersProvider);
    ref.invalidate(contactsListProvider);
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
      home: StartupRouter(coldLaunchChatId: widget.coldLaunchChatId),
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
  const StartupRouter({super.key, this.coldLaunchChatId});

  /// Chat id (direct = peer pubkey hex, group = group hex id) carried in by
  /// a tapped notification that woke the process from a killed state. Null
  /// on a regular launch.
  final String? coldLaunchChatId;

  @override
  ConsumerState<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends ConsumerState<StartupRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
      Navigator.of(context).pushReplacementNamed('/chats');
      if (chatId != null) {
        // pushReplacementNamed above completes synchronously enough that
        // the new ChatListScreen is on the stack before we push the thread.
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatThreadScreen(chatId: chatId),
        ));
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
