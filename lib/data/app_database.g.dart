// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ContactsTable extends Contacts with TableInfo<$ContactsTable, Contact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pubkeyHexMeta = const VerificationMeta(
    'pubkeyHex',
  );
  @override
  late final GeneratedColumn<String> pubkeyHex = GeneratedColumn<String>(
    'pubkey_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _claimedNameMeta = const VerificationMeta(
    'claimedName',
  );
  @override
  late final GeneratedColumn<String> claimedName = GeneratedColumn<String>(
    'claimed_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    pubkeyHex,
    addedAt,
    displayName,
    claimedName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Contact> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pubkey_hex')) {
      context.handle(
        _pubkeyHexMeta,
        pubkeyHex.isAcceptableOrUnknown(data['pubkey_hex']!, _pubkeyHexMeta),
      );
    } else if (isInserting) {
      context.missing(_pubkeyHexMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('claimed_name')) {
      context.handle(
        _claimedNameMeta,
        claimedName.isAcceptableOrUnknown(
          data['claimed_name']!,
          _claimedNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pubkeyHex};
  @override
  Contact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Contact(
      pubkeyHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pubkey_hex'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      claimedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}claimed_name'],
      ),
    );
  }

  @override
  $ContactsTable createAlias(String alias) {
    return $ContactsTable(attachedDatabase, alias);
  }
}

class Contact extends DataClass implements Insertable<Contact> {
  final String pubkeyHex;
  final DateTime addedAt;
  final String? displayName;
  final String? claimedName;
  const Contact({
    required this.pubkeyHex,
    required this.addedAt,
    this.displayName,
    this.claimedName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pubkey_hex'] = Variable<String>(pubkeyHex);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || claimedName != null) {
      map['claimed_name'] = Variable<String>(claimedName);
    }
    return map;
  }

  ContactsCompanion toCompanion(bool nullToAbsent) {
    return ContactsCompanion(
      pubkeyHex: Value(pubkeyHex),
      addedAt: Value(addedAt),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      claimedName: claimedName == null && nullToAbsent
          ? const Value.absent()
          : Value(claimedName),
    );
  }

