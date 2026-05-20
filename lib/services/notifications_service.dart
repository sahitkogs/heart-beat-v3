import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wraps `flutter_local_notifications`. Initialization is idempotent and safe
/// to call from both the main isolate (T1.4 / T8) and the FCM background
/// isolate (T7). Each isolate has its own singleton; both end up talking to
/// the same OS-side notification channel.
class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  /// Channel for Heartbeat chat messages. High importance so messages get a
  /// heads-up banner. Lock-screen content visibility is set per-notification
  /// at post time (so individual messages can opt out if needed) — defaults
  /// to public, masked by the user's Android lock-screen privacy setting.
  static const String messagesChannelId = 'heartbeat_messages';
  static const String _messagesChannelName = 'Heartbeat messages';
  static const String _messagesChannelDescription =
      'Incoming Heartbeat chat messages';

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await plugin.initialize(settings: initSettings);

    if (Platform.isAndroid) {
      final androidPlugin = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          messagesChannelId,
          _messagesChannelName,
          description: _messagesChannelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    _initialized = true;
  }
}
