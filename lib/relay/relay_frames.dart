import 'dart:convert';

/// Parsed inbound frame from the relay's WebSocket. Mirrors the wire
/// protocol the heartbeat-server emits — see
/// https://github.com/sahitkogs/heartbeat-server/blob/main/docs/PROTOCOL.md
sealed class RelayFrame {
  const RelayFrame();

  static RelayFrame parse(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final type = map['type'] as String;
    switch (type) {
      case 'deliver':
        return DeliverFrame(
          fromPubkeyHex: map['from'] as String,
          envelope: base64.decode(map['envelope'] as String),
        );
      case 'pong':
        return const PongFrame();
      case 'online_status':
        return OnlineStatusFrame(
          pubkeyHex: map['pubkey'] as String,
          online: map['online'] as bool,
        );
      case 'error':
        return ErrorFrame(
          code: map['code'] as String,
          message: (map['message'] as String?) ?? '',
        );
      default:
        return UnknownFrame(type: type, raw: raw);
    }
  }

  /// Build a "send" client frame JSON string.
  static String buildSend({required String toPubkeyHex, required List<int> envelope}) {
    return jsonEncode({
      'type': 'send',
      'to': toPubkeyHex,
      'envelope': base64.encode(envelope),
    });
  }

  static String buildPing() => '{"type":"ping"}';

  static String buildIsOnline(String pubkeyHex) =>
      jsonEncode({'type': 'is_online', 'pubkey': pubkeyHex});
}

class DeliverFrame extends RelayFrame {
  DeliverFrame({required this.fromPubkeyHex, required this.envelope});
  final String fromPubkeyHex;
  final List<int> envelope;
}

class PongFrame extends RelayFrame {
  const PongFrame();
}

class OnlineStatusFrame extends RelayFrame {
  OnlineStatusFrame({required this.pubkeyHex, required this.online});
  final String pubkeyHex;
  final bool online;
}

class ErrorFrame extends RelayFrame {
  ErrorFrame({required this.code, required this.message});
  final String code;
  final String message;
}

class UnknownFrame extends RelayFrame {
  UnknownFrame({required this.type, required this.raw});
  final String type;
  final String raw;
}
