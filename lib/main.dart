import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat/chat_providers.dart';
import 'features/chat/chat_list_screen.dart';
import 'features/chat/chat_thread_screen.dart';
import 'features/profile/display_name_setup_screen.dart';
import 'firebase_options.dart';
import 'services/background_message_handler.dart';
import 'services/notifications_service.dart';
import 'theme/app_theme.dart';

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

class HeartbeatV3App extends StatefulWidget {
  const HeartbeatV3App({super.key, this.coldLaunchChatId});

  /// Chat id (direct = peer pubkey hex, group = group hex id) carried over
  /// by a notification that woke the process from a fully-killed state.
  /// Null on a regular launch.
  final String? coldLaunchChatId;

  @override
  State<HeartbeatV3App> createState() => _HeartbeatV3AppState();
}

class _HeartbeatV3AppState extends State<HeartbeatV3App> {
  @override
  void initState() {
    super.initState();
    final chatId = widget.coldLaunchChatId;
    if (chatId != null) {
      // Wait for the first frame so MaterialApp + Navigator have built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openChatThread(chatId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heartbeat v3',
      theme: buildAppTheme(),
      navigatorKey: rootNavigatorKey,
      routes: {
        '/chats': (_) => const ChatListScreen(),
      },
      home: const StartupRouter(),
    );
  }
}

/// Reads profile.displayName once on first frame and lands the user on
/// DisplayNameSetupScreen (if null) or ChatListScreen (if set). Uses
/// pushReplacement so back-navigation doesn't return to this router.
class StartupRouter extends ConsumerStatefulWidget {
  const StartupRouter({super.key});

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
      } else {
        Navigator.of(context).pushReplacementNamed('/chats');
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
