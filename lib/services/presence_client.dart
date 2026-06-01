import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/hex_codec.dart';
import 'signing_service.dart';

/// One peer's server-reported liveness.
class PresenceInfo {
  const PresenceInfo({required this.online, this.lastSeen});
  final bool online;
  final DateTime? lastSeen; // null when server reports last_seen == 0

  factory PresenceInfo.fromJson(Map<String, dynamic> j) {
    final ls = (j['last_seen'] as num?)?.toInt() ?? 0;
    return PresenceInfo(
      online: j['online'] == true,
      lastSeen: ls > 0
          ? DateTime.fromMillisecondsSinceEpoch(ls * 1000, isUtc: true)
          : null,
    );
  }
}

/// Queries the relay's signed `POST /v1/presence`. Signature contract matches
/// PhonebookClient: Ed25519 over `"<rfc3339 ts>\n<body>"`.
class PresenceClient {
  PresenceClient({
    required this.baseUri,
    required this.signing,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final Uri baseUri;
  final SigningService signing;
  final http.Client _http;

  /// Returns presence per requested pubkey. On any network/server error
  /// returns an empty map (caller keeps last-known state).
  Future<Map<String, PresenceInfo>> fetchPresence(
      List<String> pubkeysHex) async {
    if (pubkeysHex.isEmpty) return const {};
    final body = jsonEncode({'pubkeys': pubkeysHex});
    final ts = _rfc3339Now();
    final pubHex = await signing.publicKeyHex();
    final sig = await signing.sign(utf8.encode('$ts\n$body'));
    final url = baseUri.resolve('/v1/presence');

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
      _log('fetch network error: $e');
      return const {};
    }
    if (resp.statusCode != 200) {
      _log('fetch failed status=${resp.statusCode}');
      return const {};
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final map = (decoded['presence'] as Map<String, dynamic>? ?? {});
    return map.map((k, v) =>
        MapEntry(k, PresenceInfo.fromJson(v as Map<String, dynamic>)));
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

  static void _log(String msg) {
    // ignore: avoid_print
    print('[Presence] $msg');
  }
}
