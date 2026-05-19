import 'dart:convert';

import 'package:app_v3/relay/relay_frames.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RelayFrame', () {
    test('parses "deliver" frame', () {
      final raw = jsonEncode({
        'type': 'deliver',
        'from': 'alice-pub',
        'envelope': base64.encode([1, 2, 3]),
      });
      final f = RelayFrame.parse(raw);
      expect(f, isA<DeliverFrame>());
      final d = f as DeliverFrame;
      expect(d.fromPubkeyHex, 'alice-pub');
      expect(d.envelope, [1, 2, 3]);
    });

    test('parses "error" frame', () {
      final raw = jsonEncode({
        'type': 'error',
        'code': 'recipient_offline',
        'message': 'bob',
      });
      final f = RelayFrame.parse(raw);
      expect(f, isA<ErrorFrame>());
      final e = f as ErrorFrame;
      expect(e.code, 'recipient_offline');
      expect(e.message, 'bob');
    });

    test('parses "pong" frame', () {
      final raw = '{"type":"pong"}';
      final f = RelayFrame.parse(raw);
      expect(f, isA<PongFrame>());
    });

    test('parses "online_status" frame', () {
      final raw = jsonEncode({
        'type': 'online_status',
        'pubkey': 'bob',
        'online': true,
      });
      final f = RelayFrame.parse(raw);
      expect(f, isA<OnlineStatusFrame>());
      final s = f as OnlineStatusFrame;
      expect(s.pubkeyHex, 'bob');
      expect(s.online, isTrue);
    });

    test('parses unknown type into UnknownFrame', () {
      final raw = '{"type":"future_frame"}';
      final f = RelayFrame.parse(raw);
      expect(f, isA<UnknownFrame>());
      final u = f as UnknownFrame;
      expect(u.type, 'future_frame');
    });

    test('builds "send" frame', () {
      final s = RelayFrame.buildSend(toPubkeyHex: 'bob-pub', envelope: [9, 8, 7]);
      final parsed = jsonDecode(s) as Map<String, dynamic>;
      expect(parsed['type'], 'send');
      expect(parsed['to'], 'bob-pub');
      expect(parsed['envelope'], base64.encode([9, 8, 7]));
    });

    test('builds "ping" frame', () {
      expect(RelayFrame.buildPing(), '{"type":"ping"}');
    });

    test('builds "is_online" frame', () {
      final raw = RelayFrame.buildIsOnline('alice');
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      expect(parsed['type'], 'is_online');
      expect(parsed['pubkey'], 'alice');
    });
  });
}
