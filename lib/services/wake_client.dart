import 'dart:convert';

import 'package:http/http.dart' as http;

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

  Future<WakeResult> wake({
    required String recipientPubkeyHex,
    required List<int> envelope,
  }) async {
    final body = jsonEncode({
      'recipient_pubkey': recipientPubkeyHex,
      'opaque_payload': base64Encode(envelope),
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
