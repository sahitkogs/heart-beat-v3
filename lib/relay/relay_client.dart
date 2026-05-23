import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

import '../core/hex_codec.dart';
import '../services/signing_service.dart';
import 'relay_frames.dart';

/// Talks to the Heartbeat relay over its WebSocket signaling endpoint.
/// Auth: Ed25519 signature over `"WS-CONNECT:<RFC3339 timestamp>"`.
///
/// Owns its own reconnect lifecycle. Once [connect] succeeds the first time,
/// the client will transparently re-establish the WS on disconnect (Android
/// Doze / battery optimization / wifi cycle / etc.) with exponential backoff,
/// without closing [inbound] — so MessageService keeps its existing
/// subscription across reconnects.
class RelayClient {
  RelayClient({
    required this.relayWsUrl,
    required this.signing,
  });

  /// e.g. ws://34.42.231.29:8080/v1/signal
  final Uri relayWsUrl;
  final SigningService signing;

  IOWebSocketChannel? _channel;
  bool _wsAlive = false;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;

  static const Duration _baseBackoff = Duration(seconds: 1);
  static const Duration _maxBackoff = Duration(seconds: 30);

  final StreamController<RelayFrame> _inbound =
      StreamController<RelayFrame>.broadcast();

  /// Broadcasts every parsed frame the server sends. Survives reconnects.
  Stream<RelayFrame> get inbound => _inbound.stream;

  /// True between a successful WS handshake and the next disconnect.
  bool get isConnected => _wsAlive;

  /// Establish the first connection. Throws on initial failure so callers
  /// can surface "couldn't reach the relay at all" at app start. Once this
  /// resolves, any subsequent disconnect schedules an automatic reconnect.
  Future<void> connect() async {
    if (_disposed) {
      throw StateError('connect() after dispose()');
    }
    await _openSocket();
  }

  Future<void> _openSocket() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final tsStr = _rfc3339Now();
    final pubHex = await signing.publicKeyHex();
    final sig = await signing.sign(utf8.encode('WS-CONNECT:$tsStr'));
    final sigHex = bytesToHex(sig);

    _log('connecting as $pubHex (attempt=${_reconnectAttempt + 1})');
    final WebSocket webSocket;
    try {
      webSocket = await WebSocket.connect(
        relayWsUrl.toString(),
        headers: {
          'X-Heartbeat-Pubkey': pubHex,
          'X-Heartbeat-Sig': sigHex,
          'X-Heartbeat-Timestamp': tsStr,
        },
      );
    } catch (e, st) {
      _log('CONNECT FAIL: $e\n$st');
      _wsAlive = false;
      _channel = null;
      _scheduleReconnect();
      // Only the very first connect rethrows; reconnects swallow so the
      // background retry doesn't crash the app.
      if (_reconnectAttempt == 0) rethrow;
      return;
    }

    // Aggressive client ping so a network drop is detected by us within
    // ~15s. The server has its own 5s ping loop; this is the belt-and-
    // suspenders pair. nhooyr/websocket auto-responds to client pings,
    // and dart:io auto-responds to server pings.
    webSocket.pingInterval = const Duration(seconds: 15);
    _channel = IOWebSocketChannel(webSocket);
    _wsAlive = true;
    _reconnectAttempt = 0;
    _log('connected');

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
        _handleDisconnect();
      },
      onDone: () {
        _log('stream done');
        _handleDisconnect();
      },
    );
  }

  void _handleDisconnect() {
    // Idempotent — both onError and onDone can fire on the same disconnect.
    if (!_wsAlive && _channel == null) return;
    _wsAlive = false;
    _channel = null;
    if (_disposed) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (_reconnectTimer != null) return;
    _reconnectAttempt += 1;
    final backoffMs = (_baseBackoff.inMilliseconds *
            (1 << (_reconnectAttempt - 1).clamp(0, 5)))
        .clamp(0, _maxBackoff.inMilliseconds);
    final delay = Duration(milliseconds: backoffMs);
    _log('scheduling reconnect in ${delay.inMilliseconds}ms '
        '(attempt $_reconnectAttempt)');
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _openSocket();
    });
  }

  /// Send a message via the relay. Throws [StateError] if the WebSocket is
  /// not currently connected, so callers (e.g. MessageService) can surface
  /// a real failure to the UI instead of optimistically rendering a bubble
  /// that never reaches the server.
  ///
  /// Side-effect: if disconnected, kicks the reconnect timer immediately so
  /// the next retry doesn't wait for the full backoff.
  Future<void> send({
    required String toPubkeyHex,
    required List<int> envelope,
  }) async {
    if (!_wsAlive || _channel == null) {
      _log('SEND while disconnected to=$toPubkeyHex — kicking reconnect');
      _kickReconnect();
      throw StateError('relay disconnected');
    }
    _channel!.sink.add(
      RelayFrame.buildSend(toPubkeyHex: toPubkeyHex, envelope: envelope),
    );
    _log('sent to=${toPubkeyHex.substring(0, 8)} envBytes=${envelope.length}');
  }

  /// Force an immediate reconnect attempt (skipping the rest of the
  /// current backoff). No-op if already connecting or connected.
  void _kickReconnect() {
    if (_disposed || _wsAlive) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    // _reconnectAttempt is left as-is so the next failure still backs off.
    _openSocket();
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _wsAlive = false;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
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
