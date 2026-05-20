import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'phonebook_client.dart';

/// Owns the lifecycle of the device's FCM token and the heartbeat-server
/// phonebook registration for it. Called once on app launch (after the
/// identity exists, so SigningService has a key to sign with) and re-registers
/// whenever Firebase rotates the token via onTokenRefresh.
class FcmService {
  FcmService({
    required this.phonebook,
    FirebaseMessaging? messaging,
  }) : _messaging = messaging ?? FirebaseMessaging.instance;

  final PhonebookClient phonebook;
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _refreshSub;
  bool _initialized = false;

  static const _kLastTokenKey = 'fcm_last_registered_token';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    String? token;
    try {
      token = await _messaging.getToken();
    } catch (e, st) {
      _log('getToken FAILED: $e\n$st');
      return;
    }
    if (token == null || token.isEmpty) {
      _log('no FCM token available; phonebook registration skipped');
      return;
    }
    await _registerIfChanged(token);

    _refreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      _log('token refreshed');
      try {
        await _registerIfChanged(newToken);
      } catch (e, st) {
        _log('onTokenRefresh register FAILED: $e\n$st');
      }
    });
  }

  Future<void> _registerIfChanged(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_kLastTokenKey);
    if (last == token) {
      _log('token unchanged; skipping re-register');
      return;
    }
    final result = await phonebook.register(
      fcmToken: token,
      platform: 'android',
    );
    if (result.ok) {
      await prefs.setString(_kLastTokenKey, token);
      _log('phonebook registered');
    } else {
      _log('register status=${result.status} detail=${result.detail}');
    }
  }

  Future<void> dispose() async {
    await _refreshSub?.cancel();
    phonebook.dispose();
  }

  static void _log(String msg) {
    // ignore: avoid_print
    print('[FCM] $msg');
  }
}
