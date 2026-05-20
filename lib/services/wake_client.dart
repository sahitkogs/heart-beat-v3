import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/hex_codec.dart';

/// Length in bytes of the sender pubkey prefix in a wake payload. Ed25519
/// public keys are 32 bytes — same as everywhere else in Heartbeat.
const int wakeSenderPubkeyBytes = 32;

/// Outcome of a /v1/wake call.
enum WakeStatus {
  ok,
  recipientNotRegistered,
  fcmError,
  networkError,
  serverError,
}

class WakeResult {
  const WakeResult(this.status, {this.detail});
  final WakeStatus status;
  final String? detail;
  bool get ok => status == WakeStatus.ok;
}

/// Talks to the relay's `POST /v1/wake` endpoint. The endpoint itself is
/// unauthenticated — the server looks up the recipient's FCM token in the
/// phonebook (populated via signed [PhonebookClient.register]) and bridges
/// to FCM. We're free to hammer this with any envelope: only the recipient
/// can actually decrypt it.
class WakeClient {
  WakeClient({
    required this.baseUri,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final Uri baseUri;
  final http.Client _http;

  /// Wake [recipientPubkeyHex] with [envelope] (the regular EnvelopeWire
  /// bytes). The sender's pubkey is prefixed to the payload because, unlike
  /// the relay's `deliver` frame, FCM data has no `from` field — the
  /// background isolate strips the first 32 bytes to know which libsignal
  /// session to decrypt with.
  Future<WakeResult> wake({
    required String senderPubkeyHex,
    required String recipientPubkeyHex,
    required List<int> envelope,
  }) async {
    final senderBytes = hexToBytes(senderPubkeyHex);
    if (senderBytes.length != wakeSenderPubkeyBytes) {
      throw ArgumentError(
        'sender pubkey must decode to $wakeSenderPubkeyBytes bytes',
      );
    }
    final wakePayload = Uint8List(senderBytes.length + envelope.length)
      ..setRange(0, senderBytes.length, senderBytes)
      ..setRange(senderBytes.length, senderBytes.length + envelope.length, envelope);
    final body = jsonEncode({
      'recipient_pubkey': recipientPubkeyHex,
      'opaque_payload': base64Encode(wakePayload),
    });
    final url = baseUri.resolve('/v1/wake');

    final http.Response resp;
    try {
      resp = await _http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
    } catch (e) {
      return WakeResult(WakeStatus.networkError, detail: e.toString());
    }

    if (resp.statusCode == 200) {
      return const WakeResult(WakeStatus.ok);
    }
    if (resp.statusCode == 404) {
      return WakeResult(
        WakeStatus.recipientNotRegistered,
        detail: resp.body,
      );
    }
    if (resp.statusCode == 502) {
      return WakeResult(WakeStatus.fcmError, detail: resp.body);
    }
    return WakeResult(
      WakeStatus.serverError,
      detail: 'status=${resp.statusCode} body=${resp.body}',
    );
  }

  void dispose() => _http.close();
}
