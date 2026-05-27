import 'dart:convert';

import 'package:uuid/uuid.dart';

const _uuidGen = Uuid();

/// Canonical-bytes serializer for signature inputs.
/// - Top-level keys sorted alphabetically (recursively).
/// - No whitespace.
/// - Lists preserved in order.
/// - Optionally omit a single top-level field (for stripping `sig` before sign/verify).
///
/// **Phase 10.4.1 note:** `senderDisplayName` is also stripped from
/// canonical bytes for signed envelopes — it's informational and must not
/// affect signature canonicalization. Callers pass it as a separate kwarg
/// to the builders; signing happens over canonicalJsonBytes(body, omit: 'sig')
/// which never sees `senderDisplayName` because the signing body doesn't
/// include it in the first place.
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

  /// Optional human-readable name the sender claims for themselves. Added
  /// in Phase 10.4.1; receivers use it to populate `contacts.claimedName`
  /// for the libsignal-session sender pubkey. Informational, not
  /// authenticated beyond the libsignal binding (see spec §3.5).
  String? get senderDisplayName;

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
    final senderDisplayName = raw['senderDisplayName'] as String?;
    switch (type) {
      case 'text':
        final body = raw['body'];
        if (body is! String) throw const FormatException('text missing body');
        // Pre-Phase-2 peers may omit msgId. Generate a local UUID so the
        // typed envelope can still be constructed; dedup against the same
        // peer's retransmits is impossible (no canonical id), but no message
        // is lost. Spec §10 backwards-compat clause.
        final msgIdRaw = raw['msgId'];
        final msgId = (msgIdRaw is String && msgIdRaw.isNotEmpty)
            ? msgIdRaw
            : _uuidGen.v4();
        return TextEnvelope(
          chatId: chatId, lamport: lamport, body: body, msgId: msgId,
          senderDisplayName: senderDisplayName,
        );
      case 'group_invite':
        return GroupInviteEnvelope._fromJson(raw);
      case 'member_add':
        return MemberAddEnvelope._fromJson(raw);
      case 'member_remove':
        return MemberRemoveEnvelope._fromJson(raw);
      case 'member_leave':
        return MemberLeaveEnvelope._fromJson(raw);
      case 'delivery_receipt':
        return DeliveryReceiptEnvelope._fromJson(raw);
      default:
        throw FormatException('unknown inner type: $type');
    }
  }

  static List<int> buildText({
    required String chatId,
    required int lamport,
    required String body,
    required String msgId,
    String? senderDisplayName,
  }) {
    return utf8.encode(jsonEncode({
      'v': 1, 'type': 'text',
      'chatId': chatId, 'lamport': lamport, 'body': body,
      'msgId': msgId,
      'senderDisplayName': ?senderDisplayName,
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
    String? senderDisplayName,
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
      'senderDisplayName': ?senderDisplayName,
    }));
  }

  static List<int> buildMemberAdd({
    required String chatId,
    required int lamport,
    required String target,
    required DateTime addedAt,
    required int opSeq,
    required String sigHex,
    String? senderDisplayName,
  }) {
    return utf8.encode(jsonEncode({
      'v': 1, 'type': 'member_add',
      'chatId': chatId, 'lamport': lamport,
      'target': target,
      'addedAt': addedAt.toUtc().toIso8601String(),
      'opSeq': opSeq,
      'sig': sigHex,
      'senderDisplayName': ?senderDisplayName,
    }));
  }

  static List<int> buildMemberRemove({
    required String chatId,
    required int lamport,
    required String target,
    required DateTime removedAt,
    required int opSeq,
    required String sigHex,
    String? senderDisplayName,
  }) {
    return utf8.encode(jsonEncode({
      'v': 1, 'type': 'member_remove',
      'chatId': chatId, 'lamport': lamport,
      'target': target,
      'removedAt': removedAt.toUtc().toIso8601String(),
      'opSeq': opSeq,
      'sig': sigHex,
      'senderDisplayName': ?senderDisplayName,
    }));
  }

  static List<int> buildMemberLeave({
    required String chatId,
    required int lamport,
    required DateTime leftAt,
    required String sigHex,
    String? senderDisplayName,
  }) {
    return utf8.encode(jsonEncode({
      'v': 1, 'type': 'member_leave',
      'chatId': chatId, 'lamport': lamport,
      'leftAt': leftAt.toUtc().toIso8601String(),
      'sig': sigHex,
      'senderDisplayName': ?senderDisplayName,
    }));
  }

  static List<int> buildDeliveryReceipt({
    required String chatId,
    required List<String> msgIds,
    required ReceiptKind kind,
    required DateTime at,
    String? senderDisplayName,
  }) {
    return utf8.encode(jsonEncode({
      'v': 1, 'type': 'delivery_receipt',
      'chatId': chatId, 'lamport': 0,
      'msgIds': msgIds,
      'kind': kind == ReceiptKind.read ? 'read' : 'delivered',
      'at': at.toUtc().toIso8601String(),
      'senderDisplayName': ?senderDisplayName,
    }));
  }
}

