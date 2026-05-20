import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/hex_codec.dart';
import 'signing_service.dart';

/// Outcome of a phonebook registration attempt.
enum PhonebookRegisterStatus {
  ok,
  unauthorized,
  serverError,
  networkError,
}

class PhonebookRegisterResult {
  const PhonebookRegisterResult(this.status, {this.detail});
  final PhonebookRegisterStatus status;
  final String? detail;

  bool get ok => status == PhonebookRegisterStatus.ok;
}

/// Talks to the heartbeat-server's signed REST endpoints
/// (`POST /v1/phonebook/register`). Signature contract is the same as the
/// relay WS upgrade: Ed25519 over `"<rfc3339 timestamp>\n<body>"`,
/// hex-encoded into the X-Heartbeat-Sig header.
class PhonebookClient {
  PhonebookClient({
    required this.baseUri,
    required this.signing,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final Uri baseUri;
  final SigningService signing;
  final http.Client _http;

  Future<PhonebookRegisterResult> register({
    required String fcmToken,
    required String platform,
  }) async {
    final body = jsonEncode({'fcm_token': fcmToken, 'platform': platform});
    final ts = _rfc3339Now();
    final pubHex = await signing.publicKeyHex();
    final sig = await signing.sign(utf8.encode('$ts\n$body'));
    final url = baseUri.resolve('/v1/phonebook/register');

    final http.Response resp;
    try {
      resp = await _http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Heartbeat-Pubkey': pubHex,
          'X-Heartbeat-Sig': bytesToHex(sig),
          'X-Heartbeat-Timestamp': ts,
        },
        body: body,
      );
    } catch (e) {
      _log('register network error: $e');
      return PhonebookRegisterResult(
        PhonebookRegisterStatus.networkError,
        detail: e.toString(),
      );
    }

    if (resp.statusCode == 200) {
      _log('register ok pub=${_short(pubHex)} platform=$platform');
      return const PhonebookRegisterResult(PhonebookRegisterStatus.ok);
    }
    if (resp.statusCode == 401) {
      _log('register 401 — signature rejected by server');
      return PhonebookRegisterResult(
        PhonebookRegisterStatus.unauthorized,
        detail: resp.body,
      );
    }
    _log('register failed status=${resp.statusCode} body=${resp.body}');
    return PhonebookRegisterResult(
      PhonebookRegisterStatus.serverError,
      detail: 'status=${resp.statusCode} body=${resp.body}',
    );
  }

  void dispose() => _http.close();

  /// RFC3339 UTC timestamp without fractional seconds. Matches the format
  /// `time.RFC3339` parses on the server side (and the format RelayClient
  /// already uses for its WS upgrade).
  static String _rfc3339Now() {
    final now = DateTime.now().toUtc();
    final iso = now.toIso8601String();
    final m = RegExp(r'^(.+?)(?:\.\d+)?(Z)$').firstMatch(iso);
    if (m == null) return iso;
    return '${m.group(1)}${m.group(2)}';
  }

  static String _short(String hex) =>
      hex.length >= 16 ? '${hex.substring(0, 6)}…${hex.substring(hex.length - 6)}' : hex;

  static void _log(String msg) {
    // ignore: avoid_print
    print('[Phonebook] $msg');
  }
}
