import 'dart:convert';

import 'package:app_v3/chat/group_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonicalJsonBytes', () {
    test('sorts top-level keys', () {
      final a = canonicalJsonBytes({'b': 1, 'a': 2});
      final b = canonicalJsonBytes({'a': 2, 'b': 1});
      expect(utf8.decode(a), utf8.decode(b));
      expect(utf8.decode(a), '{"a":2,"b":1}');
    });

    test('sorts nested keys recursively', () {
      final s = utf8.decode(canonicalJsonBytes({
        'z': {'y': 1, 'x': 2},
        'a': [3, 1, 2],
      }));
      expect(s, '{"a":[3,1,2],"z":{"x":2,"y":1}}');
    });

    test('omits a named field if requested', () {
      final s = utf8.decode(canonicalJsonBytes(
        {'a': 1, 'sig': 'deadbeef', 'b': 2},
        omit: 'sig',
      ));
      expect(s, '{"a":1,"b":2}');
    });
  });

  group('InnerEnvelope.parse + build', () {
    test('text envelope round-trips', () {
      final bytes = InnerEnvelope.buildText(
        chatId: 'abc123', lamport: 42, body: 'hello',
        msgId: 'm-text-1',
      );
      final parsed = InnerEnvelope.parse(bytes);
      expect(parsed, isA<TextEnvelope>());
      final t = parsed as TextEnvelope;
      expect(t.chatId, 'abc123');
      expect(t.lamport, 42);
      expect(t.body, 'hello');
    });

    test('group_invite envelope round-trips', () {
      final bytes = InnerEnvelope.buildGroupInvite(
        chatId: 'g1', groupName: 'Family', creator: 'creatorPK',
        members: ['m1', 'm2'], createdAt: DateTime.utc(2026, 5, 21),
        opSeq: 1, joinedVia: 'create', sigHex: 'deadbeef',
      );
      final p = InnerEnvelope.parse(bytes) as GroupInviteEnvelope;
      expect(p.chatId, 'g1');
      expect(p.groupName, 'Family');
      expect(p.creator, 'creatorPK');
      expect(p.members, ['m1', 'm2']);
      expect(p.opSeq, 1);
      expect(p.joinedVia, 'create');
      expect(p.sigHex, 'deadbeef');
    });

    test('member_add round-trips', () {
      final bytes = InnerEnvelope.buildMemberAdd(
        chatId: 'g1', lamport: 5, target: 'newM',
        addedAt: DateTime.utc(2026, 5, 21), opSeq: 2, sigHex: 'aa',
      );
      final p = InnerEnvelope.parse(bytes) as MemberAddEnvelope;
      expect(p.target, 'newM');
      expect(p.opSeq, 2);
    });

    test('member_remove round-trips', () {
      final bytes = InnerEnvelope.buildMemberRemove(
        chatId: 'g1', lamport: 6, target: 'badM',
        removedAt: DateTime.utc(2026, 5, 21), opSeq: 3, sigHex: 'bb',
      );
      final p = InnerEnvelope.parse(bytes) as MemberRemoveEnvelope;
      expect(p.target, 'badM');
    });

    test('member_leave round-trips', () {
      final bytes = InnerEnvelope.buildMemberLeave(
        chatId: 'g1', lamport: 7,
        leftAt: DateTime.utc(2026, 5, 21), sigHex: 'cc',
      );
      final p = InnerEnvelope.parse(bytes) as MemberLeaveEnvelope;
      expect(p.lamport, 7);
    });

    test('rejects unknown type', () {
      final bytes = utf8.encode('{"v":1,"type":"???","chatId":"x","lamport":0}');
      expect(() => InnerEnvelope.parse(bytes), throwsA(isA<FormatException>()));
    });

    test('rejects v != 1', () {
      final bytes = utf8.encode('{"v":2,"type":"text","chatId":"x","lamport":0,"body":"y"}');
      expect(() => InnerEnvelope.parse(bytes), throwsA(isA<FormatException>()));
    });

    test('rejects missing required field', () {
      final bytes = utf8.encode('{"v":1,"type":"text","chatId":"x"}');
      expect(() => InnerEnvelope.parse(bytes), throwsA(isA<FormatException>()));
    });
  });

  group('senderDisplayName (Phase 10.4.1)', () {
    test('TextEnvelope round-trip with senderDisplayName', () {
      final bytes = InnerEnvelope.buildText(
        chatId: 'c1', lamport: 1, body: 'hi',
        msgId: 'm-text-2',
        senderDisplayName: 'Sahit',
      );
      final p = InnerEnvelope.parse(bytes) as TextEnvelope;
      expect(p.body, 'hi');
      expect(p.senderDisplayName, 'Sahit');
    });

    test('TextEnvelope absent senderDisplayName parses to null', () {
      final bytes = InnerEnvelope.buildText(chatId: 'c1', lamport: 1, body: 'hi', msgId: 'm-text-3');
      final p = InnerEnvelope.parse(bytes) as TextEnvelope;
      expect(p.senderDisplayName, isNull);
    });

    test('GroupInviteEnvelope round-trip with senderDisplayName', () {
      final bytes = InnerEnvelope.buildGroupInvite(
        chatId: 'g1', groupName: 'Family',
        creator: 'creatorPK', members: const ['m1', 'm2'],
        createdAt: DateTime.utc(2026, 5, 21),
        opSeq: 1, joinedVia: 'create', sigHex: 'deadbeef',
        senderDisplayName: 'Sahit',
      );
      final p = InnerEnvelope.parse(bytes) as GroupInviteEnvelope;
      expect(p.senderDisplayName, 'Sahit');
    });

    test('MemberAddEnvelope round-trip with senderDisplayName', () {
      final bytes = InnerEnvelope.buildMemberAdd(
        chatId: 'g1', lamport: 5, target: 'newM',
        addedAt: DateTime.utc(2026, 5, 21), opSeq: 2, sigHex: 'aa',
        senderDisplayName: 'Sahit K.',
      );
      final p = InnerEnvelope.parse(bytes) as MemberAddEnvelope;
      expect(p.senderDisplayName, 'Sahit K.');
    });

    test('MemberRemoveEnvelope round-trip with senderDisplayName', () {
      final bytes = InnerEnvelope.buildMemberRemove(
        chatId: 'g1', lamport: 6, target: 'badM',
        removedAt: DateTime.utc(2026, 5, 21), opSeq: 3, sigHex: 'bb',
        senderDisplayName: 'Sahit',
      );
      final p = InnerEnvelope.parse(bytes) as MemberRemoveEnvelope;
      expect(p.senderDisplayName, 'Sahit');
    });

    test('MemberLeaveEnvelope round-trip with senderDisplayName', () {
      final bytes = InnerEnvelope.buildMemberLeave(
        chatId: 'g1', lamport: 7,
        leftAt: DateTime.utc(2026, 5, 21), sigHex: 'cc',
        senderDisplayName: 'Bob',
      );
      final p = InnerEnvelope.parse(bytes) as MemberLeaveEnvelope;
      expect(p.senderDisplayName, 'Bob');
    });
  });

  group('TextEnvelope msgId', () {
    test('buildText round-trips msgId', () {
      final bytes = InnerEnvelope.buildText(
        chatId: 'peerA', lamport: 1, body: 'hi',
        msgId: '550e8400-e29b-41d4-a716-446655440000',
      );
      final parsed = InnerEnvelope.parse(bytes);
      expect(parsed, isA<TextEnvelope>());
      expect((parsed as TextEnvelope).msgId,
          '550e8400-e29b-41d4-a716-446655440000');
    });

    test('parse generates UUID when msgId missing (v0 backwards-compat)', () {
      final raw = utf8.encode(jsonEncode({
        'v': 1, 'type': 'text',
        'chatId': 'peerA', 'lamport': 1, 'body': 'old',
      }));
      final parsed = InnerEnvelope.parse(raw) as TextEnvelope;
      expect(parsed.msgId, isNotEmpty);
      expect(parsed.msgId.length, 36); // UUID v4 length
    });

    test('parse treats empty-string msgId as missing', () {
      final raw = utf8.encode(jsonEncode({
        'v': 1, 'type': 'text',
        'chatId': 'peerA', 'lamport': 1, 'body': 'x', 'msgId': '',
      }));
      final parsed = InnerEnvelope.parse(raw) as TextEnvelope;
      expect(parsed.msgId.length, 36);
    });
  });
}
