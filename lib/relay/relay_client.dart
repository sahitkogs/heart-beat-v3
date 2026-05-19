import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

import '../core/hex_codec.dart';
import '../services/signing_service.dart';
import 'relay_frames.dart';

/// Talks to the Heartbeat relay over its WebSocket signaling endpoint.
/// Auth: Ed25519 signature over `"WS-CONNECT:<RFC3339 timestamp>"`.
class RelayClient {
  RelayClient({
    required this.relayWsUrl,
    required this.signing,
  });

  /// e.g. ws://34.42.231.29:8080/v1/signal
  final Uri relayWsUrl;
  final SigningService signing;

  IOWebSocketChannel? _channel;
  final StreamController<RelayFrame> _inbound =
      StreamController<RelayFrame>.broadcast();

  /// Broadcasts every parsed frame the server sends.
  Stream<RelayFrame> get inbound => _inbound.stream;

  Future<void> connect() async {
    final tsStr = _rfc3339Now();
    final pubHex = await signing.publicKeyHex();
    final sig = await signing.sign(utf8.encode('WS-CONNECT:$tsStr'));
    final sigHex = bytesToHex(sig);

    final webSocket = await WebSocket.connect(
      relayWsUrl.toString(),
      headers: {
        'X-Heartbeat-Pubkey': pubHex,
        'X-Heartbeat-Sig': sigHex,
        'X-Heartbeat-Timestamp': tsStr,
      },
    );
    _channel = IOWebSocketChannel(webSocket);

    _channel!.stream.listen(
      (data) {
        if (data is String) {
          try {
            _inbound.add(RelayFrame.parse(data));
          } catch (_) {
            // Drop unparseable frames silently for now.
          }
        }
      },
      onError: (_) {
        if (!_inbound.isClosed) _inbound.close();
      },
      onDone: () {
        if (!_inbound.isClosed) _inbound.close();
      },
    );
  }

  Future<void> send({
    required String toPubkeyHex,
    required List<int> envelope,
  }) async {
    _channel?.sink.add(
      RelayFrame.buildSend(toPubkeyHex: toPubkeyHex, envelope: envelope),
    );
  }

  Future<void> dispose() async {
    await _channel?.sink.close();
    if (!_inbound.isClosed) {
      await _inbound.close();
    }
  }

  /// RFC3339 UTC timestamp without fractional seconds (matches Go's
  /// `time.RFC3339`, which the server expects).
  String _rfc3339Now() {
    final now = DateTime.now().toUtc();
    // toIso8601String() produces e.g. "2026-05-19T12:34:56.789Z"; strip fractional seconds.
    final iso = now.toIso8601String();
    final m = RegExp(r'^(.+?)(?:\.\d+)?(Z)$').firstMatch(iso);
    if (m == null) return iso;
    return '${m.group(1)}${m.group(2)}';
  }
}
