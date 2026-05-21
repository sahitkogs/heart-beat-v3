import 'dart:convert';

/// Canonical-bytes serializer for signature inputs.
/// - Top-level keys sorted alphabetically (recursively).
/// - No whitespace.
/// - Lists preserved in order.
/// - Optionally omit a single top-level field (for stripping `sig` before sign/verify).
List<int> canonicalJsonBytes(Map<String, dynamic> obj, {String? omit}) {
  final entries = obj.entries
      .where((e) => omit == null || e.key != omit)
      .map((e) => MapEntry(e.key, _canon(e.value)))
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final ordered = <String, dynamic>{
    for (final e in entries) e.key: e.value
  };
  return utf8.encode(jsonEncode(ordered));
}

dynamic _canon(dynamic v) {
  if (v is Map<String, dynamic>) {
    final entries = v.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return {for (final e in entries) e.key: _canon(e.value)};
  }
  if (v is List) return v.map(_canon).toList();
  return v;
}

// Sealed-style hierarchy via type checks.
abstract class InnerEnvelope {
  String get chatId;
  int get lamport;

  /// Parse JSON bytes (post-libsignal-decrypt) into a typed envelope.
  /// Throws [FormatException] on unknown/missing fields or version mismatch.
  static InnerEnvelope parse(List<int> bytes) {
    final dynamic raw;
    try {
      raw = jsonDecode(utf8.decode(bytes));
    } catch (e) {
      throw FormatException('inner envelope JSON invalid: $e');
    }
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('inner envelope not a JSON object');
    }
    if (raw['v'] != 1) throw FormatException('unsupported v: ${raw['v']}');
    final type = raw['type'];
    final chatId = raw['chatId'];
    final lamport = raw['lamport'];
    if (chatId is! String || lamport is! int) {
      throw const FormatException('inner envelope missing chatId/lamport');
    }
    switch (type) {
      case 'text':
        final body = raw['body'];
        if (body is! String) throw const FormatException('text missing body');
        return TextEnvelope(chatId: chatId, lamport: lamport, body: body);
      case 'group_invite':
        return GroupInviteEnvelope._fromJson(raw);
      case 'member_add':
        return MemberAddEnvelope._fromJson(raw);
      case 'member_remove':
        return MemberRemoveEnvelope._fromJson(raw);
      case 'member_leave':
        return MemberLeaveEnvelope._fromJson(raw);
      default:
        throw FormatException('unknown inner type: $type');
    }
  }

  static List<int> buildText({
    required String chatId,
    required int lamport,
    required String body,
  }) {
    return utf8.encode(jsonEncode({
      'v': 1, 'type': 'text',
      'chatId': chatId, 'lamport': lamport, 'body': body,
    }));
  }

  static List<int> buildGroupInvite({
    required String chatId,
    required String groupName,
    required String creator,
    required List<String> members,
    required DateTime createdAt,
    required int opSeq,
    required String joinedVia, // 'create' | 'add'
    required String sigHex,
    int lamport = 0,
  }) {
    return utf8.encode(jsonEncode({
      'v': 1, 'type': 'group_invite',
      'chatId': chatId, 'lamport': lamport,
      'groupName': groupName,
      'creator': creator,
      'members': members,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'opSeq': opSeq,
      'joinedVia': joinedVia,
      'sig': sigHex,
    }));
  }

  static List<int> buildMemberAdd({
    required String chatId,
    required int lamport,
    required String target,
    required DateTime addedAt,
    required int opSeq,
    required String sigHex,
  }) {
    return utf8.encode(jsonEncode({
      'v': 1, 'type': 'member_add',
      'chatId': chatId, 'lamport': lamport,
      'target': target,
      'addedAt': addedAt.toUtc().toIso8601String(),
      'opSeq': opSeq,
      'sig': sigHex,
    }));
  }

  static List<int> buildMemberRemove({
    required String chatId,
    required int lamport,
    required String target,
    required DateTime removedAt,
    required int opSeq,
    required String sigHex,
  }) {
    return utf8.encode(jsonEncode({
      'v': 1, 'type': 'member_remove',
      'chatId': chatId, 'lamport': lamport,
      'target': target,
      'removedAt': removedAt.toUtc().toIso8601String(),
      'opSeq': opSeq,
      'sig': sigHex,
    }));
  }

  static List<int> buildMemberLeave({
    required String chatId,
    required int lamport,
    required DateTime leftAt,
    required String sigHex,
  }) {
    return utf8.encode(jsonEncode({
      'v': 1, 'type': 'member_leave',
      'chatId': chatId, 'lamport': lamport,
      'leftAt': leftAt.toUtc().toIso8601String(),
      'sig': sigHex,
    }));
  }
}

