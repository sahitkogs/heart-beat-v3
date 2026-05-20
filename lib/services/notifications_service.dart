import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

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

  /// Optional callback invoked when the user taps a notification while the
  /// app is in foreground or warm-started. Set by `init(onTap:)`. For
  /// cold-launch (process killed) the payload is delivered via
  /// [getLaunchDetails] instead.
  void Function(String payload)? _onTap;

  Future<void> init({void Function(String payload)? onTap}) async {
    if (_initialized) return;
    _onTap = onTap;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleResponse,
    );

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

  /// Asks the OS for POST_NOTIFICATIONS on Android 13+. No-op on older
  /// Android (status is auto-granted). Returns true if granted, false if
  /// denied or permanently denied — callers should not block on the result;
  /// the only consequence of denial is that the user won't see banners.
  /// Returns the payload that launched the app if the user tapped a
  /// notification while the process was killed. Null otherwise. Caller is
  /// responsible for routing (e.g. pushing ChatThreadScreen).
  Future<String?> getLaunchPayload() async {
    final details = await plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details!.notificationResponse?.payload;
  }

  void _handleResponse(NotificationResponse resp) {
    final payload = resp.payload;
    if (payload == null) return;
    _onTap?.call(payload);
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      // ignore: avoid_print
      print('[Notifications] permission permanently denied; skipping request');
      return false;
    }
    final result = await Permission.notification.request();
    // ignore: avoid_print
    print('[Notifications] permission request result: $result');
    return result.isGranted;
  }
}
