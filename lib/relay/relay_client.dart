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

    _log('connecting as $pubHex');
    try {
      final webSocket = await WebSocket.connect(
        relayWsUrl.toString(),
        headers: {
          'X-Heartbeat-Pubkey': pubHex,
          'X-Heartbeat-Sig': sigHex,
          'X-Heartbeat-Timestamp': tsStr,
        },
      );
      // Client-side pings + close-on-missed-pong. Without this, a TCP
      // half-open after server-side close (or wifi flap) is invisible to
      // the application: sink.add succeeds into the void, onDone never
      // fires, and every send is silently dropped. Pair with the server's
      // 15s ping-loop so either side can detect death within ~20s.
      webSocket.pingInterval = const Duration(seconds: 15);
      _channel = IOWebSocketChannel(webSocket);
      _log('connected');
    } catch (e, st) {
      _log('CONNECT FAIL: $e\n$st');
      rethrow;
    }

    _channel!.stream.listen(
      (data) {
        if (data is String) {
          try {
            final frame = RelayFrame.parse(data);
            _log('inbound type=${frame.runtimeType} raw=${data.length}B');
            _inbound.add(frame);
          } catch (e) {
            _log('inbound parse FAIL: $e raw=$data');
          }
        }
      },
      onError: (e) {
        _log('stream error: $e');
        if (!_inbound.isClosed) _inbound.close();
      },
      onDone: () {
        _log('stream done');
        if (!_inbound.isClosed) _inbound.close();
      },
    );
  }

  Future<void> send({
    required String toPubkeyHex,
    required List<int> envelope,
  }) async {
    if (_channel == null) {
      _log('SEND while disconnected! to=$toPubkeyHex');
      return;
    }
    _channel!.sink.add(
      RelayFrame.buildSend(toPubkeyHex: toPubkeyHex, envelope: envelope),
    );
    _log('sent to=${toPubkeyHex.substring(0, 8)} envBytes=${envelope.length}');
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
    final iso = now.toIso8601String();
    final m = RegExp(r'^(.+?)(?:\.\d+)?(Z)$').firstMatch(iso);
    if (m == null) return iso;
    return '${m.group(1)}${m.group(2)}';
  }

  static void _log(String msg) {
    // ignore: avoid_print
    print('[Relay] $msg');
  }
}