class TextEnvelope implements InnerEnvelope {
  TextEnvelope({
    required this.chatId,
    required this.lamport,
    required this.body,
    required this.msgId,
    this.senderDisplayName,
  });
  @override final String chatId;
  @override final int lamport;
  final String body;
  final String msgId;
  @override final String? senderDisplayName;
}

class GroupInviteEnvelope implements InnerEnvelope {
  GroupInviteEnvelope({
    required this.chatId, required this.lamport, required this.groupName,
    required this.creator, required this.members, required this.createdAt,
    required this.opSeq, required this.joinedVia, required this.sigHex,
    this.senderDisplayName,
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
      senderDisplayName: raw['senderDisplayName'] as String?,
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
  @override final String? senderDisplayName;
}

class MemberAddEnvelope implements InnerEnvelope {
  MemberAddEnvelope({
    required this.chatId, required this.lamport, required this.target,
    required this.addedAt, required this.opSeq, required this.sigHex,
    this.senderDisplayName,
  });
  factory MemberAddEnvelope._fromJson(Map<String, dynamic> raw) => MemberAddEnvelope(
    chatId: raw['chatId'] as String,
    lamport: raw['lamport'] as int,
    target: raw['target'] as String,
    addedAt: DateTime.parse(raw['addedAt'] as String),
    opSeq: raw['opSeq'] as int,
    sigHex: raw['sig'] as String,
    senderDisplayName: raw['senderDisplayName'] as String?,
  );
  @override final String chatId;
  @override final int lamport;
  final String target;
  final DateTime addedAt;
  final int opSeq;
  final String sigHex;
  @override final String? senderDisplayName;
}

class MemberRemoveEnvelope implements InnerEnvelope {
  MemberRemoveEnvelope({
    required this.chatId, required this.lamport, required this.target,
    required this.removedAt, required this.opSeq, required this.sigHex,
    this.senderDisplayName,
  });
  factory MemberRemoveEnvelope._fromJson(Map<String, dynamic> raw) => MemberRemoveEnvelope(
    chatId: raw['chatId'] as String,
    lamport: raw['lamport'] as int,
    target: raw['target'] as String,
    removedAt: DateTime.parse(raw['removedAt'] as String),
    opSeq: raw['opSeq'] as int,
    sigHex: raw['sig'] as String,
    senderDisplayName: raw['senderDisplayName'] as String?,
  );
  @override final String chatId;
  @override final int lamport;
  final String target;
  final DateTime removedAt;
  final int opSeq;
  final String sigHex;
  @override final String? senderDisplayName;
}

class MemberLeaveEnvelope implements InnerEnvelope {
  MemberLeaveEnvelope({
    required this.chatId, required this.lamport,
    required this.leftAt, required this.sigHex,
    this.senderDisplayName,
  });
  factory MemberLeaveEnvelope._fromJson(Map<String, dynamic> raw) => MemberLeaveEnvelope(
    chatId: raw['chatId'] as String,
    lamport: raw['lamport'] as int,
    leftAt: DateTime.parse(raw['leftAt'] as String),
    sigHex: raw['sig'] as String,
    senderDisplayName: raw['senderDisplayName'] as String?,
  );
  @override final String chatId;
  @override final int lamport;
  final DateTime leftAt;
  final String sigHex;
  @override final String? senderDisplayName;
}

enum ReceiptKind { delivered, read }

class DeliveryReceiptEnvelope implements InnerEnvelope {
  DeliveryReceiptEnvelope({
    required this.chatId,
    required this.msgIds,
    required this.kind,
    required this.at,
    this.senderDisplayName,
  });

  factory DeliveryReceiptEnvelope._fromJson(Map<String, dynamic> raw) {
    final msgIds = (raw['msgIds'] as List?)?.cast<String>() ?? const [];
    if (msgIds.isEmpty) {
      throw const FormatException('delivery_receipt missing msgIds');
    }
    final kindStr = raw['kind'];
    final kind = switch (kindStr) {
      'delivered' => ReceiptKind.delivered,
      'read' => ReceiptKind.read,
      _ => throw FormatException('unknown receipt kind: $kindStr'),
    };
    final atStr = raw['at'];
    if (atStr is! String) {
      throw const FormatException('delivery_receipt missing at');
    }
    return DeliveryReceiptEnvelope(
      chatId: raw['chatId'] as String,
      msgIds: msgIds,
      kind: kind,
      at: DateTime.parse(atStr),
      senderDisplayName: raw['senderDisplayName'] as String?,
    );
  }

  @override final String chatId;
  // Receipts don't advance the chat's lamport clock — they're metadata.
  @override int get lamport => 0;
  final List<String> msgIds;
  final ReceiptKind kind;
  final DateTime at;
  @override final String? senderDisplayName;
}
