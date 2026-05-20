import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
import 'firebase_options.dart';
import 'services/background_message_handler.dart';
import 'services/notifications_service.dart';
import 'theme/app_theme.dart';

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
    await NotificationsService.instance.init();
    // ignore: avoid_print
    print('[main] NotificationsService initialized');
  } catch (e, st) {
    // ignore: avoid_print
    print('[main] NotificationsService init FAILED: $e\n$st');
  }

  runApp(const ProviderScope(child: HeartbeatV3App()));
}

class HeartbeatV3App extends StatelessWidget {
  const HeartbeatV3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heartbeat v3',
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
