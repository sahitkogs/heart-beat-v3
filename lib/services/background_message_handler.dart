import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';

import '../chat/pre_key_bootstrap.dart';
import '../core/hex_codec.dart';
import '../data/app_database.dart';
import '../data/chats_dao.dart';
import '../data/contacts_repository.dart';
import '../firebase_options.dart';
import 'libsignal_crypto_service.dart';
import 'notifications_service.dart';
import 'wake_client.dart';

/// Top-level entry point Android invokes when the app is killed or
/// backgrounded and an FCM data message arrives. MUST be a top-level
/// function annotated with `@pragma('vm:entry-point')` so the AOT compiler
/// keeps it in the binary.
///
/// Wake payload format (set in [WakeClient.wake]):
///   `senderPubkey(32 bytes) || envelope(EnvelopeWire bytes)`
///
/// Splits the sender prefix, parses the envelope, decrypts (or processes a
/// bundle), persists to drift, and shows a notification. Always cleans up
/// its own DB connection.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Already-initialized is fine; Android can call us during a hot lifecycle.
    _log('Firebase.initializeApp: $e');
  }
  await processFcmMessage(message, showNotification: true);
}

/// Foreground variant: called by `FirebaseMessaging.onMessage` when the
/// app is open. Persists the message but does NOT show a banner — the chat
/// UI will reflect it automatically via the drift `watch()` streams.
Future<void> firebaseMessagingForegroundHandler(RemoteMessage message) async {
  await processFcmMessage(message, showNotification: false);
}

/// Shared core of both handlers. Exposed so tests can drive it without a
/// real Firebase invocation.
Future<void> processFcmMessage(
  RemoteMessage message, {
  required bool showNotification,
}) async {
  final raw = message.data['hb_payload'];
  if (raw is! String || raw.isEmpty) {
    _log('missing hb_payload in FCM data');
    return;
  }

  final Uint8List wakePayload;
  try {
    wakePayload = base64Decode(raw);
  } catch (e) {
    _log('base64 decode failed: $e');
    return;
  }

  if (wakePayload.length < wakeSenderPubkeyBytes + 1) {
    _log('wake payload too short: ${wakePayload.length}B');
    return;
  }

  final senderPubkeyHex = bytesToHex(
    wakePayload.sublist(0, wakeSenderPubkeyBytes),
  );
  final envelopeBytes = wakePayload.sublist(wakeSenderPubkeyBytes);

  ParsedEnvelope parsed;
  try {
    parsed = EnvelopeWire.parse(envelopeBytes);
  } catch (e) {
    _log('envelope parse failed: $e');
    return;
  }

  // Open a fresh DB connection for this isolate. SQLite WAL mode means a
  // concurrent main-isolate connection is fine; both write to the same file
  // and serialize via WAL.
  final db = AppDatabase();
  try {
    final dao = ChatsDao(db);
    await dao.ensureChat(senderPubkeyHex);

    final crypto = LibsignalCryptoService(db);
    await crypto.initialize();

    if (parsed.isBundle) {
      try {
        await crypto.processPeerPreKeyBundle(parsed.bundle!);
        await dao.markPeerBundleReceived(senderPubkeyHex);
        _log('processed peer bundle from=${_short(senderPubkeyHex)}');
      } catch (e, st) {
        _log('process bundle FAILED from=${_short(senderPubkeyHex)} '
            'err=$e\n$st');
      }
      // Don't auto-reply with OUR bundle from background — the sender will
      // hit recipient_offline again next time they try and re-bridge then.
      // No notification for a bundle alone (it carries no message content).
      return;
    }

    // Message path.
    final List<int> plaintext;
    try {
      plaintext = await crypto.decrypt(
        peerPubkeyHex: senderPubkeyHex,
        ciphertext: parsed.ciphertext!,
      );
    } catch (e, st) {
      _log('decrypt FAILED from=${_short(senderPubkeyHex)} err=$e\n$st');
      return;
    }
    final body = utf8.decode(plaintext);

    final now = DateTime.now();
    final lamport = await dao.bumpLamport(senderPubkeyHex);
    await dao.insertMessage(
      MessagesCompanion.insert(
        id: const Uuid().v4(),
        chatId: senderPubkeyHex,
        senderPubkeyHex: senderPubkeyHex,
        body: body,
        lamport: lamport,
        sentAt: now,
        receivedAt: Value(now),
      ),
    );
    await dao.updateLastMessage(senderPubkeyHex, _preview(body), now);
    _log('persisted message from=${_short(senderPubkeyHex)} bodyLen=${body.length}');

    if (showNotification) {
      final repo = ContactsRepository(db);
      final contacts = await repo.loadAll();
      final isKnown = contacts.any((c) => c.pubkeyHex == senderPubkeyHex);
      // v3 contacts table doesn't store a display name — best we can do is
      // a stable short label. A "Contacts can have nicknames" feature would
      // upgrade this to the user-chosen name.
      final title = isKnown
          ? _short(senderPubkeyHex)
          : 'Unknown ${_short(senderPubkeyHex)}';
      try {
        await _showMessageNotification(
          title: title,
          body: body,
          payload: senderPubkeyHex,
        );
      } catch (e, st) {
        _log('show notification FAILED: $e\n$st');
      }
    }
  } finally {
    await db.close();
  }
}

Future<void> _showMessageNotification({
  required String title,
  required String body,
  required String payload,
}) async {
  // Each isolate gets its own plugin instance. The OS-side channel is shared
  // (created in main isolate at boot), so re-init here is safe + idempotent.
  final plugin = FlutterLocalNotificationsPlugin();
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await plugin.initialize(settings: initSettings);

  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      NotificationsService.messagesChannelId,
      'Heartbeat messages',
      channelDescription: 'Incoming Heartbeat chat messages',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  // Use a 31-bit notification id so each notification stays distinct
  // (Android collapses if id is reused). 31-bit because the int field is
  // signed 32-bit Java int.
  final id = DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff);
  await plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: details,
    payload: payload,
  );
}

String _preview(String body) =>
    body.length <= 80 ? body : '${body.substring(0, 77)}...';

String _short(String hex) =>
    hex.length >= 16
        ? '${hex.substring(0, 6)}…${hex.substring(hex.length - 6)}'
        : hex;

void _log(String msg) {
  // ignore: avoid_print
  print('[BG] $msg');
}