class TextEnvelope implements InnerEnvelope {
  TextEnvelope({required this.chatId, required this.lamport, required this.body});
  @override final String chatId;
  @override final int lamport;
  final String body;
}

class GroupInviteEnvelope implements InnerEnvelope {
  GroupInviteEnvelope({
    required this.chatId, required this.lamport, required this.groupName,
    required this.creator, required this.members, required this.createdAt,
    required this.opSeq, required this.joinedVia, required this.sigHex,
  });
  factory GroupInviteEnvelope._fromJson(Map<String, dynamic> raw) {
    return GroupInviteEnvelope(
      chatId: raw['chatId'] as String,
      lamport: raw['lamport'] as int,
      groupName: raw['groupName'] as String,
      creator: raw['creator'] as String,
      members: (raw['members'] as List).cast<String>(),
      createdAt: DateTime.parse(raw['createdAt'] as String),
      opSeq: raw['opSeq'] as int,
      joinedVia: raw['joinedVia'] as String,
      sigHex: raw['sig'] as String,
    );
  }
  @override final String chatId;
  @override final int lamport;
  final String groupName;
  final String creator;
  final List<String> members;
  final DateTime createdAt;
  final int opSeq;
  final String joinedVia;
  final String sigHex;
}

class MemberAddEnvelope implements InnerEnvelope {
  MemberAddEnvelope({
    required this.chatId, required this.lamport, required this.target,
    required this.addedAt, required this.opSeq, required this.sigHex,
  });
  factory MemberAddEnvelope._fromJson(Map<String, dynamic> raw) => MemberAddEnvelope(
    chatId: raw['chatId'] as String,
    lamport: raw['lamport'] as int,
    target: raw['target'] as String,
    addedAt: DateTime.parse(raw['addedAt'] as String),
    opSeq: raw['opSeq'] as int,
    sigHex: raw['sig'] as String,
  );
  @override final String chatId;
  @override final int lamport;
  final String target;
  final DateTime addedAt;
  final int opSeq;
  final String sigHex;
}

class MemberRemoveEnvelope implements InnerEnvelope {
  MemberRemoveEnvelope({
    required this.chatId, required this.lamport, required this.target,
    required this.removedAt, required this.opSeq, required this.sigHex,
  });
  factory MemberRemoveEnvelope._fromJson(Map<String, dynamic> raw) => MemberRemoveEnvelope(
    chatId: raw['chatId'] as String,
    lamport: raw['lamport'] as int,
    target: raw['target'] as String,
    removedAt: DateTime.parse(raw['removedAt'] as String),
    opSeq: raw['opSeq'] as int,
    sigHex: raw['sig'] as String,
  );
  @override final String chatId;
  @override final int lamport;
  final String target;
  final DateTime removedAt;
  final int opSeq;
  final String sigHex;
}

class MemberLeaveEnvelope implements InnerEnvelope {
  MemberLeaveEnvelope({
    required this.chatId, required this.lamport,
    required this.leftAt, required this.sigHex,
  });
  factory MemberLeaveEnvelope._fromJson(Map<String, dynamic> raw) => MemberLeaveEnvelope(
    chatId: raw['chatId'] as String,
    lamport: raw['lamport'] as int,
    leftAt: DateTime.parse(raw['leftAt'] as String),
    sigHex: raw['sig'] as String,
  );
  @override final String chatId;
  @override final int lamport;
  final DateTime leftAt;
  final String sigHex;
}