  factory Contact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Contact(
      pubkeyHex: serializer.fromJson<String>(json['pubkeyHex']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      claimedName: serializer.fromJson<String?>(json['claimedName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pubkeyHex': serializer.toJson<String>(pubkeyHex),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'displayName': serializer.toJson<String?>(displayName),
      'claimedName': serializer.toJson<String?>(claimedName),
    };
  }

  Contact copyWith({
    String? pubkeyHex,
    DateTime? addedAt,
    Value<String?> displayName = const Value.absent(),
    Value<String?> claimedName = const Value.absent(),
  }) => Contact(
    pubkeyHex: pubkeyHex ?? this.pubkeyHex,
    addedAt: addedAt ?? this.addedAt,
    displayName: displayName.present ? displayName.value : this.displayName,
    claimedName: claimedName.present ? claimedName.value : this.claimedName,
  );
  Contact copyWithCompanion(ContactsCompanion data) {
    return Contact(
      pubkeyHex: data.pubkeyHex.present ? data.pubkeyHex.value : this.pubkeyHex,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      claimedName: data.claimedName.present
          ? data.claimedName.value
          : this.claimedName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Contact(')
          ..write('pubkeyHex: $pubkeyHex, ')
          ..write('addedAt: $addedAt, ')
          ..write('displayName: $displayName, ')
          ..write('claimedName: $claimedName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pubkeyHex, addedAt, displayName, claimedName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Contact &&
          other.pubkeyHex == this.pubkeyHex &&
          other.addedAt == this.addedAt &&
          other.displayName == this.displayName &&
          other.claimedName == this.claimedName);
}

class ContactsCompanion extends UpdateCompanion<Contact> {
  final Value<String> pubkeyHex;
  final Value<DateTime> addedAt;
  final Value<String?> displayName;
  final Value<String?> claimedName;
  final Value<int> rowid;
  const ContactsCompanion({
    this.pubkeyHex = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.displayName = const Value.absent(),
    this.claimedName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsCompanion.insert({
    required String pubkeyHex,
    required DateTime addedAt,
    this.displayName = const Value.absent(),
    this.claimedName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : pubkeyHex = Value(pubkeyHex),
       addedAt = Value(addedAt);
  static Insertable<Contact> custom({
    Expression<String>? pubkeyHex,
    Expression<DateTime>? addedAt,
    Expression<String>? displayName,
    Expression<String>? claimedName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pubkeyHex != null) 'pubkey_hex': pubkeyHex,
      if (addedAt != null) 'added_at': addedAt,
      if (displayName != null) 'display_name': displayName,
      if (claimedName != null) 'claimed_name': claimedName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsCompanion copyWith({
    Value<String>? pubkeyHex,
    Value<DateTime>? addedAt,
    Value<String?>? displayName,
    Value<String?>? claimedName,
    Value<int>? rowid,
  }) {
    return ContactsCompanion(
      pubkeyHex: pubkeyHex ?? this.pubkeyHex,
      addedAt: addedAt ?? this.addedAt,
      displayName: displayName ?? this.displayName,
      claimedName: claimedName ?? this.claimedName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pubkeyHex.present) {
      map['pubkey_hex'] = Variable<String>(pubkeyHex.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (claimedName.present) {
      map['claimed_name'] = Variable<String>(claimedName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsCompanion(')
          ..write('pubkeyHex: $pubkeyHex, ')
          ..write('addedAt: $addedAt, ')
          ..write('displayName: $displayName, ')
          ..write('claimedName: $claimedName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatsTable extends Chats with TableInfo<$ChatsTable, Chat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('direct'),
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creatorPubkeyHexMeta = const VerificationMeta(
    'creatorPubkeyHex',
  );
  @override
  late final GeneratedColumn<String> creatorPubkeyHex = GeneratedColumn<String>(
    'creator_pubkey_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastMessageAtMeta = const VerificationMeta(
    'lastMessageAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastMessageAt =
      GeneratedColumn<DateTime>(
        'last_message_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastMessagePreviewMeta =
      const VerificationMeta('lastMessagePreview');
  @override
  late final GeneratedColumn<String> lastMessagePreview =
      GeneratedColumn<String>(
        'last_message_preview',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _leftAtMeta = const VerificationMeta('leftAt');
  @override
  late final GeneratedColumn<DateTime> leftAt = GeneratedColumn<DateTime>(
    'left_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastOpSeqMeta = const VerificationMeta(
    'lastOpSeq',
  );
  @override
  late final GeneratedColumn<int> lastOpSeq = GeneratedColumn<int>(
    'last_op_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    chatId,
    kind,
    groupName,
    creatorPubkeyHex,
    createdAt,
    lastMessageAt,
    lastMessagePreview,
    leftAt,
    lastOpSeq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chats';
  @override
  VerificationContext validateIntegrity(
    Insertable<Chat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    }
    if (data.containsKey('creator_pubkey_hex')) {
      context.handle(
        _creatorPubkeyHexMeta,
        creatorPubkeyHex.isAcceptableOrUnknown(
          data['creator_pubkey_hex']!,
          _creatorPubkeyHexMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_message_at')) {
      context.handle(
        _lastMessageAtMeta,
        lastMessageAt.isAcceptableOrUnknown(
          data['last_message_at']!,
          _lastMessageAtMeta,
        ),
      );
    }
    if (data.containsKey('last_message_preview')) {
      context.handle(
        _lastMessagePreviewMeta,
        lastMessagePreview.isAcceptableOrUnknown(
          data['last_message_preview']!,
          _lastMessagePreviewMeta,
        ),
      );
    }
    if (data.containsKey('left_at')) {
      context.handle(
        _leftAtMeta,
        leftAt.isAcceptableOrUnknown(data['left_at']!, _leftAtMeta),
      );
    }
    if (data.containsKey('last_op_seq')) {
      context.handle(
        _lastOpSeqMeta,
        lastOpSeq.isAcceptableOrUnknown(data['last_op_seq']!, _lastOpSeqMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chatId};
  @override
  Chat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chat(
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      ),
      creatorPubkeyHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creator_pubkey_hex'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastMessageAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_message_at'],
      ),
      lastMessagePreview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_preview'],
      ),
      leftAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}left_at'],
      ),
      lastOpSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_op_seq'],
      )!,
    );
  }

  @override
  $ChatsTable createAlias(String alias) {
    return $ChatsTable(attachedDatabase, alias);
  }
}

class Chat extends DataClass implements Insertable<Chat> {
  final String chatId;
  final String kind;
  final String? groupName;
  final String? creatorPubkeyHex;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final DateTime? leftAt;
  final int lastOpSeq;
  const Chat({
    required this.chatId,
    required this.kind,
    this.groupName,
    this.creatorPubkeyHex,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.leftAt,
    required this.lastOpSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chat_id'] = Variable<String>(chatId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    if (!nullToAbsent || creatorPubkeyHex != null) {
      map['creator_pubkey_hex'] = Variable<String>(creatorPubkeyHex);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastMessageAt != null) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt);
    }
    if (!nullToAbsent || lastMessagePreview != null) {
      map['last_message_preview'] = Variable<String>(lastMessagePreview);
    }
    if (!nullToAbsent || leftAt != null) {
      map['left_at'] = Variable<DateTime>(leftAt);
    }
    map['last_op_seq'] = Variable<int>(lastOpSeq);
    return map;
  }

  ChatsCompanion toCompanion(bool nullToAbsent) {
    return ChatsCompanion(
      chatId: Value(chatId),
      kind: Value(kind),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
      creatorPubkeyHex: creatorPubkeyHex == null && nullToAbsent
          ? const Value.absent()
          : Value(creatorPubkeyHex),
      createdAt: Value(createdAt),
      lastMessageAt: lastMessageAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageAt),
      lastMessagePreview: lastMessagePreview == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessagePreview),
      leftAt: leftAt == null && nullToAbsent
          ? const Value.absent()
          : Value(leftAt),
      lastOpSeq: Value(lastOpSeq),
    );
  }

  factory Chat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chat(
      chatId: serializer.fromJson<String>(json['chatId']),
      kind: serializer.fromJson<String>(json['kind']),
      groupName: serializer.fromJson<String?>(json['groupName']),
      creatorPubkeyHex: serializer.fromJson<String?>(json['creatorPubkeyHex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastMessageAt: serializer.fromJson<DateTime?>(json['lastMessageAt']),
      lastMessagePreview: serializer.fromJson<String?>(
        json['lastMessagePreview'],
      ),
      leftAt: serializer.fromJson<DateTime?>(json['leftAt']),
      lastOpSeq: serializer.fromJson<int>(json['lastOpSeq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chatId': serializer.toJson<String>(chatId),
      'kind': serializer.toJson<String>(kind),
      'groupName': serializer.toJson<String?>(groupName),
      'creatorPubkeyHex': serializer.toJson<String?>(creatorPubkeyHex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastMessageAt': serializer.toJson<DateTime?>(lastMessageAt),
      'lastMessagePreview': serializer.toJson<String?>(lastMessagePreview),
      'leftAt': serializer.toJson<DateTime?>(leftAt),
      'lastOpSeq': serializer.toJson<int>(lastOpSeq),
    };
  }

  Chat copyWith({
    String? chatId,
    String? kind,
    Value<String?> groupName = const Value.absent(),
    Value<String?> creatorPubkeyHex = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> lastMessageAt = const Value.absent(),
    Value<String?> lastMessagePreview = const Value.absent(),
    Value<DateTime?> leftAt = const Value.absent(),
    int? lastOpSeq,
  }) => Chat(
    chatId: chatId ?? this.chatId,
    kind: kind ?? this.kind,
    groupName: groupName.present ? groupName.value : this.groupName,
    creatorPubkeyHex: creatorPubkeyHex.present
        ? creatorPubkeyHex.value
        : this.creatorPubkeyHex,
    createdAt: createdAt ?? this.createdAt,
    lastMessageAt: lastMessageAt.present
        ? lastMessageAt.value
        : this.lastMessageAt,
    lastMessagePreview: lastMessagePreview.present
        ? lastMessagePreview.value
        : this.lastMessagePreview,
    leftAt: leftAt.present ? leftAt.value : this.leftAt,
    lastOpSeq: lastOpSeq ?? this.lastOpSeq,
  );
  Chat copyWithCompanion(ChatsCompanion data) {
    return Chat(
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      kind: data.kind.present ? data.kind.value : this.kind,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      creatorPubkeyHex: data.creatorPubkeyHex.present
          ? data.creatorPubkeyHex.value
          : this.creatorPubkeyHex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
      lastMessagePreview: data.lastMessagePreview.present
          ? data.lastMessagePreview.value
          : this.lastMessagePreview,
      leftAt: data.leftAt.present ? data.leftAt.value : this.leftAt,
      lastOpSeq: data.lastOpSeq.present ? data.lastOpSeq.value : this.lastOpSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chat(')
          ..write('chatId: $chatId, ')
          ..write('kind: $kind, ')
          ..write('groupName: $groupName, ')
          ..write('creatorPubkeyHex: $creatorPubkeyHex, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('lastMessagePreview: $lastMessagePreview, ')
          ..write('leftAt: $leftAt, ')
          ..write('lastOpSeq: $lastOpSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    chatId,
    kind,
    groupName,
    creatorPubkeyHex,
    createdAt,
    lastMessageAt,
    lastMessagePreview,
    leftAt,
    lastOpSeq,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chat &&
          other.chatId == this.chatId &&
          other.kind == this.kind &&
          other.groupName == this.groupName &&
          other.creatorPubkeyHex == this.creatorPubkeyHex &&
          other.createdAt == this.createdAt &&
          other.lastMessageAt == this.lastMessageAt &&
          other.lastMessagePreview == this.lastMessagePreview &&
          other.leftAt == this.leftAt &&
          other.lastOpSeq == this.lastOpSeq);
}

class ChatsCompanion extends UpdateCompanion<Chat> {
  final Value<String> chatId;
  final Value<String> kind;
  final Value<String?> groupName;
  final Value<String?> creatorPubkeyHex;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastMessageAt;
  final Value<String?> lastMessagePreview;
  final Value<DateTime?> leftAt;
  final Value<int> lastOpSeq;
  final Value<int> rowid;
  const ChatsCompanion({
    this.chatId = const Value.absent(),
    this.kind = const Value.absent(),
    this.groupName = const Value.absent(),
    this.creatorPubkeyHex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.lastMessagePreview = const Value.absent(),
    this.leftAt = const Value.absent(),
    this.lastOpSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatsCompanion.insert({
    required String chatId,
    this.kind = const Value.absent(),
    this.groupName = const Value.absent(),
    this.creatorPubkeyHex = const Value.absent(),
    required DateTime createdAt,
    this.lastMessageAt = const Value.absent(),
    this.lastMessagePreview = const Value.absent(),
    this.leftAt = const Value.absent(),
    this.lastOpSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : chatId = Value(chatId),
       createdAt = Value(createdAt);
  static Insertable<Chat> custom({
    Expression<String>? chatId,
    Expression<String>? kind,
    Expression<String>? groupName,
    Expression<String>? creatorPubkeyHex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastMessageAt,
    Expression<String>? lastMessagePreview,
    Expression<DateTime>? leftAt,
    Expression<int>? lastOpSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chatId != null) 'chat_id': chatId,
      if (kind != null) 'kind': kind,
      if (groupName != null) 'group_name': groupName,
      if (creatorPubkeyHex != null) 'creator_pubkey_hex': creatorPubkeyHex,
      if (createdAt != null) 'created_at': createdAt,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt,
      if (lastMessagePreview != null)
        'last_message_preview': lastMessagePreview,
      if (leftAt != null) 'left_at': leftAt,
      if (lastOpSeq != null) 'last_op_seq': lastOpSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatsCompanion copyWith({
    Value<String>? chatId,
    Value<String>? kind,
    Value<String?>? groupName,
    Value<String?>? creatorPubkeyHex,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastMessageAt,
    Value<String?>? lastMessagePreview,
    Value<DateTime?>? leftAt,
    Value<int>? lastOpSeq,
    Value<int>? rowid,
  }) {
    return ChatsCompanion(
      chatId: chatId ?? this.chatId,
      kind: kind ?? this.kind,
      groupName: groupName ?? this.groupName,
      creatorPubkeyHex: creatorPubkeyHex ?? this.creatorPubkeyHex,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      leftAt: leftAt ?? this.leftAt,
      lastOpSeq: lastOpSeq ?? this.lastOpSeq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (creatorPubkeyHex.present) {
      map['creator_pubkey_hex'] = Variable<String>(creatorPubkeyHex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastMessageAt.present) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt.value);
    }
    if (lastMessagePreview.present) {
      map['last_message_preview'] = Variable<String>(lastMessagePreview.value);
    }
    if (leftAt.present) {
      map['left_at'] = Variable<DateTime>(leftAt.value);
    }
    if (lastOpSeq.present) {
      map['last_op_seq'] = Variable<int>(lastOpSeq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatsCompanion(')
          ..write('chatId: $chatId, ')
          ..write('kind: $kind, ')
          ..write('groupName: $groupName, ')
          ..write('creatorPubkeyHex: $creatorPubkeyHex, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('lastMessagePreview: $lastMessagePreview, ')
          ..write('leftAt: $leftAt, ')
          ..write('lastOpSeq: $lastOpSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderPubkeyHexMeta = const VerificationMeta(
    'senderPubkeyHex',
  );
  @override
  late final GeneratedColumn<String> senderPubkeyHex = GeneratedColumn<String>(
    'sender_pubkey_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lamportMeta = const VerificationMeta(
    'lamport',
  );
  @override
  late final GeneratedColumn<int> lamport = GeneratedColumn<int>(
    'lamport',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<DateTime> sentAt = GeneratedColumn<DateTime>(
    'sent_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DeliveryState, int>
  deliveryState = GeneratedColumn<int>(
    'delivery_state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  ).withConverter<DeliveryState>($MessagesTable.$converterdeliveryState);
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chatId,
    senderPubkeyHex,
    body,
    lamport,
    sentAt,
    receivedAt,
    kind,
    deliveryState,
    readAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('sender_pubkey_hex')) {
      context.handle(
        _senderPubkeyHexMeta,
        senderPubkeyHex.isAcceptableOrUnknown(
          data['sender_pubkey_hex']!,
          _senderPubkeyHexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_senderPubkeyHexMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('lamport')) {
      context.handle(
        _lamportMeta,
        lamport.isAcceptableOrUnknown(data['lamport']!, _lamportMeta),
      );
    } else if (isInserting) {
      context.missing(_lamportMeta);
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    } else if (isInserting) {
      context.missing(_sentAtMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_id'],
      )!,
      senderPubkeyHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_pubkey_hex'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      lamport: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lamport'],
      )!,
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}sent_at'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      deliveryState: $MessagesTable.$converterdeliveryState.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}delivery_state'],
        )!,
      ),
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_at'],
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DeliveryState, int, int> $converterdeliveryState =
      const EnumIndexConverter<DeliveryState>(DeliveryState.values);
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String chatId;
  final String senderPubkeyHex;
  final String body;
  final int lamport;
  final DateTime sentAt;
  final DateTime? receivedAt;
  final String kind;
  final DeliveryState deliveryState;
  final DateTime? readAt;
  const Message({
    required this.id,
    required this.chatId,
    required this.senderPubkeyHex,
    required this.body,
    required this.lamport,
    required this.sentAt,
    this.receivedAt,
    required this.kind,
    required this.deliveryState,
    this.readAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['chat_id'] = Variable<String>(chatId);
    map['sender_pubkey_hex'] = Variable<String>(senderPubkeyHex);
    map['body'] = Variable<String>(body);
    map['lamport'] = Variable<int>(lamport);
    map['sent_at'] = Variable<DateTime>(sentAt);
    if (!nullToAbsent || receivedAt != null) {
      map['received_at'] = Variable<DateTime>(receivedAt);
    }
    map['kind'] = Variable<String>(kind);
    {
      map['delivery_state'] = Variable<int>(
        $MessagesTable.$converterdeliveryState.toSql(deliveryState),
      );
    }
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<DateTime>(readAt);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      chatId: Value(chatId),
      senderPubkeyHex: Value(senderPubkeyHex),
      body: Value(body),
      lamport: Value(lamport),
      sentAt: Value(sentAt),
      receivedAt: receivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(receivedAt),
      kind: Value(kind),
      deliveryState: Value(deliveryState),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      chatId: serializer.fromJson<String>(json['chatId']),
      senderPubkeyHex: serializer.fromJson<String>(json['senderPubkeyHex']),
      body: serializer.fromJson<String>(json['body']),
      lamport: serializer.fromJson<int>(json['lamport']),
      sentAt: serializer.fromJson<DateTime>(json['sentAt']),
      receivedAt: serializer.fromJson<DateTime?>(json['receivedAt']),
      kind: serializer.fromJson<String>(json['kind']),
      deliveryState: $MessagesTable.$converterdeliveryState.fromJson(
        serializer.fromJson<int>(json['deliveryState']),
      ),
      readAt: serializer.fromJson<DateTime?>(json['readAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'chatId': serializer.toJson<String>(chatId),
      'senderPubkeyHex': serializer.toJson<String>(senderPubkeyHex),
      'body': serializer.toJson<String>(body),
      'lamport': serializer.toJson<int>(lamport),
      'sentAt': serializer.toJson<DateTime>(sentAt),
      'receivedAt': serializer.toJson<DateTime?>(receivedAt),
      'kind': serializer.toJson<String>(kind),
      'deliveryState': serializer.toJson<int>(
        $MessagesTable.$converterdeliveryState.toJson(deliveryState),
      ),
      'readAt': serializer.toJson<DateTime?>(readAt),
    };
  }

  Message copyWith({
    String? id,
    String? chatId,
    String? senderPubkeyHex,
    String? body,
    int? lamport,
    DateTime? sentAt,
    Value<DateTime?> receivedAt = const Value.absent(),
    String? kind,
    DeliveryState? deliveryState,
    Value<DateTime?> readAt = const Value.absent(),
  }) => Message(
    id: id ?? this.id,
    chatId: chatId ?? this.chatId,
    senderPubkeyHex: senderPubkeyHex ?? this.senderPubkeyHex,
    body: body ?? this.body,
    lamport: lamport ?? this.lamport,
    sentAt: sentAt ?? this.sentAt,
    receivedAt: receivedAt.present ? receivedAt.value : this.receivedAt,
    kind: kind ?? this.kind,
    deliveryState: deliveryState ?? this.deliveryState,
    readAt: readAt.present ? readAt.value : this.readAt,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      senderPubkeyHex: data.senderPubkeyHex.present
          ? data.senderPubkeyHex.value
          : this.senderPubkeyHex,
      body: data.body.present ? data.body.value : this.body,
      lamport: data.lamport.present ? data.lamport.value : this.lamport,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      kind: data.kind.present ? data.kind.value : this.kind,
      deliveryState: data.deliveryState.present
          ? data.deliveryState.value
          : this.deliveryState,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('senderPubkeyHex: $senderPubkeyHex, ')
          ..write('body: $body, ')
          ..write('lamport: $lamport, ')
          ..write('sentAt: $sentAt, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('kind: $kind, ')
          ..write('deliveryState: $deliveryState, ')
          ..write('readAt: $readAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    chatId,
    senderPubkeyHex,
    body,
    lamport,
    sentAt,
    receivedAt,
    kind,
    deliveryState,
    readAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.chatId == this.chatId &&
          other.senderPubkeyHex == this.senderPubkeyHex &&
          other.body == this.body &&
          other.lamport == this.lamport &&
          other.sentAt == this.sentAt &&
          other.receivedAt == this.receivedAt &&
          other.kind == this.kind &&
          other.deliveryState == this.deliveryState &&
          other.readAt == this.readAt);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> chatId;
  final Value<String> senderPubkeyHex;
  final Value<String> body;
  final Value<int> lamport;
  final Value<DateTime> sentAt;
  final Value<DateTime?> receivedAt;
  final Value<String> kind;
  final Value<DeliveryState> deliveryState;
  final Value<DateTime?> readAt;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.senderPubkeyHex = const Value.absent(),
    this.body = const Value.absent(),
    this.lamport = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.kind = const Value.absent(),
    this.deliveryState = const Value.absent(),
    this.readAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String chatId,
    required String senderPubkeyHex,
    required String body,
    required int lamport,
    required DateTime sentAt,
    this.receivedAt = const Value.absent(),
    this.kind = const Value.absent(),
    this.deliveryState = const Value.absent(),
    this.readAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       chatId = Value(chatId),
       senderPubkeyHex = Value(senderPubkeyHex),
       body = Value(body),
       lamport = Value(lamport),
       sentAt = Value(sentAt);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? chatId,
    Expression<String>? senderPubkeyHex,
    Expression<String>? body,
    Expression<int>? lamport,
    Expression<DateTime>? sentAt,
    Expression<DateTime>? receivedAt,
    Expression<String>? kind,
    Expression<int>? deliveryState,
    Expression<DateTime>? readAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chatId != null) 'chat_id': chatId,
      if (senderPubkeyHex != null) 'sender_pubkey_hex': senderPubkeyHex,
      if (body != null) 'body': body,
      if (lamport != null) 'lamport': lamport,
      if (sentAt != null) 'sent_at': sentAt,
      if (receivedAt != null) 'received_at': receivedAt,
      if (kind != null) 'kind': kind,
      if (deliveryState != null) 'delivery_state': deliveryState,
      if (readAt != null) 'read_at': readAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? chatId,
    Value<String>? senderPubkeyHex,
    Value<String>? body,
    Value<int>? lamport,
    Value<DateTime>? sentAt,
    Value<DateTime?>? receivedAt,
    Value<String>? kind,
    Value<DeliveryState>? deliveryState,
    Value<DateTime?>? readAt,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderPubkeyHex: senderPubkeyHex ?? this.senderPubkeyHex,
      body: body ?? this.body,
      lamport: lamport ?? this.lamport,
      sentAt: sentAt ?? this.sentAt,
      receivedAt: receivedAt ?? this.receivedAt,
      kind: kind ?? this.kind,
      deliveryState: deliveryState ?? this.deliveryState,
      readAt: readAt ?? this.readAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (senderPubkeyHex.present) {
      map['sender_pubkey_hex'] = Variable<String>(senderPubkeyHex.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (lamport.present) {
      map['lamport'] = Variable<int>(lamport.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<DateTime>(sentAt.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (deliveryState.present) {
      map['delivery_state'] = Variable<int>(
        $MessagesTable.$converterdeliveryState.toSql(deliveryState.value),
      );
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('senderPubkeyHex: $senderPubkeyHex, ')
          ..write('body: $body, ')
          ..write('lamport: $lamport, ')
          ..write('sentAt: $sentAt, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('kind: $kind, ')
          ..write('deliveryState: $deliveryState, ')
          ..write('readAt: $readAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LamportSeqTable extends LamportSeq
    with TableInfo<$LamportSeqTable, LamportSeqData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LamportSeqTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [chatId, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lamport_seq';
  @override
  VerificationContext validateIntegrity(
    Insertable<LamportSeqData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chatId};
  @override
  LamportSeqData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LamportSeqData(
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $LamportSeqTable createAlias(String alias) {
    return $LamportSeqTable(attachedDatabase, alias);
  }
}

class LamportSeqData extends DataClass implements Insertable<LamportSeqData> {
  final String chatId;
  final int value;
  const LamportSeqData({required this.chatId, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chat_id'] = Variable<String>(chatId);
    map['value'] = Variable<int>(value);
    return map;
  }

  LamportSeqCompanion toCompanion(bool nullToAbsent) {
    return LamportSeqCompanion(chatId: Value(chatId), value: Value(value));
  }

  factory LamportSeqData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LamportSeqData(
      chatId: serializer.fromJson<String>(json['chatId']),
      value: serializer.fromJson<int>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chatId': serializer.toJson<String>(chatId),
      'value': serializer.toJson<int>(value),
    };
  }

  LamportSeqData copyWith({String? chatId, int? value}) =>
      LamportSeqData(chatId: chatId ?? this.chatId, value: value ?? this.value);
  LamportSeqData copyWithCompanion(LamportSeqCompanion data) {
    return LamportSeqData(
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LamportSeqData(')
          ..write('chatId: $chatId, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chatId, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LamportSeqData &&
          other.chatId == this.chatId &&
          other.value == this.value);
}

class LamportSeqCompanion extends UpdateCompanion<LamportSeqData> {
  final Value<String> chatId;
  final Value<int> value;
  final Value<int> rowid;
  const LamportSeqCompanion({
    this.chatId = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LamportSeqCompanion.insert({
    required String chatId,
    required int value,
    this.rowid = const Value.absent(),
  }) : chatId = Value(chatId),
       value = Value(value);
  static Insertable<LamportSeqData> custom({
    Expression<String>? chatId,
    Expression<int>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chatId != null) 'chat_id': chatId,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LamportSeqCompanion copyWith({
    Value<String>? chatId,
    Value<int>? value,
    Value<int>? rowid,
  }) {
    return LamportSeqCompanion(
      chatId: chatId ?? this.chatId,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LamportSeqCompanion(')
          ..write('chatId: $chatId, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupMembersTable extends GroupMembers
    with TableInfo<$GroupMembersTable, GroupMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberPubkeyHexMeta = const VerificationMeta(
    'memberPubkeyHex',
  );
  @override
  late final GeneratedColumn<String> memberPubkeyHex = GeneratedColumn<String>(
    'member_pubkey_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedByPubkeyHexMeta = const VerificationMeta(
    'addedByPubkeyHex',
  );
  @override
  late final GeneratedColumn<String> addedByPubkeyHex = GeneratedColumn<String>(
    'added_by_pubkey_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _removedAtMeta = const VerificationMeta(
    'removedAt',
  );
  @override
  late final GeneratedColumn<DateTime> removedAt = GeneratedColumn<DateTime>(
    'removed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    chatId,
    memberPubkeyHex,
    addedAt,
    addedByPubkeyHex,
    removedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('member_pubkey_hex')) {
      context.handle(
        _memberPubkeyHexMeta,
        memberPubkeyHex.isAcceptableOrUnknown(
          data['member_pubkey_hex']!,
          _memberPubkeyHexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_memberPubkeyHexMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('added_by_pubkey_hex')) {
      context.handle(
        _addedByPubkeyHexMeta,
        addedByPubkeyHex.isAcceptableOrUnknown(
          data['added_by_pubkey_hex']!,
          _addedByPubkeyHexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addedByPubkeyHexMeta);
    }
    if (data.containsKey('removed_at')) {
      context.handle(
        _removedAtMeta,
        removedAt.isAcceptableOrUnknown(data['removed_at']!, _removedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chatId, memberPubkeyHex};
  @override
  GroupMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupMember(
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_id'],
      )!,
      memberPubkeyHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_pubkey_hex'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      addedByPubkeyHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_by_pubkey_hex'],
      )!,
      removedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}removed_at'],
      ),
    );
  }

  @override
  $GroupMembersTable createAlias(String alias) {
    return $GroupMembersTable(attachedDatabase, alias);
  }
}

class GroupMember extends DataClass implements Insertable<GroupMember> {
  final String chatId;
  final String memberPubkeyHex;
  final DateTime addedAt;
  final String addedByPubkeyHex;
  final DateTime? removedAt;
  const GroupMember({
    required this.chatId,
    required this.memberPubkeyHex,
    required this.addedAt,
    required this.addedByPubkeyHex,
    this.removedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chat_id'] = Variable<String>(chatId);
    map['member_pubkey_hex'] = Variable<String>(memberPubkeyHex);
    map['added_at'] = Variable<DateTime>(addedAt);
    map['added_by_pubkey_hex'] = Variable<String>(addedByPubkeyHex);
    if (!nullToAbsent || removedAt != null) {
      map['removed_at'] = Variable<DateTime>(removedAt);
    }
    return map;
  }

  GroupMembersCompanion toCompanion(bool nullToAbsent) {
    return GroupMembersCompanion(
      chatId: Value(chatId),
      memberPubkeyHex: Value(memberPubkeyHex),
      addedAt: Value(addedAt),
      addedByPubkeyHex: Value(addedByPubkeyHex),
      removedAt: removedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(removedAt),
    );
  }

  factory GroupMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupMember(
      chatId: serializer.fromJson<String>(json['chatId']),
      memberPubkeyHex: serializer.fromJson<String>(json['memberPubkeyHex']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      addedByPubkeyHex: serializer.fromJson<String>(json['addedByPubkeyHex']),
      removedAt: serializer.fromJson<DateTime?>(json['removedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chatId': serializer.toJson<String>(chatId),
      'memberPubkeyHex': serializer.toJson<String>(memberPubkeyHex),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'addedByPubkeyHex': serializer.toJson<String>(addedByPubkeyHex),
      'removedAt': serializer.toJson<DateTime?>(removedAt),
    };
  }

  GroupMember copyWith({
    String? chatId,
    String? memberPubkeyHex,
    DateTime? addedAt,
    String? addedByPubkeyHex,
    Value<DateTime?> removedAt = const Value.absent(),
  }) => GroupMember(
    chatId: chatId ?? this.chatId,
    memberPubkeyHex: memberPubkeyHex ?? this.memberPubkeyHex,
    addedAt: addedAt ?? this.addedAt,
    addedByPubkeyHex: addedByPubkeyHex ?? this.addedByPubkeyHex,
    removedAt: removedAt.present ? removedAt.value : this.removedAt,
  );
  GroupMember copyWithCompanion(GroupMembersCompanion data) {
    return GroupMember(
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      memberPubkeyHex: data.memberPubkeyHex.present
          ? data.memberPubkeyHex.value
          : this.memberPubkeyHex,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      addedByPubkeyHex: data.addedByPubkeyHex.present
          ? data.addedByPubkeyHex.value
          : this.addedByPubkeyHex,
      removedAt: data.removedAt.present ? data.removedAt.value : this.removedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupMember(')
          ..write('chatId: $chatId, ')
          ..write('memberPubkeyHex: $memberPubkeyHex, ')
          ..write('addedAt: $addedAt, ')
          ..write('addedByPubkeyHex: $addedByPubkeyHex, ')
          ..write('removedAt: $removedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    chatId,
    memberPubkeyHex,
    addedAt,
    addedByPubkeyHex,
    removedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupMember &&
          other.chatId == this.chatId &&
          other.memberPubkeyHex == this.memberPubkeyHex &&
          other.addedAt == this.addedAt &&
          other.addedByPubkeyHex == this.addedByPubkeyHex &&
          other.removedAt == this.removedAt);
}

class GroupMembersCompanion extends UpdateCompanion<GroupMember> {
  final Value<String> chatId;
  final Value<String> memberPubkeyHex;
  final Value<DateTime> addedAt;
  final Value<String> addedByPubkeyHex;
  final Value<DateTime?> removedAt;
  final Value<int> rowid;
  const GroupMembersCompanion({
    this.chatId = const Value.absent(),
    this.memberPubkeyHex = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.addedByPubkeyHex = const Value.absent(),
    this.removedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupMembersCompanion.insert({
    required String chatId,
    required String memberPubkeyHex,
    required DateTime addedAt,
    required String addedByPubkeyHex,
    this.removedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : chatId = Value(chatId),
       memberPubkeyHex = Value(memberPubkeyHex),
       addedAt = Value(addedAt),
       addedByPubkeyHex = Value(addedByPubkeyHex);
  static Insertable<GroupMember> custom({
    Expression<String>? chatId,
    Expression<String>? memberPubkeyHex,
    Expression<DateTime>? addedAt,
    Expression<String>? addedByPubkeyHex,
    Expression<DateTime>? removedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chatId != null) 'chat_id': chatId,
      if (memberPubkeyHex != null) 'member_pubkey_hex': memberPubkeyHex,
      if (addedAt != null) 'added_at': addedAt,
      if (addedByPubkeyHex != null) 'added_by_pubkey_hex': addedByPubkeyHex,
      if (removedAt != null) 'removed_at': removedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupMembersCompanion copyWith({
    Value<String>? chatId,
    Value<String>? memberPubkeyHex,
    Value<DateTime>? addedAt,
    Value<String>? addedByPubkeyHex,
    Value<DateTime?>? removedAt,
    Value<int>? rowid,
  }) {
    return GroupMembersCompanion(
      chatId: chatId ?? this.chatId,
      memberPubkeyHex: memberPubkeyHex ?? this.memberPubkeyHex,
      addedAt: addedAt ?? this.addedAt,
      addedByPubkeyHex: addedByPubkeyHex ?? this.addedByPubkeyHex,
      removedAt: removedAt ?? this.removedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (memberPubkeyHex.present) {
      map['member_pubkey_hex'] = Variable<String>(memberPubkeyHex.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (addedByPubkeyHex.present) {
      map['added_by_pubkey_hex'] = Variable<String>(addedByPubkeyHex.value);
    }
    if (removedAt.present) {
      map['removed_at'] = Variable<DateTime>(removedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupMembersCompanion(')
          ..write('chatId: $chatId, ')
          ..write('memberPubkeyHex: $memberPubkeyHex, ')
          ..write('addedAt: $addedAt, ')
          ..write('addedByPubkeyHex: $addedByPubkeyHex, ')
          ..write('removedAt: $removedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupOpsLogTable extends GroupOpsLog
    with TableInfo<$GroupOpsLogTable, GroupOpsLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupOpsLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opSeqMeta = const VerificationMeta('opSeq');
  @override
  late final GeneratedColumn<int> opSeq = GeneratedColumn<int>(
    'op_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetPubkeyHexMeta = const VerificationMeta(
    'targetPubkeyHex',
  );
  @override
  late final GeneratedColumn<String> targetPubkeyHex = GeneratedColumn<String>(
    'target_pubkey_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _signerPubkeyHexMeta = const VerificationMeta(
    'signerPubkeyHex',
  );
  @override
  late final GeneratedColumn<String> signerPubkeyHex = GeneratedColumn<String>(
    'signer_pubkey_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signatureHexMeta = const VerificationMeta(
    'signatureHex',
  );
  @override
  late final GeneratedColumn<String> signatureHex = GeneratedColumn<String>(
    'signature_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appliedMeta = const VerificationMeta(
    'applied',
  );
  @override
  late final GeneratedColumn<bool> applied = GeneratedColumn<bool>(
    'applied',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("applied" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chatId,
    opSeq,
    kind,
    targetPubkeyHex,
    signerPubkeyHex,
    signatureHex,
    receivedAt,
    applied,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_ops_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupOpsLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('op_seq')) {
      context.handle(
        _opSeqMeta,
        opSeq.isAcceptableOrUnknown(data['op_seq']!, _opSeqMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('target_pubkey_hex')) {
      context.handle(
        _targetPubkeyHexMeta,
        targetPubkeyHex.isAcceptableOrUnknown(
          data['target_pubkey_hex']!,
          _targetPubkeyHexMeta,
        ),
      );
    }
    if (data.containsKey('signer_pubkey_hex')) {
      context.handle(
        _signerPubkeyHexMeta,
        signerPubkeyHex.isAcceptableOrUnknown(
          data['signer_pubkey_hex']!,
          _signerPubkeyHexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_signerPubkeyHexMeta);
    }
    if (data.containsKey('signature_hex')) {
      context.handle(
        _signatureHexMeta,
        signatureHex.isAcceptableOrUnknown(
          data['signature_hex']!,
          _signatureHexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_signatureHexMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('applied')) {
      context.handle(
        _appliedMeta,
        applied.isAcceptableOrUnknown(data['applied']!, _appliedMeta),
      );
    } else if (isInserting) {
      context.missing(_appliedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GroupOpsLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupOpsLogData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_id'],
      )!,
      opSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}op_seq'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      targetPubkeyHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_pubkey_hex'],
      ),
      signerPubkeyHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signer_pubkey_hex'],
      )!,
      signatureHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature_hex'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
      applied: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}applied'],
      )!,
    );
  }

  @override
  $GroupOpsLogTable createAlias(String alias) {
    return $GroupOpsLogTable(attachedDatabase, alias);
  }
}

class GroupOpsLogData extends DataClass implements Insertable<GroupOpsLogData> {
  final String id;
  final String chatId;
  final int? opSeq;
  final String kind;
  final String? targetPubkeyHex;
  final String signerPubkeyHex;
  final String signatureHex;
  final DateTime receivedAt;
  final bool applied;
  const GroupOpsLogData({
    required this.id,
    required this.chatId,
    this.opSeq,
    required this.kind,
    this.targetPubkeyHex,
    required this.signerPubkeyHex,
    required this.signatureHex,
    required this.receivedAt,
    required this.applied,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['chat_id'] = Variable<String>(chatId);
    if (!nullToAbsent || opSeq != null) {
      map['op_seq'] = Variable<int>(opSeq);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || targetPubkeyHex != null) {
      map['target_pubkey_hex'] = Variable<String>(targetPubkeyHex);
    }
    map['signer_pubkey_hex'] = Variable<String>(signerPubkeyHex);
    map['signature_hex'] = Variable<String>(signatureHex);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['applied'] = Variable<bool>(applied);
    return map;
  }

  GroupOpsLogCompanion toCompanion(bool nullToAbsent) {
    return GroupOpsLogCompanion(
      id: Value(id),
      chatId: Value(chatId),
      opSeq: opSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(opSeq),
      kind: Value(kind),
      targetPubkeyHex: targetPubkeyHex == null && nullToAbsent
          ? const Value.absent()
          : Value(targetPubkeyHex),
      signerPubkeyHex: Value(signerPubkeyHex),
      signatureHex: Value(signatureHex),
      receivedAt: Value(receivedAt),
      applied: Value(applied),
    );
  }

  factory GroupOpsLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupOpsLogData(
      id: serializer.fromJson<String>(json['id']),
      chatId: serializer.fromJson<String>(json['chatId']),
      opSeq: serializer.fromJson<int?>(json['opSeq']),
      kind: serializer.fromJson<String>(json['kind']),
      targetPubkeyHex: serializer.fromJson<String?>(json['targetPubkeyHex']),
      signerPubkeyHex: serializer.fromJson<String>(json['signerPubkeyHex']),
      signatureHex: serializer.fromJson<String>(json['signatureHex']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      applied: serializer.fromJson<bool>(json['applied']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'chatId': serializer.toJson<String>(chatId),
      'opSeq': serializer.toJson<int?>(opSeq),
      'kind': serializer.toJson<String>(kind),
      'targetPubkeyHex': serializer.toJson<String?>(targetPubkeyHex),
      'signerPubkeyHex': serializer.toJson<String>(signerPubkeyHex),
      'signatureHex': serializer.toJson<String>(signatureHex),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'applied': serializer.toJson<bool>(applied),
    };
  }

  GroupOpsLogData copyWith({
    String? id,
    String? chatId,
    Value<int?> opSeq = const Value.absent(),
    String? kind,
    Value<String?> targetPubkeyHex = const Value.absent(),
    String? signerPubkeyHex,
    String? signatureHex,
    DateTime? receivedAt,
    bool? applied,
  }) => GroupOpsLogData(
    id: id ?? this.id,
    chatId: chatId ?? this.chatId,
    opSeq: opSeq.present ? opSeq.value : this.opSeq,
    kind: kind ?? this.kind,
    targetPubkeyHex: targetPubkeyHex.present
        ? targetPubkeyHex.value
        : this.targetPubkeyHex,
    signerPubkeyHex: signerPubkeyHex ?? this.signerPubkeyHex,
    signatureHex: signatureHex ?? this.signatureHex,
    receivedAt: receivedAt ?? this.receivedAt,
    applied: applied ?? this.applied,
  );
  GroupOpsLogData copyWithCompanion(GroupOpsLogCompanion data) {
    return GroupOpsLogData(
      id: data.id.present ? data.id.value : this.id,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      opSeq: data.opSeq.present ? data.opSeq.value : this.opSeq,
      kind: data.kind.present ? data.kind.value : this.kind,
      targetPubkeyHex: data.targetPubkeyHex.present
          ? data.targetPubkeyHex.value
          : this.targetPubkeyHex,
      signerPubkeyHex: data.signerPubkeyHex.present
          ? data.signerPubkeyHex.value
          : this.signerPubkeyHex,
      signatureHex: data.signatureHex.present
          ? data.signatureHex.value
          : this.signatureHex,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
      applied: data.applied.present ? data.applied.value : this.applied,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupOpsLogData(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('opSeq: $opSeq, ')
          ..write('kind: $kind, ')
          ..write('targetPubkeyHex: $targetPubkeyHex, ')
          ..write('signerPubkeyHex: $signerPubkeyHex, ')
          ..write('signatureHex: $signatureHex, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('applied: $applied')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    chatId,
    opSeq,
    kind,
    targetPubkeyHex,
    signerPubkeyHex,
    signatureHex,
    receivedAt,
    applied,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupOpsLogData &&
          other.id == this.id &&
          other.chatId == this.chatId &&
          other.opSeq == this.opSeq &&
          other.kind == this.kind &&
          other.targetPubkeyHex == this.targetPubkeyHex &&
          other.signerPubkeyHex == this.signerPubkeyHex &&
          other.signatureHex == this.signatureHex &&
          other.receivedAt == this.receivedAt &&
          other.applied == this.applied);
}

class GroupOpsLogCompanion extends UpdateCompanion<GroupOpsLogData> {
  final Value<String> id;
  final Value<String> chatId;
  final Value<int?> opSeq;
  final Value<String> kind;
  final Value<String?> targetPubkeyHex;
  final Value<String> signerPubkeyHex;
  final Value<String> signatureHex;
  final Value<DateTime> receivedAt;
  final Value<bool> applied;
  final Value<int> rowid;
  const GroupOpsLogCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.opSeq = const Value.absent(),
    this.kind = const Value.absent(),
    this.targetPubkeyHex = const Value.absent(),
    this.signerPubkeyHex = const Value.absent(),
    this.signatureHex = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.applied = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupOpsLogCompanion.insert({
    required String id,
    required String chatId,
    this.opSeq = const Value.absent(),
    required String kind,
    this.targetPubkeyHex = const Value.absent(),
    required String signerPubkeyHex,
    required String signatureHex,
    required DateTime receivedAt,
    required bool applied,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       chatId = Value(chatId),
       kind = Value(kind),
       signerPubkeyHex = Value(signerPubkeyHex),
       signatureHex = Value(signatureHex),
       receivedAt = Value(receivedAt),
       applied = Value(applied);
  static Insertable<GroupOpsLogData> custom({
    Expression<String>? id,
    Expression<String>? chatId,
    Expression<int>? opSeq,
    Expression<String>? kind,
    Expression<String>? targetPubkeyHex,
    Expression<String>? signerPubkeyHex,
    Expression<String>? signatureHex,
    Expression<DateTime>? receivedAt,
    Expression<bool>? applied,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chatId != null) 'chat_id': chatId,
      if (opSeq != null) 'op_seq': opSeq,
      if (kind != null) 'kind': kind,
      if (targetPubkeyHex != null) 'target_pubkey_hex': targetPubkeyHex,
      if (signerPubkeyHex != null) 'signer_pubkey_hex': signerPubkeyHex,
      if (signatureHex != null) 'signature_hex': signatureHex,
      if (receivedAt != null) 'received_at': receivedAt,
      if (applied != null) 'applied': applied,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupOpsLogCompanion copyWith({
    Value<String>? id,
    Value<String>? chatId,
    Value<int?>? opSeq,
    Value<String>? kind,
    Value<String?>? targetPubkeyHex,
    Value<String>? signerPubkeyHex,
    Value<String>? signatureHex,
    Value<DateTime>? receivedAt,
    Value<bool>? applied,
    Value<int>? rowid,
  }) {
    return GroupOpsLogCompanion(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      opSeq: opSeq ?? this.opSeq,
      kind: kind ?? this.kind,
      targetPubkeyHex: targetPubkeyHex ?? this.targetPubkeyHex,
      signerPubkeyHex: signerPubkeyHex ?? this.signerPubkeyHex,
      signatureHex: signatureHex ?? this.signatureHex,
      receivedAt: receivedAt ?? this.receivedAt,
      applied: applied ?? this.applied,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (opSeq.present) {
      map['op_seq'] = Variable<int>(opSeq.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (targetPubkeyHex.present) {
      map['target_pubkey_hex'] = Variable<String>(targetPubkeyHex.value);
    }
    if (signerPubkeyHex.present) {
      map['signer_pubkey_hex'] = Variable<String>(signerPubkeyHex.value);
    }
    if (signatureHex.present) {
      map['signature_hex'] = Variable<String>(signatureHex.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (applied.present) {
      map['applied'] = Variable<bool>(applied.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupOpsLogCompanion(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('opSeq: $opSeq, ')
          ..write('kind: $kind, ')
          ..write('targetPubkeyHex: $targetPubkeyHex, ')
          ..write('signerPubkeyHex: $signerPubkeyHex, ')
          ..write('signatureHex: $signatureHex, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('applied: $applied, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeerBundleStateTable extends PeerBundleState
    with TableInfo<$PeerBundleStateTable, PeerBundleStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeerBundleStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _peerPubkeyHexMeta = const VerificationMeta(
    'peerPubkeyHex',
  );
  @override
  late final GeneratedColumn<String> peerPubkeyHex = GeneratedColumn<String>(
    'peer_pubkey_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bundleSentAtMeta = const VerificationMeta(
    'bundleSentAt',
  );
  @override
  late final GeneratedColumn<DateTime> bundleSentAt = GeneratedColumn<DateTime>(
    'bundle_sent_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _peerBundleReceivedAtMeta =
      const VerificationMeta('peerBundleReceivedAt');
  @override
  late final GeneratedColumn<DateTime> peerBundleReceivedAt =
      GeneratedColumn<DateTime>(
        'peer_bundle_received_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    peerPubkeyHex,
    bundleSentAt,
    peerBundleReceivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'peer_bundle_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeerBundleStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('peer_pubkey_hex')) {
      context.handle(
        _peerPubkeyHexMeta,
        peerPubkeyHex.isAcceptableOrUnknown(
          data['peer_pubkey_hex']!,
          _peerPubkeyHexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_peerPubkeyHexMeta);
    }
    if (data.containsKey('bundle_sent_at')) {
      context.handle(
        _bundleSentAtMeta,
        bundleSentAt.isAcceptableOrUnknown(
          data['bundle_sent_at']!,
          _bundleSentAtMeta,
        ),
      );
    }
    if (data.containsKey('peer_bundle_received_at')) {
      context.handle(
        _peerBundleReceivedAtMeta,
        peerBundleReceivedAt.isAcceptableOrUnknown(
          data['peer_bundle_received_at']!,
          _peerBundleReceivedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {peerPubkeyHex};
  @override
  PeerBundleStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeerBundleStateData(
      peerPubkeyHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_pubkey_hex'],
      )!,
      bundleSentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}bundle_sent_at'],
      ),
      peerBundleReceivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}peer_bundle_received_at'],
      ),
    );
  }

  @override
  $PeerBundleStateTable createAlias(String alias) {
    return $PeerBundleStateTable(attachedDatabase, alias);
  }
}

class PeerBundleStateData extends DataClass
    implements Insertable<PeerBundleStateData> {
  final String peerPubkeyHex;
  final DateTime? bundleSentAt;
  final DateTime? peerBundleReceivedAt;
  const PeerBundleStateData({
    required this.peerPubkeyHex,
    this.bundleSentAt,
    this.peerBundleReceivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_pubkey_hex'] = Variable<String>(peerPubkeyHex);
    if (!nullToAbsent || bundleSentAt != null) {
      map['bundle_sent_at'] = Variable<DateTime>(bundleSentAt);
    }
    if (!nullToAbsent || peerBundleReceivedAt != null) {
      map['peer_bundle_received_at'] = Variable<DateTime>(peerBundleReceivedAt);
    }
    return map;
  }

  PeerBundleStateCompanion toCompanion(bool nullToAbsent) {
    return PeerBundleStateCompanion(
      peerPubkeyHex: Value(peerPubkeyHex),
      bundleSentAt: bundleSentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(bundleSentAt),
      peerBundleReceivedAt: peerBundleReceivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(peerBundleReceivedAt),
    );
  }

  factory PeerBundleStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeerBundleStateData(
      peerPubkeyHex: serializer.fromJson<String>(json['peerPubkeyHex']),
      bundleSentAt: serializer.fromJson<DateTime?>(json['bundleSentAt']),
      peerBundleReceivedAt: serializer.fromJson<DateTime?>(
        json['peerBundleReceivedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'peerPubkeyHex': serializer.toJson<String>(peerPubkeyHex),
      'bundleSentAt': serializer.toJson<DateTime?>(bundleSentAt),
      'peerBundleReceivedAt': serializer.toJson<DateTime?>(
        peerBundleReceivedAt,
      ),
    };
  }

  PeerBundleStateData copyWith({
    String? peerPubkeyHex,
    Value<DateTime?> bundleSentAt = const Value.absent(),
    Value<DateTime?> peerBundleReceivedAt = const Value.absent(),
  }) => PeerBundleStateData(
    peerPubkeyHex: peerPubkeyHex ?? this.peerPubkeyHex,
    bundleSentAt: bundleSentAt.present ? bundleSentAt.value : this.bundleSentAt,
    peerBundleReceivedAt: peerBundleReceivedAt.present
        ? peerBundleReceivedAt.value
        : this.peerBundleReceivedAt,
  );
  PeerBundleStateData copyWithCompanion(PeerBundleStateCompanion data) {
    return PeerBundleStateData(
      peerPubkeyHex: data.peerPubkeyHex.present
          ? data.peerPubkeyHex.value
          : this.peerPubkeyHex,
      bundleSentAt: data.bundleSentAt.present
          ? data.bundleSentAt.value
          : this.bundleSentAt,
      peerBundleReceivedAt: data.peerBundleReceivedAt.present
          ? data.peerBundleReceivedAt.value
          : this.peerBundleReceivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeerBundleStateData(')
          ..write('peerPubkeyHex: $peerPubkeyHex, ')
          ..write('bundleSentAt: $bundleSentAt, ')
          ..write('peerBundleReceivedAt: $peerBundleReceivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(peerPubkeyHex, bundleSentAt, peerBundleReceivedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeerBundleStateData &&
          other.peerPubkeyHex == this.peerPubkeyHex &&
          other.bundleSentAt == this.bundleSentAt &&
          other.peerBundleReceivedAt == this.peerBundleReceivedAt);
}

class PeerBundleStateCompanion extends UpdateCompanion<PeerBundleStateData> {
  final Value<String> peerPubkeyHex;
  final Value<DateTime?> bundleSentAt;
  final Value<DateTime?> peerBundleReceivedAt;
  final Value<int> rowid;
  const PeerBundleStateCompanion({
    this.peerPubkeyHex = const Value.absent(),
    this.bundleSentAt = const Value.absent(),
    this.peerBundleReceivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeerBundleStateCompanion.insert({
    required String peerPubkeyHex,
    this.bundleSentAt = const Value.absent(),
    this.peerBundleReceivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : peerPubkeyHex = Value(peerPubkeyHex);
  static Insertable<PeerBundleStateData> custom({
    Expression<String>? peerPubkeyHex,
    Expression<DateTime>? bundleSentAt,
    Expression<DateTime>? peerBundleReceivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerPubkeyHex != null) 'peer_pubkey_hex': peerPubkeyHex,
      if (bundleSentAt != null) 'bundle_sent_at': bundleSentAt,
      if (peerBundleReceivedAt != null)
        'peer_bundle_received_at': peerBundleReceivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeerBundleStateCompanion copyWith({
    Value<String>? peerPubkeyHex,
    Value<DateTime?>? bundleSentAt,
    Value<DateTime?>? peerBundleReceivedAt,
    Value<int>? rowid,
  }) {
    return PeerBundleStateCompanion(
      peerPubkeyHex: peerPubkeyHex ?? this.peerPubkeyHex,
      bundleSentAt: bundleSentAt ?? this.bundleSentAt,
      peerBundleReceivedAt: peerBundleReceivedAt ?? this.peerBundleReceivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (peerPubkeyHex.present) {
      map['peer_pubkey_hex'] = Variable<String>(peerPubkeyHex.value);
    }
    if (bundleSentAt.present) {
      map['bundle_sent_at'] = Variable<DateTime>(bundleSentAt.value);
    }
    if (peerBundleReceivedAt.present) {
      map['peer_bundle_received_at'] = Variable<DateTime>(
        peerBundleReceivedAt.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeerBundleStateCompanion(')
          ..write('peerPubkeyHex: $peerPubkeyHex, ')
          ..write('bundleSentAt: $bundleSentAt, ')
          ..write('peerBundleReceivedAt: $peerBundleReceivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _msgIdMeta = const VerificationMeta('msgId');
  @override
  late final GeneratedColumn<String> msgId = GeneratedColumn<String>(
    'msg_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerPubkeyHexMeta = const VerificationMeta(
    'peerPubkeyHex',
  );
  @override
  late final GeneratedColumn<String> peerPubkeyHex = GeneratedColumn<String>(
    'peer_pubkey_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeBytesMeta = const VerificationMeta(
    'envelopeBytes',
  );
  @override
  late final GeneratedColumn<Uint8List> envelopeBytes =
      GeneratedColumn<Uint8List>(
        'envelope_bytes',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _attemptMeta = const VerificationMeta(
    'attempt',
  );
  @override
  late final GeneratedColumn<int> attempt = GeneratedColumn<int>(
    'attempt',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    msgId,
    peerPubkeyHex,
    envelopeBytes,
    attempt,
    nextRetryAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('msg_id')) {
      context.handle(
        _msgIdMeta,
        msgId.isAcceptableOrUnknown(data['msg_id']!, _msgIdMeta),
      );
    } else if (isInserting) {
      context.missing(_msgIdMeta);
    }
    if (data.containsKey('peer_pubkey_hex')) {
      context.handle(
        _peerPubkeyHexMeta,
        peerPubkeyHex.isAcceptableOrUnknown(
          data['peer_pubkey_hex']!,
          _peerPubkeyHexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_peerPubkeyHexMeta);
    }
    if (data.containsKey('envelope_bytes')) {
      context.handle(
        _envelopeBytesMeta,
        envelopeBytes.isAcceptableOrUnknown(
          data['envelope_bytes']!,
          _envelopeBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_envelopeBytesMeta);
    }
    if (data.containsKey('attempt')) {
      context.handle(
        _attemptMeta,
        attempt.isAcceptableOrUnknown(data['attempt']!, _attemptMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextRetryAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {msgId};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      msgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}msg_id'],
      )!,
      peerPubkeyHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_pubkey_hex'],
      )!,
      envelopeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}envelope_bytes'],
      )!,
      attempt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String msgId;
  final String peerPubkeyHex;
  final Uint8List envelopeBytes;
  final int attempt;
  final DateTime nextRetryAt;
  final DateTime createdAt;
  const OutboxData({
    required this.msgId,
    required this.peerPubkeyHex,
    required this.envelopeBytes,
    required this.attempt,
    required this.nextRetryAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['msg_id'] = Variable<String>(msgId);
    map['peer_pubkey_hex'] = Variable<String>(peerPubkeyHex);
    map['envelope_bytes'] = Variable<Uint8List>(envelopeBytes);
    map['attempt'] = Variable<int>(attempt);
    map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      msgId: Value(msgId),
      peerPubkeyHex: Value(peerPubkeyHex),
      envelopeBytes: Value(envelopeBytes),
      attempt: Value(attempt),
      nextRetryAt: Value(nextRetryAt),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      msgId: serializer.fromJson<String>(json['msgId']),
      peerPubkeyHex: serializer.fromJson<String>(json['peerPubkeyHex']),
      envelopeBytes: serializer.fromJson<Uint8List>(json['envelopeBytes']),
      attempt: serializer.fromJson<int>(json['attempt']),
      nextRetryAt: serializer.fromJson<DateTime>(json['nextRetryAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'msgId': serializer.toJson<String>(msgId),
      'peerPubkeyHex': serializer.toJson<String>(peerPubkeyHex),
      'envelopeBytes': serializer.toJson<Uint8List>(envelopeBytes),
      'attempt': serializer.toJson<int>(attempt),
      'nextRetryAt': serializer.toJson<DateTime>(nextRetryAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxData copyWith({
    String? msgId,
    String? peerPubkeyHex,
    Uint8List? envelopeBytes,
    int? attempt,
    DateTime? nextRetryAt,
    DateTime? createdAt,
  }) => OutboxData(
    msgId: msgId ?? this.msgId,
    peerPubkeyHex: peerPubkeyHex ?? this.peerPubkeyHex,
    envelopeBytes: envelopeBytes ?? this.envelopeBytes,
    attempt: attempt ?? this.attempt,
    nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      msgId: data.msgId.present ? data.msgId.value : this.msgId,
      peerPubkeyHex: data.peerPubkeyHex.present
          ? data.peerPubkeyHex.value
          : this.peerPubkeyHex,
      envelopeBytes: data.envelopeBytes.present
          ? data.envelopeBytes.value
          : this.envelopeBytes,
      attempt: data.attempt.present ? data.attempt.value : this.attempt,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('msgId: $msgId, ')
          ..write('peerPubkeyHex: $peerPubkeyHex, ')
          ..write('envelopeBytes: $envelopeBytes, ')
          ..write('attempt: $attempt, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    msgId,
    peerPubkeyHex,
    $driftBlobEquality.hash(envelopeBytes),
    attempt,
    nextRetryAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.msgId == this.msgId &&
          other.peerPubkeyHex == this.peerPubkeyHex &&
          $driftBlobEquality.equals(other.envelopeBytes, this.envelopeBytes) &&
          other.attempt == this.attempt &&
          other.nextRetryAt == this.nextRetryAt &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> msgId;
  final Value<String> peerPubkeyHex;
  final Value<Uint8List> envelopeBytes;
  final Value<int> attempt;
  final Value<DateTime> nextRetryAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const OutboxCompanion({
    this.msgId = const Value.absent(),
    this.peerPubkeyHex = const Value.absent(),
    this.envelopeBytes = const Value.absent(),
    this.attempt = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String msgId,
    required String peerPubkeyHex,
    required Uint8List envelopeBytes,
    this.attempt = const Value.absent(),
    required DateTime nextRetryAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : msgId = Value(msgId),
       peerPubkeyHex = Value(peerPubkeyHex),
       envelopeBytes = Value(envelopeBytes),
       nextRetryAt = Value(nextRetryAt),
       createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<String>? msgId,
    Expression<String>? peerPubkeyHex,
    Expression<Uint8List>? envelopeBytes,
    Expression<int>? attempt,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (msgId != null) 'msg_id': msgId,
      if (peerPubkeyHex != null) 'peer_pubkey_hex': peerPubkeyHex,
      if (envelopeBytes != null) 'envelope_bytes': envelopeBytes,
      if (attempt != null) 'attempt': attempt,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? msgId,
    Value<String>? peerPubkeyHex,
    Value<Uint8List>? envelopeBytes,
    Value<int>? attempt,
    Value<DateTime>? nextRetryAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      msgId: msgId ?? this.msgId,
      peerPubkeyHex: peerPubkeyHex ?? this.peerPubkeyHex,
      envelopeBytes: envelopeBytes ?? this.envelopeBytes,
      attempt: attempt ?? this.attempt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (msgId.present) {
      map['msg_id'] = Variable<String>(msgId.value);
    }
    if (peerPubkeyHex.present) {
      map['peer_pubkey_hex'] = Variable<String>(peerPubkeyHex.value);
    }
    if (envelopeBytes.present) {
      map['envelope_bytes'] = Variable<Uint8List>(envelopeBytes.value);
    }
    if (attempt.present) {
      map['attempt'] = Variable<int>(attempt.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('msgId: $msgId, ')
          ..write('peerPubkeyHex: $peerPubkeyHex, ')
          ..write('envelopeBytes: $envelopeBytes, ')
          ..write('attempt: $attempt, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfileTable extends Profile with TableInfo<$ProfileTable, ProfileData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, displayName, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProfileTable createAlias(String alias) {
    return $ProfileTable(attachedDatabase, alias);
  }
}

class ProfileData extends DataClass implements Insertable<ProfileData> {
  final int id;
  final String displayName;
  final DateTime updatedAt;
  const ProfileData({
    required this.id,
    required this.displayName,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['display_name'] = Variable<String>(displayName);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProfileCompanion toCompanion(bool nullToAbsent) {
    return ProfileCompanion(
      id: Value(id),
      displayName: Value(displayName),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProfileData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileData(
      id: serializer.fromJson<int>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'displayName': serializer.toJson<String>(displayName),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProfileData copyWith({int? id, String? displayName, DateTime? updatedAt}) =>
      ProfileData(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ProfileData copyWithCompanion(ProfileCompanion data) {
    return ProfileData(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileData(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, displayName, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileData &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.updatedAt == this.updatedAt);
}

class ProfileCompanion extends UpdateCompanion<ProfileData> {
  final Value<int> id;
  final Value<String> displayName;
  final Value<DateTime> updatedAt;
  const ProfileCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ProfileCompanion.insert({
    this.id = const Value.absent(),
    required String displayName,
    required DateTime updatedAt,
  }) : displayName = Value(displayName),
       updatedAt = Value(updatedAt);
  static Insertable<ProfileData> custom({
    Expression<int>? id,
    Expression<String>? displayName,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ProfileCompanion copyWith({
    Value<int>? id,
    Value<String>? displayName,
    Value<DateTime>? updatedAt,
  }) {
    return ProfileCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfileCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SignalIdentityTable extends SignalIdentity
    with TableInfo<$SignalIdentityTable, SignalIdentityData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SignalIdentityTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _identityKeyPairMeta = const VerificationMeta(
    'identityKeyPair',
  );
  @override
  late final GeneratedColumn<Uint8List> identityKeyPair =
      GeneratedColumn<Uint8List>(
        'identity_key_pair',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _registrationIdMeta = const VerificationMeta(
    'registrationId',
  );
  @override
  late final GeneratedColumn<int> registrationId = GeneratedColumn<int>(
    'registration_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<int> deviceId = GeneratedColumn<int>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    identityKeyPair,
    registrationId,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'signal_identity';
  @override
  VerificationContext validateIntegrity(
    Insertable<SignalIdentityData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('identity_key_pair')) {
      context.handle(
        _identityKeyPairMeta,
        identityKeyPair.isAcceptableOrUnknown(
          data['identity_key_pair']!,
          _identityKeyPairMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_identityKeyPairMeta);
    }
    if (data.containsKey('registration_id')) {
      context.handle(
        _registrationIdMeta,
        registrationId.isAcceptableOrUnknown(
          data['registration_id']!,
          _registrationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_registrationIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SignalIdentityData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SignalIdentityData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      identityKeyPair: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}identity_key_pair'],
      )!,
      registrationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}registration_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $SignalIdentityTable createAlias(String alias) {
    return $SignalIdentityTable(attachedDatabase, alias);
  }
}

class SignalIdentityData extends DataClass
    implements Insertable<SignalIdentityData> {
  final int id;
  final Uint8List identityKeyPair;
  final int registrationId;
  final int deviceId;
  const SignalIdentityData({
    required this.id,
    required this.identityKeyPair,
    required this.registrationId,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['identity_key_pair'] = Variable<Uint8List>(identityKeyPair);
    map['registration_id'] = Variable<int>(registrationId);
    map['device_id'] = Variable<int>(deviceId);
    return map;
  }

  SignalIdentityCompanion toCompanion(bool nullToAbsent) {
    return SignalIdentityCompanion(
      id: Value(id),
      identityKeyPair: Value(identityKeyPair),
      registrationId: Value(registrationId),
      deviceId: Value(deviceId),
    );
  }

  factory SignalIdentityData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SignalIdentityData(
      id: serializer.fromJson<int>(json['id']),
      identityKeyPair: serializer.fromJson<Uint8List>(json['identityKeyPair']),
      registrationId: serializer.fromJson<int>(json['registrationId']),
      deviceId: serializer.fromJson<int>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'identityKeyPair': serializer.toJson<Uint8List>(identityKeyPair),
      'registrationId': serializer.toJson<int>(registrationId),
      'deviceId': serializer.toJson<int>(deviceId),
    };
  }

  SignalIdentityData copyWith({
    int? id,
    Uint8List? identityKeyPair,
    int? registrationId,
    int? deviceId,
  }) => SignalIdentityData(
    id: id ?? this.id,
    identityKeyPair: identityKeyPair ?? this.identityKeyPair,
    registrationId: registrationId ?? this.registrationId,
    deviceId: deviceId ?? this.deviceId,
  );
  SignalIdentityData copyWithCompanion(SignalIdentityCompanion data) {
    return SignalIdentityData(
      id: data.id.present ? data.id.value : this.id,
      identityKeyPair: data.identityKeyPair.present
          ? data.identityKeyPair.value
          : this.identityKeyPair,
      registrationId: data.registrationId.present
          ? data.registrationId.value
          : this.registrationId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SignalIdentityData(')
          ..write('id: $id, ')
          ..write('identityKeyPair: $identityKeyPair, ')
          ..write('registrationId: $registrationId, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    $driftBlobEquality.hash(identityKeyPair),
    registrationId,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignalIdentityData &&
          other.id == this.id &&
          $driftBlobEquality.equals(
            other.identityKeyPair,
            this.identityKeyPair,
          ) &&
          other.registrationId == this.registrationId &&
          other.deviceId == this.deviceId);
}

class SignalIdentityCompanion extends UpdateCompanion<SignalIdentityData> {
  final Value<int> id;
  final Value<Uint8List> identityKeyPair;
  final Value<int> registrationId;
  final Value<int> deviceId;
  const SignalIdentityCompanion({
    this.id = const Value.absent(),
    this.identityKeyPair = const Value.absent(),
    this.registrationId = const Value.absent(),
    this.deviceId = const Value.absent(),
  });
  SignalIdentityCompanion.insert({
    this.id = const Value.absent(),
    required Uint8List identityKeyPair,
    required int registrationId,
    required int deviceId,
  }) : identityKeyPair = Value(identityKeyPair),
       registrationId = Value(registrationId),
       deviceId = Value(deviceId);
  static Insertable<SignalIdentityData> custom({
    Expression<int>? id,
    Expression<Uint8List>? identityKeyPair,
    Expression<int>? registrationId,
    Expression<int>? deviceId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (identityKeyPair != null) 'identity_key_pair': identityKeyPair,
      if (registrationId != null) 'registration_id': registrationId,
      if (deviceId != null) 'device_id': deviceId,
    });
  }

  SignalIdentityCompanion copyWith({
    Value<int>? id,
    Value<Uint8List>? identityKeyPair,
    Value<int>? registrationId,
    Value<int>? deviceId,
  }) {
    return SignalIdentityCompanion(
      id: id ?? this.id,
      identityKeyPair: identityKeyPair ?? this.identityKeyPair,
      registrationId: registrationId ?? this.registrationId,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (identityKeyPair.present) {
      map['identity_key_pair'] = Variable<Uint8List>(identityKeyPair.value);
    }
    if (registrationId.present) {
      map['registration_id'] = Variable<int>(registrationId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<int>(deviceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SignalIdentityCompanion(')
          ..write('id: $id, ')
          ..write('identityKeyPair: $identityKeyPair, ')
          ..write('registrationId: $registrationId, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }
}

class $SignalPreKeysTable extends SignalPreKeys
    with TableInfo<$SignalPreKeysTable, SignalPreKey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SignalPreKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyIdMeta = const VerificationMeta('keyId');
  @override
  late final GeneratedColumn<int> keyId = GeneratedColumn<int>(
    'key_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordMeta = const VerificationMeta('record');
  @override
  late final GeneratedColumn<Uint8List> record = GeneratedColumn<Uint8List>(
    'record',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [keyId, record];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'signal_pre_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<SignalPreKey> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key_id')) {
      context.handle(
        _keyIdMeta,
        keyId.isAcceptableOrUnknown(data['key_id']!, _keyIdMeta),
      );
    }
    if (data.containsKey('record')) {
      context.handle(
        _recordMeta,
        record.isAcceptableOrUnknown(data['record']!, _recordMeta),
      );
    } else if (isInserting) {
      context.missing(_recordMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {keyId};
  @override
  SignalPreKey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SignalPreKey(
      keyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}key_id'],
      )!,
      record: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}record'],
      )!,
    );
  }

  @override
  $SignalPreKeysTable createAlias(String alias) {
    return $SignalPreKeysTable(attachedDatabase, alias);
  }
}

class SignalPreKey extends DataClass implements Insertable<SignalPreKey> {
  final int keyId;
  final Uint8List record;
  const SignalPreKey({required this.keyId, required this.record});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key_id'] = Variable<int>(keyId);
    map['record'] = Variable<Uint8List>(record);
    return map;
  }

  SignalPreKeysCompanion toCompanion(bool nullToAbsent) {
    return SignalPreKeysCompanion(keyId: Value(keyId), record: Value(record));
  }

  factory SignalPreKey.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SignalPreKey(
      keyId: serializer.fromJson<int>(json['keyId']),
      record: serializer.fromJson<Uint8List>(json['record']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'keyId': serializer.toJson<int>(keyId),
      'record': serializer.toJson<Uint8List>(record),
    };
  }

  SignalPreKey copyWith({int? keyId, Uint8List? record}) =>
      SignalPreKey(keyId: keyId ?? this.keyId, record: record ?? this.record);
  SignalPreKey copyWithCompanion(SignalPreKeysCompanion data) {
    return SignalPreKey(
      keyId: data.keyId.present ? data.keyId.value : this.keyId,
      record: data.record.present ? data.record.value : this.record,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SignalPreKey(')
          ..write('keyId: $keyId, ')
          ..write('record: $record')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(keyId, $driftBlobEquality.hash(record));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignalPreKey &&
          other.keyId == this.keyId &&
          $driftBlobEquality.equals(other.record, this.record));
}

class SignalPreKeysCompanion extends UpdateCompanion<SignalPreKey> {
  final Value<int> keyId;
  final Value<Uint8List> record;
  const SignalPreKeysCompanion({
    this.keyId = const Value.absent(),
    this.record = const Value.absent(),
  });
  SignalPreKeysCompanion.insert({
    this.keyId = const Value.absent(),
    required Uint8List record,
  }) : record = Value(record);
  static Insertable<SignalPreKey> custom({
    Expression<int>? keyId,
    Expression<Uint8List>? record,
  }) {
    return RawValuesInsertable({
      if (keyId != null) 'key_id': keyId,
      if (record != null) 'record': record,
    });
  }

  SignalPreKeysCompanion copyWith({
    Value<int>? keyId,
    Value<Uint8List>? record,
  }) {
    return SignalPreKeysCompanion(
      keyId: keyId ?? this.keyId,
      record: record ?? this.record,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (keyId.present) {
      map['key_id'] = Variable<int>(keyId.value);
    }
    if (record.present) {
      map['record'] = Variable<Uint8List>(record.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SignalPreKeysCompanion(')
          ..write('keyId: $keyId, ')
          ..write('record: $record')
          ..write(')'))
        .toString();
  }
}

class $SignalSignedPreKeysTable extends SignalSignedPreKeys
    with TableInfo<$SignalSignedPreKeysTable, SignalSignedPreKey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SignalSignedPreKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyIdMeta = const VerificationMeta('keyId');
  @override
  late final GeneratedColumn<int> keyId = GeneratedColumn<int>(
    'key_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordMeta = const VerificationMeta('record');
  @override
  late final GeneratedColumn<Uint8List> record = GeneratedColumn<Uint8List>(
    'record',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [keyId, record];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'signal_signed_pre_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<SignalSignedPreKey> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key_id')) {
      context.handle(
        _keyIdMeta,
        keyId.isAcceptableOrUnknown(data['key_id']!, _keyIdMeta),
      );
    }
    if (data.containsKey('record')) {
      context.handle(
        _recordMeta,
        record.isAcceptableOrUnknown(data['record']!, _recordMeta),
      );
    } else if (isInserting) {
      context.missing(_recordMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {keyId};
  @override
  SignalSignedPreKey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SignalSignedPreKey(
      keyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}key_id'],
      )!,
      record: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}record'],
      )!,
    );
  }

  @override
  $SignalSignedPreKeysTable createAlias(String alias) {
    return $SignalSignedPreKeysTable(attachedDatabase, alias);
  }
}

class SignalSignedPreKey extends DataClass
    implements Insertable<SignalSignedPreKey> {
  final int keyId;
  final Uint8List record;
  const SignalSignedPreKey({required this.keyId, required this.record});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key_id'] = Variable<int>(keyId);
    map['record'] = Variable<Uint8List>(record);
    return map;
  }

  SignalSignedPreKeysCompanion toCompanion(bool nullToAbsent) {
    return SignalSignedPreKeysCompanion(
      keyId: Value(keyId),
      record: Value(record),
    );
  }

  factory SignalSignedPreKey.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SignalSignedPreKey(
      keyId: serializer.fromJson<int>(json['keyId']),
      record: serializer.fromJson<Uint8List>(json['record']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'keyId': serializer.toJson<int>(keyId),
      'record': serializer.toJson<Uint8List>(record),
    };
  }

  SignalSignedPreKey copyWith({int? keyId, Uint8List? record}) =>
      SignalSignedPreKey(
        keyId: keyId ?? this.keyId,
        record: record ?? this.record,
      );
  SignalSignedPreKey copyWithCompanion(SignalSignedPreKeysCompanion data) {
    return SignalSignedPreKey(
      keyId: data.keyId.present ? data.keyId.value : this.keyId,
      record: data.record.present ? data.record.value : this.record,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SignalSignedPreKey(')
          ..write('keyId: $keyId, ')
          ..write('record: $record')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(keyId, $driftBlobEquality.hash(record));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignalSignedPreKey &&
          other.keyId == this.keyId &&
          $driftBlobEquality.equals(other.record, this.record));
}

class SignalSignedPreKeysCompanion extends UpdateCompanion<SignalSignedPreKey> {
  final Value<int> keyId;
  final Value<Uint8List> record;
  const SignalSignedPreKeysCompanion({
    this.keyId = const Value.absent(),
    this.record = const Value.absent(),
  });
  SignalSignedPreKeysCompanion.insert({
    this.keyId = const Value.absent(),
    required Uint8List record,
  }) : record = Value(record);
  static Insertable<SignalSignedPreKey> custom({
    Expression<int>? keyId,
    Expression<Uint8List>? record,
  }) {
    return RawValuesInsertable({
      if (keyId != null) 'key_id': keyId,
      if (record != null) 'record': record,
    });
  }

  SignalSignedPreKeysCompanion copyWith({
    Value<int>? keyId,
    Value<Uint8List>? record,
  }) {
    return SignalSignedPreKeysCompanion(
      keyId: keyId ?? this.keyId,
      record: record ?? this.record,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (keyId.present) {
      map['key_id'] = Variable<int>(keyId.value);
    }
    if (record.present) {
      map['record'] = Variable<Uint8List>(record.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SignalSignedPreKeysCompanion(')
          ..write('keyId: $keyId, ')
          ..write('record: $record')
          ..write(')'))
        .toString();
  }
}

class $SignalSessionsTable extends SignalSessions
    with TableInfo<$SignalSessionsTable, SignalSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SignalSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordMeta = const VerificationMeta('record');
  @override
  late final GeneratedColumn<Uint8List> record = GeneratedColumn<Uint8List>(
    'record',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [address, record];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'signal_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SignalSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('record')) {
      context.handle(
        _recordMeta,
        record.isAcceptableOrUnknown(data['record']!, _recordMeta),
      );
    } else if (isInserting) {
      context.missing(_recordMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {address};
  @override
  SignalSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SignalSession(
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      record: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}record'],
      )!,
    );
  }

  @override
  $SignalSessionsTable createAlias(String alias) {
    return $SignalSessionsTable(attachedDatabase, alias);
  }
}

class SignalSession extends DataClass implements Insertable<SignalSession> {
  final String address;
  final Uint8List record;
  const SignalSession({required this.address, required this.record});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['address'] = Variable<String>(address);
    map['record'] = Variable<Uint8List>(record);
    return map;
  }

  SignalSessionsCompanion toCompanion(bool nullToAbsent) {
    return SignalSessionsCompanion(
      address: Value(address),
      record: Value(record),
    );
  }

  factory SignalSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SignalSession(
      address: serializer.fromJson<String>(json['address']),
      record: serializer.fromJson<Uint8List>(json['record']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'address': serializer.toJson<String>(address),
      'record': serializer.toJson<Uint8List>(record),
    };
  }

  SignalSession copyWith({String? address, Uint8List? record}) => SignalSession(
    address: address ?? this.address,
    record: record ?? this.record,
  );
  SignalSession copyWithCompanion(SignalSessionsCompanion data) {
    return SignalSession(
      address: data.address.present ? data.address.value : this.address,
      record: data.record.present ? data.record.value : this.record,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SignalSession(')
          ..write('address: $address, ')
          ..write('record: $record')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(address, $driftBlobEquality.hash(record));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignalSession &&
          other.address == this.address &&
          $driftBlobEquality.equals(other.record, this.record));
}

class SignalSessionsCompanion extends UpdateCompanion<SignalSession> {
  final Value<String> address;
  final Value<Uint8List> record;
  final Value<int> rowid;
  const SignalSessionsCompanion({
    this.address = const Value.absent(),
    this.record = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SignalSessionsCompanion.insert({
    required String address,
    required Uint8List record,
    this.rowid = const Value.absent(),
  }) : address = Value(address),
       record = Value(record);
  static Insertable<SignalSession> custom({
    Expression<String>? address,
    Expression<Uint8List>? record,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (address != null) 'address': address,
      if (record != null) 'record': record,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SignalSessionsCompanion copyWith({
    Value<String>? address,
    Value<Uint8List>? record,
    Value<int>? rowid,
  }) {
    return SignalSessionsCompanion(
      address: address ?? this.address,
      record: record ?? this.record,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (record.present) {
      map['record'] = Variable<Uint8List>(record.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SignalSessionsCompanion(')
          ..write('address: $address, ')
          ..write('record: $record, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SignalPeerIdentitiesTable extends SignalPeerIdentities
    with TableInfo<$SignalPeerIdentitiesTable, SignalPeerIdentity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SignalPeerIdentitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _peerPubkeyHexMeta = const VerificationMeta(
    'peerPubkeyHex',
  );
  @override
  late final GeneratedColumn<String> peerPubkeyHex = GeneratedColumn<String>(
    'peer_pubkey_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _identityKeyMeta = const VerificationMeta(
    'identityKey',
  );
  @override
  late final GeneratedColumn<Uint8List> identityKey =
      GeneratedColumn<Uint8List>(
        'identity_key',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _trustedMeta = const VerificationMeta(
    'trusted',
  );
  @override
  late final GeneratedColumn<bool> trusted = GeneratedColumn<bool>(
    'trusted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("trusted" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [peerPubkeyHex, identityKey, trusted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'signal_peer_identities';
  @override
  VerificationContext validateIntegrity(
    Insertable<SignalPeerIdentity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('peer_pubkey_hex')) {
      context.handle(
        _peerPubkeyHexMeta,
        peerPubkeyHex.isAcceptableOrUnknown(
          data['peer_pubkey_hex']!,
          _peerPubkeyHexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_peerPubkeyHexMeta);
    }
    if (data.containsKey('identity_key')) {
      context.handle(
        _identityKeyMeta,
        identityKey.isAcceptableOrUnknown(
          data['identity_key']!,
          _identityKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_identityKeyMeta);
    }
    if (data.containsKey('trusted')) {
      context.handle(
        _trustedMeta,
        trusted.isAcceptableOrUnknown(data['trusted']!, _trustedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {peerPubkeyHex};
  @override
  SignalPeerIdentity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SignalPeerIdentity(
      peerPubkeyHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_pubkey_hex'],
      )!,
      identityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}identity_key'],
      )!,
      trusted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}trusted'],
      )!,
    );
  }

  @override
  $SignalPeerIdentitiesTable createAlias(String alias) {
    return $SignalPeerIdentitiesTable(attachedDatabase, alias);
  }
}

class SignalPeerIdentity extends DataClass
    implements Insertable<SignalPeerIdentity> {
  final String peerPubkeyHex;
  final Uint8List identityKey;
  final bool trusted;
  const SignalPeerIdentity({
    required this.peerPubkeyHex,
    required this.identityKey,
    required this.trusted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_pubkey_hex'] = Variable<String>(peerPubkeyHex);
    map['identity_key'] = Variable<Uint8List>(identityKey);
    map['trusted'] = Variable<bool>(trusted);
    return map;
  }

  SignalPeerIdentitiesCompanion toCompanion(bool nullToAbsent) {
    return SignalPeerIdentitiesCompanion(
      peerPubkeyHex: Value(peerPubkeyHex),
      identityKey: Value(identityKey),
      trusted: Value(trusted),
    );
  }

  factory SignalPeerIdentity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SignalPeerIdentity(
      peerPubkeyHex: serializer.fromJson<String>(json['peerPubkeyHex']),
      identityKey: serializer.fromJson<Uint8List>(json['identityKey']),
      trusted: serializer.fromJson<bool>(json['trusted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'peerPubkeyHex': serializer.toJson<String>(peerPubkeyHex),
      'identityKey': serializer.toJson<Uint8List>(identityKey),
      'trusted': serializer.toJson<bool>(trusted),
    };
  }

  SignalPeerIdentity copyWith({
    String? peerPubkeyHex,
    Uint8List? identityKey,
    bool? trusted,
  }) => SignalPeerIdentity(
    peerPubkeyHex: peerPubkeyHex ?? this.peerPubkeyHex,
    identityKey: identityKey ?? this.identityKey,
    trusted: trusted ?? this.trusted,
  );
  SignalPeerIdentity copyWithCompanion(SignalPeerIdentitiesCompanion data) {
    return SignalPeerIdentity(
      peerPubkeyHex: data.peerPubkeyHex.present
          ? data.peerPubkeyHex.value
          : this.peerPubkeyHex,
      identityKey: data.identityKey.present
          ? data.identityKey.value
          : this.identityKey,
      trusted: data.trusted.present ? data.trusted.value : this.trusted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SignalPeerIdentity(')
          ..write('peerPubkeyHex: $peerPubkeyHex, ')
          ..write('identityKey: $identityKey, ')
          ..write('trusted: $trusted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(peerPubkeyHex, $driftBlobEquality.hash(identityKey), trusted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignalPeerIdentity &&
          other.peerPubkeyHex == this.peerPubkeyHex &&
          $driftBlobEquality.equals(other.identityKey, this.identityKey) &&
          other.trusted == this.trusted);
}

class SignalPeerIdentitiesCompanion
    extends UpdateCompanion<SignalPeerIdentity> {
  final Value<String> peerPubkeyHex;
  final Value<Uint8List> identityKey;
  final Value<bool> trusted;
  final Value<int> rowid;
  const SignalPeerIdentitiesCompanion({
    this.peerPubkeyHex = const Value.absent(),
    this.identityKey = const Value.absent(),
    this.trusted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SignalPeerIdentitiesCompanion.insert({
    required String peerPubkeyHex,
    required Uint8List identityKey,
    this.trusted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : peerPubkeyHex = Value(peerPubkeyHex),
       identityKey = Value(identityKey);
  static Insertable<SignalPeerIdentity> custom({
    Expression<String>? peerPubkeyHex,
    Expression<Uint8List>? identityKey,
    Expression<bool>? trusted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerPubkeyHex != null) 'peer_pubkey_hex': peerPubkeyHex,
      if (identityKey != null) 'identity_key': identityKey,
      if (trusted != null) 'trusted': trusted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SignalPeerIdentitiesCompanion copyWith({
    Value<String>? peerPubkeyHex,
    Value<Uint8List>? identityKey,
    Value<bool>? trusted,
    Value<int>? rowid,
  }) {
    return SignalPeerIdentitiesCompanion(
      peerPubkeyHex: peerPubkeyHex ?? this.peerPubkeyHex,
      identityKey: identityKey ?? this.identityKey,
      trusted: trusted ?? this.trusted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (peerPubkeyHex.present) {
      map['peer_pubkey_hex'] = Variable<String>(peerPubkeyHex.value);
    }
    if (identityKey.present) {
      map['identity_key'] = Variable<Uint8List>(identityKey.value);
    }
    if (trusted.present) {
      map['trusted'] = Variable<bool>(trusted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SignalPeerIdentitiesCompanion(')
          ..write('peerPubkeyHex: $peerPubkeyHex, ')
          ..write('identityKey: $identityKey, ')
          ..write('trusted: $trusted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ContactsTable contacts = $ContactsTable(this);
  late final $ChatsTable chats = $ChatsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $LamportSeqTable lamportSeq = $LamportSeqTable(this);
  late final $GroupMembersTable groupMembers = $GroupMembersTable(this);
  late final $GroupOpsLogTable groupOpsLog = $GroupOpsLogTable(this);
  late final $PeerBundleStateTable peerBundleState = $PeerBundleStateTable(
    this,
  );
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $ProfileTable profile = $ProfileTable(this);
  late final $SignalIdentityTable signalIdentity = $SignalIdentityTable(this);
  late final $SignalPreKeysTable signalPreKeys = $SignalPreKeysTable(this);
  late final $SignalSignedPreKeysTable signalSignedPreKeys =
      $SignalSignedPreKeysTable(this);
  late final $SignalSessionsTable signalSessions = $SignalSessionsTable(this);
  late final $SignalPeerIdentitiesTable signalPeerIdentities =
      $SignalPeerIdentitiesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    contacts,
    chats,
    messages,
    lamportSeq,
    groupMembers,
    groupOpsLog,
    peerBundleState,
    outbox,
    profile,
    signalIdentity,
    signalPreKeys,
    signalSignedPreKeys,
    signalSessions,
    signalPeerIdentities,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$ContactsTableCreateCompanionBuilder =
    ContactsCompanion Function({
      required String pubkeyHex,
      required DateTime addedAt,
      Value<String?> displayName,
      Value<String?> claimedName,
      Value<int> rowid,
    });
typedef $$ContactsTableUpdateCompanionBuilder =
    ContactsCompanion Function({
      Value<String> pubkeyHex,
      Value<DateTime> addedAt,
      Value<String?> displayName,
      Value<String?> claimedName,
      Value<int> rowid,
    });

class $$ContactsTableFilterComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pubkeyHex => $composableBuilder(
    column: $table.pubkeyHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get claimedName => $composableBuilder(
    column: $table.claimedName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pubkeyHex => $composableBuilder(
    column: $table.pubkeyHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get claimedName => $composableBuilder(
    column: $table.claimedName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pubkeyHex =>
      $composableBuilder(column: $table.pubkeyHex, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get claimedName => $composableBuilder(
    column: $table.claimedName,
    builder: (column) => column,
  );
}

class $$ContactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContactsTable,
          Contact,
          $$ContactsTableFilterComposer,
          $$ContactsTableOrderingComposer,
          $$ContactsTableAnnotationComposer,
          $$ContactsTableCreateCompanionBuilder,
          $$ContactsTableUpdateCompanionBuilder,
          (Contact, BaseReferences<_$AppDatabase, $ContactsTable, Contact>),
          Contact,
          PrefetchHooks Function()
        > {
  $$ContactsTableTableManager(_$AppDatabase db, $ContactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pubkeyHex = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> claimedName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion(
                pubkeyHex: pubkeyHex,
                addedAt: addedAt,
                displayName: displayName,
                claimedName: claimedName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pubkeyHex,
                required DateTime addedAt,
                Value<String?> displayName = const Value.absent(),
                Value<String?> claimedName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion.insert(
                pubkeyHex: pubkeyHex,
                addedAt: addedAt,
                displayName: displayName,
                claimedName: claimedName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContactsTable,
      Contact,
      $$ContactsTableFilterComposer,
      $$ContactsTableOrderingComposer,
      $$ContactsTableAnnotationComposer,
      $$ContactsTableCreateCompanionBuilder,
      $$ContactsTableUpdateCompanionBuilder,
      (Contact, BaseReferences<_$AppDatabase, $ContactsTable, Contact>),
      Contact,
      PrefetchHooks Function()
    >;
typedef $$ChatsTableCreateCompanionBuilder =
    ChatsCompanion Function({
      required String chatId,
      Value<String> kind,
      Value<String?> groupName,
      Value<String?> creatorPubkeyHex,
      required DateTime createdAt,
      Value<DateTime?> lastMessageAt,
      Value<String?> lastMessagePreview,
      Value<DateTime?> leftAt,
      Value<int> lastOpSeq,
      Value<int> rowid,
    });
typedef $$ChatsTableUpdateCompanionBuilder =
    ChatsCompanion Function({
      Value<String> chatId,
      Value<String> kind,
      Value<String?> groupName,
      Value<String?> creatorPubkeyHex,
      Value<DateTime> createdAt,
      Value<DateTime?> lastMessageAt,
      Value<String?> lastMessagePreview,
      Value<DateTime?> leftAt,
      Value<int> lastOpSeq,
      Value<int> rowid,
    });

class $$ChatsTableFilterComposer extends Composer<_$AppDatabase, $ChatsTable> {
  $$ChatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatorPubkeyHex => $composableBuilder(
    column: $table.creatorPubkeyHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessagePreview => $composableBuilder(
    column: $table.lastMessagePreview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get leftAt => $composableBuilder(
    column: $table.leftAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastOpSeq => $composableBuilder(
    column: $table.lastOpSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatsTable> {
  $$ChatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatorPubkeyHex => $composableBuilder(
    column: $table.creatorPubkeyHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessagePreview => $composableBuilder(
    column: $table.lastMessagePreview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get leftAt => $composableBuilder(
    column: $table.leftAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastOpSeq => $composableBuilder(
    column: $table.lastOpSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatsTable> {
  $$ChatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get creatorPubkeyHex => $composableBuilder(
    column: $table.creatorPubkeyHex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessagePreview => $composableBuilder(
    column: $table.lastMessagePreview,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get leftAt =>
      $composableBuilder(column: $table.leftAt, builder: (column) => column);

  GeneratedColumn<int> get lastOpSeq =>
      $composableBuilder(column: $table.lastOpSeq, builder: (column) => column);
}

class $$ChatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatsTable,
          Chat,
          $$ChatsTableFilterComposer,
          $$ChatsTableOrderingComposer,
          $$ChatsTableAnnotationComposer,
          $$ChatsTableCreateCompanionBuilder,
          $$ChatsTableUpdateCompanionBuilder,
          (Chat, BaseReferences<_$AppDatabase, $ChatsTable, Chat>),
          Chat,
          PrefetchHooks Function()
        > {
  $$ChatsTableTableManager(_$AppDatabase db, $ChatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> chatId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<String?> creatorPubkeyHex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastMessageAt = const Value.absent(),
                Value<String?> lastMessagePreview = const Value.absent(),
                Value<DateTime?> leftAt = const Value.absent(),
                Value<int> lastOpSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatsCompanion(
                chatId: chatId,
                kind: kind,
                groupName: groupName,
                creatorPubkeyHex: creatorPubkeyHex,
                createdAt: createdAt,
                lastMessageAt: lastMessageAt,
                lastMessagePreview: lastMessagePreview,
                leftAt: leftAt,
                lastOpSeq: lastOpSeq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String chatId,
                Value<String> kind = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<String?> creatorPubkeyHex = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> lastMessageAt = const Value.absent(),
                Value<String?> lastMessagePreview = const Value.absent(),
                Value<DateTime?> leftAt = const Value.absent(),
                Value<int> lastOpSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatsCompanion.insert(
                chatId: chatId,
                kind: kind,
                groupName: groupName,
                creatorPubkeyHex: creatorPubkeyHex,
                createdAt: createdAt,
                lastMessageAt: lastMessageAt,
                lastMessagePreview: lastMessagePreview,
                leftAt: leftAt,
                lastOpSeq: lastOpSeq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatsTable,
      Chat,
      $$ChatsTableFilterComposer,
      $$ChatsTableOrderingComposer,
      $$ChatsTableAnnotationComposer,
      $$ChatsTableCreateCompanionBuilder,
      $$ChatsTableUpdateCompanionBuilder,
      (Chat, BaseReferences<_$AppDatabase, $ChatsTable, Chat>),
      Chat,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String chatId,
      required String senderPubkeyHex,
      required String body,
      required int lamport,
      required DateTime sentAt,
      Value<DateTime?> receivedAt,
      Value<String> kind,
      Value<DeliveryState> deliveryState,
      Value<DateTime?> readAt,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> chatId,
      Value<String> senderPubkeyHex,
      Value<String> body,
      Value<int> lamport,
      Value<DateTime> sentAt,
      Value<DateTime?> receivedAt,
      Value<String> kind,
      Value<DeliveryState> deliveryState,
      Value<DateTime?> readAt,
      Value<int> rowid,
    });

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderPubkeyHex => $composableBuilder(
    column: $table.senderPubkeyHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lamport => $composableBuilder(
    column: $table.lamport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DeliveryState, DeliveryState, int>
  get deliveryState => $composableBuilder(
    column: $table.deliveryState,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderPubkeyHex => $composableBuilder(
    column: $table.senderPubkeyHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lamport => $composableBuilder(
    column: $table.lamport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deliveryState => $composableBuilder(
    column: $table.deliveryState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get senderPubkeyHex => $composableBuilder(
    column: $table.senderPubkeyHex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get lamport =>
      $composableBuilder(column: $table.lamport, builder: (column) => column);

  GeneratedColumn<DateTime> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DeliveryState, int> get deliveryState =>
      $composableBuilder(
        column: $table.deliveryState,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
          Message,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> chatId = const Value.absent(),
                Value<String> senderPubkeyHex = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> lamport = const Value.absent(),
                Value<DateTime> sentAt = const Value.absent(),
                Value<DateTime?> receivedAt = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<DeliveryState> deliveryState = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                chatId: chatId,
                senderPubkeyHex: senderPubkeyHex,
                body: body,
                lamport: lamport,
                sentAt: sentAt,
                receivedAt: receivedAt,
                kind: kind,
                deliveryState: deliveryState,
                readAt: readAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String chatId,
                required String senderPubkeyHex,
                required String body,
                required int lamport,
                required DateTime sentAt,
                Value<DateTime?> receivedAt = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<DeliveryState> deliveryState = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                chatId: chatId,
                senderPubkeyHex: senderPubkeyHex,
                body: body,
                lamport: lamport,
                sentAt: sentAt,
                receivedAt: receivedAt,
                kind: kind,
                deliveryState: deliveryState,
                readAt: readAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
      Message,
      PrefetchHooks Function()
    >;
typedef $$LamportSeqTableCreateCompanionBuilder =
    LamportSeqCompanion Function({
      required String chatId,
      required int value,
      Value<int> rowid,
    });
typedef $$LamportSeqTableUpdateCompanionBuilder =
    LamportSeqCompanion Function({
      Value<String> chatId,
      Value<int> value,
      Value<int> rowid,
    });

class $$LamportSeqTableFilterComposer
    extends Composer<_$AppDatabase, $LamportSeqTable> {
  $$LamportSeqTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LamportSeqTableOrderingComposer
    extends Composer<_$AppDatabase, $LamportSeqTable> {
  $$LamportSeqTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LamportSeqTableAnnotationComposer
    extends Composer<_$AppDatabase, $LamportSeqTable> {
  $$LamportSeqTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$LamportSeqTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LamportSeqTable,
          LamportSeqData,
          $$LamportSeqTableFilterComposer,
          $$LamportSeqTableOrderingComposer,
          $$LamportSeqTableAnnotationComposer,
          $$LamportSeqTableCreateCompanionBuilder,
          $$LamportSeqTableUpdateCompanionBuilder,
          (
            LamportSeqData,
            BaseReferences<_$AppDatabase, $LamportSeqTable, LamportSeqData>,
          ),
          LamportSeqData,
          PrefetchHooks Function()
        > {
  $$LamportSeqTableTableManager(_$AppDatabase db, $LamportSeqTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LamportSeqTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LamportSeqTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LamportSeqTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> chatId = const Value.absent(),
                Value<int> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LamportSeqCompanion(
                chatId: chatId,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String chatId,
                required int value,
                Value<int> rowid = const Value.absent(),
              }) => LamportSeqCompanion.insert(
                chatId: chatId,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LamportSeqTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LamportSeqTable,
      LamportSeqData,
      $$LamportSeqTableFilterComposer,
      $$LamportSeqTableOrderingComposer,
      $$LamportSeqTableAnnotationComposer,
      $$LamportSeqTableCreateCompanionBuilder,
      $$LamportSeqTableUpdateCompanionBuilder,
      (
        LamportSeqData,
        BaseReferences<_$AppDatabase, $LamportSeqTable, LamportSeqData>,
      ),
      LamportSeqData,
      PrefetchHooks Function()
    >;
typedef $$GroupMembersTableCreateCompanionBuilder =
    GroupMembersCompanion Function({
      required String chatId,
      required String memberPubkeyHex,
      required DateTime addedAt,
      required String addedByPubkeyHex,
      Value<DateTime?> removedAt,
      Value<int> rowid,
    });
typedef $$GroupMembersTableUpdateCompanionBuilder =
    GroupMembersCompanion Function({
      Value<String> chatId,
      Value<String> memberPubkeyHex,
      Value<DateTime> addedAt,
      Value<String> addedByPubkeyHex,
      Value<DateTime?> removedAt,
      Value<int> rowid,
    });

class $$GroupMembersTableFilterComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberPubkeyHex => $composableBuilder(
    column: $table.memberPubkeyHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedByPubkeyHex => $composableBuilder(
    column: $table.addedByPubkeyHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get removedAt => $composableBuilder(
    column: $table.removedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GroupMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberPubkeyHex => $composableBuilder(
    column: $table.memberPubkeyHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedByPubkeyHex => $composableBuilder(
    column: $table.addedByPubkeyHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get removedAt => $composableBuilder(
    column: $table.removedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get memberPubkeyHex => $composableBuilder(
    column: $table.memberPubkeyHex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get addedByPubkeyHex => $composableBuilder(
    column: $table.addedByPubkeyHex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get removedAt =>
      $composableBuilder(column: $table.removedAt, builder: (column) => column);
}

class $$GroupMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupMembersTable,
          GroupMember,
          $$GroupMembersTableFilterComposer,
          $$GroupMembersTableOrderingComposer,
          $$GroupMembersTableAnnotationComposer,
          $$GroupMembersTableCreateCompanionBuilder,
          $$GroupMembersTableUpdateCompanionBuilder,
          (
            GroupMember,
            BaseReferences<_$AppDatabase, $GroupMembersTable, GroupMember>,
          ),
          GroupMember,
          PrefetchHooks Function()
        > {
  $$GroupMembersTableTableManager(_$AppDatabase db, $GroupMembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> chatId = const Value.absent(),
                Value<String> memberPubkeyHex = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<String> addedByPubkeyHex = const Value.absent(),
                Value<DateTime?> removedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion(
                chatId: chatId,
                memberPubkeyHex: memberPubkeyHex,
                addedAt: addedAt,
                addedByPubkeyHex: addedByPubkeyHex,
                removedAt: removedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String chatId,
                required String memberPubkeyHex,
                required DateTime addedAt,
                required String addedByPubkeyHex,
                Value<DateTime?> removedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion.insert(
                chatId: chatId,
                memberPubkeyHex: memberPubkeyHex,
                addedAt: addedAt,
                addedByPubkeyHex: addedByPubkeyHex,
                removedAt: removedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GroupMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupMembersTable,
      GroupMember,
      $$GroupMembersTableFilterComposer,
      $$GroupMembersTableOrderingComposer,
      $$GroupMembersTableAnnotationComposer,
      $$GroupMembersTableCreateCompanionBuilder,
      $$GroupMembersTableUpdateCompanionBuilder,
      (
        GroupMember,
        BaseReferences<_$AppDatabase, $GroupMembersTable, GroupMember>,
      ),
      GroupMember,
      PrefetchHooks Function()
    >;
typedef $$GroupOpsLogTableCreateCompanionBuilder =
    GroupOpsLogCompanion Function({
      required String id,
      required String chatId,
      Value<int?> opSeq,
      required String kind,
      Value<String?> targetPubkeyHex,
      required String signerPubkeyHex,
      required String signatureHex,
      required DateTime receivedAt,
      required bool applied,
      Value<int> rowid,
    });
typedef $$GroupOpsLogTableUpdateCompanionBuilder =
    GroupOpsLogCompanion Function({
      Value<String> id,
      Value<String> chatId,
      Value<int?> opSeq,
      Value<String> kind,
      Value<String?> targetPubkeyHex,
      Value<String> signerPubkeyHex,
      Value<String> signatureHex,
      Value<DateTime> receivedAt,
      Value<bool> applied,
      Value<int> rowid,
    });

class $$GroupOpsLogTableFilterComposer
    extends Composer<_$AppDatabase, $GroupOpsLogTable> {
  $$GroupOpsLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get opSeq => $composableBuilder(
    column: $table.opSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetPubkeyHex => $composableBuilder(
    column: $table.targetPubkeyHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signerPubkeyHex => $composableBuilder(
    column: $table.signerPubkeyHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signatureHex => $composableBuilder(
    column: $table.signatureHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get applied => $composableBuilder(
    column: $table.applied,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GroupOpsLogTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupOpsLogTable> {
  $$GroupOpsLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get opSeq => $composableBuilder(
    column: $table.opSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetPubkeyHex => $composableBuilder(
    column: $table.targetPubkeyHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signerPubkeyHex => $composableBuilder(
    column: $table.signerPubkeyHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signatureHex => $composableBuilder(
    column: $table.signatureHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get applied => $composableBuilder(
    column: $table.applied,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupOpsLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupOpsLogTable> {
  $$GroupOpsLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<int> get opSeq =>
      $composableBuilder(column: $table.opSeq, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get targetPubkeyHex => $composableBuilder(
    column: $table.targetPubkeyHex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signerPubkeyHex => $composableBuilder(
    column: $table.signerPubkeyHex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signatureHex => $composableBuilder(
    column: $table.signatureHex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get applied =>
      $composableBuilder(column: $table.applied, builder: (column) => column);
}

class $$GroupOpsLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupOpsLogTable,
          GroupOpsLogData,
          $$GroupOpsLogTableFilterComposer,
          $$GroupOpsLogTableOrderingComposer,
          $$GroupOpsLogTableAnnotationComposer,
          $$GroupOpsLogTableCreateCompanionBuilder,
          $$GroupOpsLogTableUpdateCompanionBuilder,
          (
            GroupOpsLogData,
            BaseReferences<_$AppDatabase, $GroupOpsLogTable, GroupOpsLogData>,
          ),
          GroupOpsLogData,
          PrefetchHooks Function()
        > {
  $$GroupOpsLogTableTableManager(_$AppDatabase db, $GroupOpsLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupOpsLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupOpsLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupOpsLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> chatId = const Value.absent(),
                Value<int?> opSeq = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> targetPubkeyHex = const Value.absent(),
                Value<String> signerPubkeyHex = const Value.absent(),
                Value<String> signatureHex = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<bool> applied = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupOpsLogCompanion(
                id: id,
                chatId: chatId,
                opSeq: opSeq,
                kind: kind,
                targetPubkeyHex: targetPubkeyHex,
                signerPubkeyHex: signerPubkeyHex,
                signatureHex: signatureHex,
                receivedAt: receivedAt,
                applied: applied,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String chatId,
                Value<int?> opSeq = const Value.absent(),
                required String kind,
                Value<String?> targetPubkeyHex = const Value.absent(),
                required String signerPubkeyHex,
                required String signatureHex,
                required DateTime receivedAt,
                required bool applied,
                Value<int> rowid = const Value.absent(),
              }) => GroupOpsLogCompanion.insert(
                id: id,
                chatId: chatId,
                opSeq: opSeq,
                kind: kind,
                targetPubkeyHex: targetPubkeyHex,
                signerPubkeyHex: signerPubkeyHex,
                signatureHex: signatureHex,
                receivedAt: receivedAt,
                applied: applied,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GroupOpsLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupOpsLogTable,
      GroupOpsLogData,
      $$GroupOpsLogTableFilterComposer,
      $$GroupOpsLogTableOrderingComposer,
      $$GroupOpsLogTableAnnotationComposer,
      $$GroupOpsLogTableCreateCompanionBuilder,
      $$GroupOpsLogTableUpdateCompanionBuilder,
      (
        GroupOpsLogData,
        BaseReferences<_$AppDatabase, $GroupOpsLogTable, GroupOpsLogData>,
      ),
      GroupOpsLogData,
      PrefetchHooks Function()
    >;
typedef $$PeerBundleStateTableCreateCompanionBuilder =
    PeerBundleStateCompanion Function({
      required String peerPubkeyHex,
      Value<DateTime?> bundleSentAt,
      Value<DateTime?> peerBundleReceivedAt,
      Value<int> rowid,
    });
typedef $$PeerBundleStateTableUpdateCompanionBuilder =
    PeerBundleStateCompanion Function({
      Value<String> peerPubkeyHex,
      Value<DateTime?> bundleSentAt,
      Value<DateTime?> peerBundleReceivedAt,
      Value<int> rowid,
    });

class $$PeerBundleStateTableFilterComposer
    extends Composer<_$AppDatabase, $PeerBundleStateTable> {
  $$PeerBundleStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get peerPubkeyHex => $composableBuilder(
    column: $table.peerPubkeyHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get bundleSentAt => $composableBuilder(
    column: $table.bundleSentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get peerBundleReceivedAt => $composableBuilder(
    column: $table.peerBundleReceivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeerBundleStateTableOrderingComposer
    extends Composer<_$AppDatabase, $PeerBundleStateTable> {
  $$PeerBundleStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get peerPubkeyHex => $composableBuilder(
    column: $table.peerPubkeyHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get bundleSentAt => $composableBuilder(
    column: $table.bundleSentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get peerBundleReceivedAt => $composableBuilder(
    column: $table.peerBundleReceivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeerBundleStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeerBundleStateTable> {
  $$PeerBundleStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get peerPubkeyHex => $composableBuilder(
    column: $table.peerPubkeyHex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get bundleSentAt => $composableBuilder(
    column: $table.bundleSentAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get peerBundleReceivedAt => $composableBuilder(
    column: $table.peerBundleReceivedAt,
    builder: (column) => column,
  );
}

class $$PeerBundleStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeerBundleStateTable,
          PeerBundleStateData,
          $$PeerBundleStateTableFilterComposer,
          $$PeerBundleStateTableOrderingComposer,
          $$PeerBundleStateTableAnnotationComposer,
          $$PeerBundleStateTableCreateCompanionBuilder,
          $$PeerBundleStateTableUpdateCompanionBuilder,
          (
            PeerBundleStateData,
            BaseReferences<
              _$AppDatabase,
              $PeerBundleStateTable,
              PeerBundleStateData
            >,
          ),
          PeerBundleStateData,
          PrefetchHooks Function()
        > {
  $$PeerBundleStateTableTableManager(
    _$AppDatabase db,
    $PeerBundleStateTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeerBundleStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeerBundleStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeerBundleStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> peerPubkeyHex = const Value.absent(),
                Value<DateTime?> bundleSentAt = const Value.absent(),
                Value<DateTime?> peerBundleReceivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeerBundleStateCompanion(
                peerPubkeyHex: peerPubkeyHex,
                bundleSentAt: bundleSentAt,
                peerBundleReceivedAt: peerBundleReceivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String peerPubkeyHex,
                Value<DateTime?> bundleSentAt = const Value.absent(),
                Value<DateTime?> peerBundleReceivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeerBundleStateCompanion.insert(
                peerPubkeyHex: peerPubkeyHex,
                bundleSentAt: bundleSentAt,
                peerBundleReceivedAt: peerBundleReceivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeerBundleStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeerBundleStateTable,
      PeerBundleStateData,
      $$PeerBundleStateTableFilterComposer,
      $$PeerBundleStateTableOrderingComposer,
      $$PeerBundleStateTableAnnotationComposer,
      $$PeerBundleStateTableCreateCompanionBuilder,
      $$PeerBundleStateTableUpdateCompanionBuilder,
      (
        PeerBundleStateData,
        BaseReferences<
          _$AppDatabase,
          $PeerBundleStateTable,
          PeerBundleStateData
        >,
      ),
      PeerBundleStateData,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      required String msgId,
      required String peerPubkeyHex,
      required Uint8List envelopeBytes,
      Value<int> attempt,
      required DateTime nextRetryAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<String> msgId,
      Value<String> peerPubkeyHex,
      Value<Uint8List> envelopeBytes,
      Value<int> attempt,
      Value<DateTime> nextRetryAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get msgId => $composableBuilder(
    column: $table.msgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerPubkeyHex => $composableBuilder(
    column: $table.peerPubkeyHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get envelopeBytes => $composableBuilder(
    column: $table.envelopeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get msgId => $composableBuilder(
    column: $table.msgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerPubkeyHex => $composableBuilder(
    column: $table.peerPubkeyHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get envelopeBytes => $composableBuilder(
    column: $table.envelopeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempt => $composableBuilder(
    column: $table.attempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get msgId =>
      $composableBuilder(column: $table.msgId, builder: (column) => column);

  GeneratedColumn<String> get peerPubkeyHex => $composableBuilder(
    column: $table.peerPubkeyHex,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get envelopeBytes => $composableBuilder(
    column: $table.envelopeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempt =>
      $composableBuilder(column: $table.attempt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> msgId = const Value.absent(),
                Value<String> peerPubkeyHex = const Value.absent(),
                Value<Uint8List> envelopeBytes = const Value.absent(),
                Value<int> attempt = const Value.absent(),
                Value<DateTime> nextRetryAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                msgId: msgId,
                peerPubkeyHex: peerPubkeyHex,
                envelopeBytes: envelopeBytes,
                attempt: attempt,
                nextRetryAt: nextRetryAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String msgId,
                required String peerPubkeyHex,
                required Uint8List envelopeBytes,
                Value<int> attempt = const Value.absent(),
                required DateTime nextRetryAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                msgId: msgId,
                peerPubkeyHex: peerPubkeyHex,
                envelopeBytes: envelopeBytes,
                attempt: attempt,
                nextRetryAt: nextRetryAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $$ProfileTableCreateCompanionBuilder =
    ProfileCompanion Function({
      Value<int> id,
      required String displayName,
      required DateTime updatedAt,
    });
typedef $$ProfileTableUpdateCompanionBuilder =
    ProfileCompanion Function({
      Value<int> id,
      Value<String> displayName,
      Value<DateTime> updatedAt,
    });

class $$ProfileTableFilterComposer
    extends Composer<_$AppDatabase, $ProfileTable> {
  $$ProfileTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfileTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfileTable> {
  $$ProfileTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfileTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfileTable> {
  $$ProfileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProfileTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfileTable,
          ProfileData,
          $$ProfileTableFilterComposer,
          $$ProfileTableOrderingComposer,
          $$ProfileTableAnnotationComposer,
          $$ProfileTableCreateCompanionBuilder,
          $$ProfileTableUpdateCompanionBuilder,
          (
            ProfileData,
            BaseReferences<_$AppDatabase, $ProfileTable, ProfileData>,
          ),
          ProfileData,
          PrefetchHooks Function()
        > {
  $$ProfileTableTableManager(_$AppDatabase db, $ProfileTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ProfileCompanion(
                id: id,
                displayName: displayName,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String displayName,
                required DateTime updatedAt,
              }) => ProfileCompanion.insert(
                id: id,
                displayName: displayName,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfileTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfileTable,
      ProfileData,
      $$ProfileTableFilterComposer,
      $$ProfileTableOrderingComposer,
      $$ProfileTableAnnotationComposer,
      $$ProfileTableCreateCompanionBuilder,
      $$ProfileTableUpdateCompanionBuilder,
      (ProfileData, BaseReferences<_$AppDatabase, $ProfileTable, ProfileData>),
      ProfileData,
      PrefetchHooks Function()
    >;
typedef $$SignalIdentityTableCreateCompanionBuilder =
    SignalIdentityCompanion Function({
      Value<int> id,
      required Uint8List identityKeyPair,
      required int registrationId,
      required int deviceId,
    });
typedef $$SignalIdentityTableUpdateCompanionBuilder =
    SignalIdentityCompanion Function({
      Value<int> id,
      Value<Uint8List> identityKeyPair,
      Value<int> registrationId,
      Value<int> deviceId,
    });

class $$SignalIdentityTableFilterComposer
    extends Composer<_$AppDatabase, $SignalIdentityTable> {
  $$SignalIdentityTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get identityKeyPair => $composableBuilder(
    column: $table.identityKeyPair,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get registrationId => $composableBuilder(
    column: $table.registrationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SignalIdentityTableOrderingComposer
    extends Composer<_$AppDatabase, $SignalIdentityTable> {
  $$SignalIdentityTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get identityKeyPair => $composableBuilder(
    column: $table.identityKeyPair,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get registrationId => $composableBuilder(
    column: $table.registrationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SignalIdentityTableAnnotationComposer
    extends Composer<_$AppDatabase, $SignalIdentityTable> {
  $$SignalIdentityTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get identityKeyPair => $composableBuilder(
    column: $table.identityKeyPair,
    builder: (column) => column,
  );

  GeneratedColumn<int> get registrationId => $composableBuilder(
    column: $table.registrationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$SignalIdentityTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SignalIdentityTable,
          SignalIdentityData,
          $$SignalIdentityTableFilterComposer,
          $$SignalIdentityTableOrderingComposer,
          $$SignalIdentityTableAnnotationComposer,
          $$SignalIdentityTableCreateCompanionBuilder,
          $$SignalIdentityTableUpdateCompanionBuilder,
          (
            SignalIdentityData,
            BaseReferences<
              _$AppDatabase,
              $SignalIdentityTable,
              SignalIdentityData
            >,
          ),
          SignalIdentityData,
          PrefetchHooks Function()
        > {
  $$SignalIdentityTableTableManager(
    _$AppDatabase db,
    $SignalIdentityTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SignalIdentityTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SignalIdentityTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SignalIdentityTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<Uint8List> identityKeyPair = const Value.absent(),
                Value<int> registrationId = const Value.absent(),
                Value<int> deviceId = const Value.absent(),
              }) => SignalIdentityCompanion(
                id: id,
                identityKeyPair: identityKeyPair,
                registrationId: registrationId,
                deviceId: deviceId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required Uint8List identityKeyPair,
                required int registrationId,
                required int deviceId,
              }) => SignalIdentityCompanion.insert(
                id: id,
                identityKeyPair: identityKeyPair,
                registrationId: registrationId,
                deviceId: deviceId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SignalIdentityTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SignalIdentityTable,
      SignalIdentityData,
      $$SignalIdentityTableFilterComposer,
      $$SignalIdentityTableOrderingComposer,
      $$SignalIdentityTableAnnotationComposer,
      $$SignalIdentityTableCreateCompanionBuilder,
      $$SignalIdentityTableUpdateCompanionBuilder,
      (
        SignalIdentityData,
        BaseReferences<_$AppDatabase, $SignalIdentityTable, SignalIdentityData>,
      ),
      SignalIdentityData,
      PrefetchHooks Function()
    >;
typedef $$SignalPreKeysTableCreateCompanionBuilder =
    SignalPreKeysCompanion Function({
      Value<int> keyId,
      required Uint8List record,
    });
typedef $$SignalPreKeysTableUpdateCompanionBuilder =
    SignalPreKeysCompanion Function({
      Value<int> keyId,
      Value<Uint8List> record,
    });

class $$SignalPreKeysTableFilterComposer
    extends Composer<_$AppDatabase, $SignalPreKeysTable> {
  $$SignalPreKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get keyId => $composableBuilder(
    column: $table.keyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SignalPreKeysTableOrderingComposer
    extends Composer<_$AppDatabase, $SignalPreKeysTable> {
  $$SignalPreKeysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get keyId => $composableBuilder(
    column: $table.keyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SignalPreKeysTableAnnotationComposer
    extends Composer<_$AppDatabase, $SignalPreKeysTable> {
  $$SignalPreKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get keyId =>
      $composableBuilder(column: $table.keyId, builder: (column) => column);

  GeneratedColumn<Uint8List> get record =>
      $composableBuilder(column: $table.record, builder: (column) => column);
}

class $$SignalPreKeysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SignalPreKeysTable,
          SignalPreKey,
          $$SignalPreKeysTableFilterComposer,
          $$SignalPreKeysTableOrderingComposer,
          $$SignalPreKeysTableAnnotationComposer,
          $$SignalPreKeysTableCreateCompanionBuilder,
          $$SignalPreKeysTableUpdateCompanionBuilder,
          (
            SignalPreKey,
            BaseReferences<_$AppDatabase, $SignalPreKeysTable, SignalPreKey>,
          ),
          SignalPreKey,
          PrefetchHooks Function()
        > {
  $$SignalPreKeysTableTableManager(_$AppDatabase db, $SignalPreKeysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SignalPreKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SignalPreKeysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SignalPreKeysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> keyId = const Value.absent(),
                Value<Uint8List> record = const Value.absent(),
              }) => SignalPreKeysCompanion(keyId: keyId, record: record),
          createCompanionCallback:
              ({
                Value<int> keyId = const Value.absent(),
                required Uint8List record,
              }) => SignalPreKeysCompanion.insert(keyId: keyId, record: record),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SignalPreKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SignalPreKeysTable,
      SignalPreKey,
      $$SignalPreKeysTableFilterComposer,
      $$SignalPreKeysTableOrderingComposer,
      $$SignalPreKeysTableAnnotationComposer,
      $$SignalPreKeysTableCreateCompanionBuilder,
      $$SignalPreKeysTableUpdateCompanionBuilder,
      (
        SignalPreKey,
        BaseReferences<_$AppDatabase, $SignalPreKeysTable, SignalPreKey>,
      ),
      SignalPreKey,
      PrefetchHooks Function()
    >;
typedef $$SignalSignedPreKeysTableCreateCompanionBuilder =
    SignalSignedPreKeysCompanion Function({
      Value<int> keyId,
      required Uint8List record,
    });
typedef $$SignalSignedPreKeysTableUpdateCompanionBuilder =
    SignalSignedPreKeysCompanion Function({
      Value<int> keyId,
      Value<Uint8List> record,
    });

class $$SignalSignedPreKeysTableFilterComposer
    extends Composer<_$AppDatabase, $SignalSignedPreKeysTable> {
  $$SignalSignedPreKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get keyId => $composableBuilder(
    column: $table.keyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SignalSignedPreKeysTableOrderingComposer
    extends Composer<_$AppDatabase, $SignalSignedPreKeysTable> {
  $$SignalSignedPreKeysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get keyId => $composableBuilder(
    column: $table.keyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SignalSignedPreKeysTableAnnotationComposer
    extends Composer<_$AppDatabase, $SignalSignedPreKeysTable> {
  $$SignalSignedPreKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get keyId =>
      $composableBuilder(column: $table.keyId, builder: (column) => column);

  GeneratedColumn<Uint8List> get record =>
      $composableBuilder(column: $table.record, builder: (column) => column);
}

class $$SignalSignedPreKeysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SignalSignedPreKeysTable,
          SignalSignedPreKey,
          $$SignalSignedPreKeysTableFilterComposer,
          $$SignalSignedPreKeysTableOrderingComposer,
          $$SignalSignedPreKeysTableAnnotationComposer,
          $$SignalSignedPreKeysTableCreateCompanionBuilder,
          $$SignalSignedPreKeysTableUpdateCompanionBuilder,
          (
            SignalSignedPreKey,
            BaseReferences<
              _$AppDatabase,
              $SignalSignedPreKeysTable,
              SignalSignedPreKey
            >,
          ),
          SignalSignedPreKey,
          PrefetchHooks Function()
        > {
  $$SignalSignedPreKeysTableTableManager(
    _$AppDatabase db,
    $SignalSignedPreKeysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SignalSignedPreKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SignalSignedPreKeysTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SignalSignedPreKeysTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> keyId = const Value.absent(),
                Value<Uint8List> record = const Value.absent(),
              }) => SignalSignedPreKeysCompanion(keyId: keyId, record: record),
          createCompanionCallback:
              ({
                Value<int> keyId = const Value.absent(),
                required Uint8List record,
              }) => SignalSignedPreKeysCompanion.insert(
                keyId: keyId,
                record: record,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SignalSignedPreKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SignalSignedPreKeysTable,
      SignalSignedPreKey,
      $$SignalSignedPreKeysTableFilterComposer,
      $$SignalSignedPreKeysTableOrderingComposer,
      $$SignalSignedPreKeysTableAnnotationComposer,
      $$SignalSignedPreKeysTableCreateCompanionBuilder,
      $$SignalSignedPreKeysTableUpdateCompanionBuilder,
      (
        SignalSignedPreKey,
        BaseReferences<
          _$AppDatabase,
          $SignalSignedPreKeysTable,
          SignalSignedPreKey
        >,
      ),
      SignalSignedPreKey,
      PrefetchHooks Function()
    >;
typedef $$SignalSessionsTableCreateCompanionBuilder =
    SignalSessionsCompanion Function({
      required String address,
      required Uint8List record,
      Value<int> rowid,
    });
typedef $$SignalSessionsTableUpdateCompanionBuilder =
    SignalSessionsCompanion Function({
      Value<String> address,
      Value<Uint8List> record,
      Value<int> rowid,
    });

class $$SignalSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SignalSessionsTable> {
  $$SignalSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SignalSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SignalSessionsTable> {
  $$SignalSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SignalSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SignalSessionsTable> {
  $$SignalSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<Uint8List> get record =>
      $composableBuilder(column: $table.record, builder: (column) => column);
}

class $$SignalSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SignalSessionsTable,
          SignalSession,
          $$SignalSessionsTableFilterComposer,
          $$SignalSessionsTableOrderingComposer,
          $$SignalSessionsTableAnnotationComposer,
          $$SignalSessionsTableCreateCompanionBuilder,
          $$SignalSessionsTableUpdateCompanionBuilder,
          (
            SignalSession,
            BaseReferences<_$AppDatabase, $SignalSessionsTable, SignalSession>,
          ),
          SignalSession,
          PrefetchHooks Function()
        > {
  $$SignalSessionsTableTableManager(
    _$AppDatabase db,
    $SignalSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SignalSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SignalSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SignalSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> address = const Value.absent(),
                Value<Uint8List> record = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SignalSessionsCompanion(
                address: address,
                record: record,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String address,
                required Uint8List record,
                Value<int> rowid = const Value.absent(),
              }) => SignalSessionsCompanion.insert(
                address: address,
                record: record,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SignalSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SignalSessionsTable,
      SignalSession,
      $$SignalSessionsTableFilterComposer,
      $$SignalSessionsTableOrderingComposer,
      $$SignalSessionsTableAnnotationComposer,
      $$SignalSessionsTableCreateCompanionBuilder,
      $$SignalSessionsTableUpdateCompanionBuilder,
      (
        SignalSession,
        BaseReferences<_$AppDatabase, $SignalSessionsTable, SignalSession>,
      ),
      SignalSession,
      PrefetchHooks Function()
    >;
typedef $$SignalPeerIdentitiesTableCreateCompanionBuilder =
    SignalPeerIdentitiesCompanion Function({
      required String peerPubkeyHex,
      required Uint8List identityKey,
      Value<bool> trusted,
      Value<int> rowid,
    });
typedef $$SignalPeerIdentitiesTableUpdateCompanionBuilder =
    SignalPeerIdentitiesCompanion Function({
      Value<String> peerPubkeyHex,
      Value<Uint8List> identityKey,
      Value<bool> trusted,
      Value<int> rowid,
    });

class $$SignalPeerIdentitiesTableFilterComposer
    extends Composer<_$AppDatabase, $SignalPeerIdentitiesTable> {
  $$SignalPeerIdentitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get peerPubkeyHex => $composableBuilder(
    column: $table.peerPubkeyHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get identityKey => $composableBuilder(
    column: $table.identityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trusted => $composableBuilder(
    column: $table.trusted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SignalPeerIdentitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $SignalPeerIdentitiesTable> {
  $$SignalPeerIdentitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get peerPubkeyHex => $composableBuilder(
    column: $table.peerPubkeyHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get identityKey => $composableBuilder(
    column: $table.identityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trusted => $composableBuilder(
    column: $table.trusted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SignalPeerIdentitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SignalPeerIdentitiesTable> {
  $$SignalPeerIdentitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get peerPubkeyHex => $composableBuilder(
    column: $table.peerPubkeyHex,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get identityKey => $composableBuilder(
    column: $table.identityKey,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get trusted =>
      $composableBuilder(column: $table.trusted, builder: (column) => column);
}

class $$SignalPeerIdentitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SignalPeerIdentitiesTable,
          SignalPeerIdentity,
          $$SignalPeerIdentitiesTableFilterComposer,
          $$SignalPeerIdentitiesTableOrderingComposer,
          $$SignalPeerIdentitiesTableAnnotationComposer,
          $$SignalPeerIdentitiesTableCreateCompanionBuilder,
          $$SignalPeerIdentitiesTableUpdateCompanionBuilder,
          (
            SignalPeerIdentity,
            BaseReferences<
              _$AppDatabase,
              $SignalPeerIdentitiesTable,
              SignalPeerIdentity
            >,
          ),
          SignalPeerIdentity,
          PrefetchHooks Function()
        > {
  $$SignalPeerIdentitiesTableTableManager(
    _$AppDatabase db,
    $SignalPeerIdentitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SignalPeerIdentitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SignalPeerIdentitiesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SignalPeerIdentitiesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> peerPubkeyHex = const Value.absent(),
                Value<Uint8List> identityKey = const Value.absent(),
                Value<bool> trusted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SignalPeerIdentitiesCompanion(
                peerPubkeyHex: peerPubkeyHex,
                identityKey: identityKey,
                trusted: trusted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String peerPubkeyHex,
                required Uint8List identityKey,
                Value<bool> trusted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SignalPeerIdentitiesCompanion.insert(
                peerPubkeyHex: peerPubkeyHex,
                identityKey: identityKey,
                trusted: trusted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SignalPeerIdentitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SignalPeerIdentitiesTable,
      SignalPeerIdentity,
      $$SignalPeerIdentitiesTableFilterComposer,
      $$SignalPeerIdentitiesTableOrderingComposer,
      $$SignalPeerIdentitiesTableAnnotationComposer,
      $$SignalPeerIdentitiesTableCreateCompanionBuilder,
      $$SignalPeerIdentitiesTableUpdateCompanionBuilder,
      (
        SignalPeerIdentity,
        BaseReferences<
          _$AppDatabase,
          $SignalPeerIdentitiesTable,
          SignalPeerIdentity
        >,
      ),
      SignalPeerIdentity,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db, _db.contacts);
  $$ChatsTableTableManager get chats =>
      $$ChatsTableTableManager(_db, _db.chats);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$LamportSeqTableTableManager get lamportSeq =>
      $$LamportSeqTableTableManager(_db, _db.lamportSeq);
  $$GroupMembersTableTableManager get groupMembers =>
      $$GroupMembersTableTableManager(_db, _db.groupMembers);
  $$GroupOpsLogTableTableManager get groupOpsLog =>
      $$GroupOpsLogTableTableManager(_db, _db.groupOpsLog);
  $$PeerBundleStateTableTableManager get peerBundleState =>
      $$PeerBundleStateTableTableManager(_db, _db.peerBundleState);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$ProfileTableTableManager get profile =>
      $$ProfileTableTableManager(_db, _db.profile);
  $$SignalIdentityTableTableManager get signalIdentity =>
      $$SignalIdentityTableTableManager(_db, _db.signalIdentity);
  $$SignalPreKeysTableTableManager get signalPreKeys =>
      $$SignalPreKeysTableTableManager(_db, _db.signalPreKeys);
  $$SignalSignedPreKeysTableTableManager get signalSignedPreKeys =>
      $$SignalSignedPreKeysTableTableManager(_db, _db.signalSignedPreKeys);
  $$SignalSessionsTableTableManager get signalSessions =>
      $$SignalSessionsTableTableManager(_db, _db.signalSessions);
  $$SignalPeerIdentitiesTableTableManager get signalPeerIdentities =>
      $$SignalPeerIdentitiesTableTableManager(_db, _db.signalPeerIdentities);
}
