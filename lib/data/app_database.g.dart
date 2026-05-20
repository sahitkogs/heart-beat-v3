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
  @override
  List<GeneratedColumn> get $columns => [pubkeyHex, addedAt];
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
  const Contact({required this.pubkeyHex, required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pubkey_hex'] = Variable<String>(pubkeyHex);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  ContactsCompanion toCompanion(bool nullToAbsent) {
    return ContactsCompanion(
      pubkeyHex: Value(pubkeyHex),
      addedAt: Value(addedAt),
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
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pubkeyHex': serializer.toJson<String>(pubkeyHex),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  Contact copyWith({String? pubkeyHex, DateTime? addedAt}) => Contact(
    pubkeyHex: pubkeyHex ?? this.pubkeyHex,
    addedAt: addedAt ?? this.addedAt,
  );
  Contact copyWithCompanion(ContactsCompanion data) {
    return Contact(
      pubkeyHex: data.pubkeyHex.present ? data.pubkeyHex.value : this.pubkeyHex,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Contact(')
          ..write('pubkeyHex: $pubkeyHex, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pubkeyHex, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Contact &&
          other.pubkeyHex == this.pubkeyHex &&
          other.addedAt == this.addedAt);
}

class ContactsCompanion extends UpdateCompanion<Contact> {
  final Value<String> pubkeyHex;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const ContactsCompanion({
    this.pubkeyHex = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsCompanion.insert({
    required String pubkeyHex,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : pubkeyHex = Value(pubkeyHex),
       addedAt = Value(addedAt);
  static Insertable<Contact> custom({
    Expression<String>? pubkeyHex,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pubkeyHex != null) 'pubkey_hex': pubkeyHex,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsCompanion copyWith({
    Value<String>? pubkeyHex,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return ContactsCompanion(
      pubkeyHex: pubkeyHex ?? this.pubkeyHex,
      addedAt: addedAt ?? this.addedAt,
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
    createdAt,
    lastMessageAt,
    lastMessagePreview,
    bundleSentAt,
    peerBundleReceivedAt,
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
  Chat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chat(
      peerPubkeyHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_pubkey_hex'],
      )!,
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
  $ChatsTable createAlias(String alias) {
    return $ChatsTable(attachedDatabase, alias);
  }
}

class Chat extends DataClass implements Insertable<Chat> {
  final String peerPubkeyHex;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final DateTime? bundleSentAt;
  final DateTime? peerBundleReceivedAt;
  const Chat({
    required this.peerPubkeyHex,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.bundleSentAt,
    this.peerBundleReceivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_pubkey_hex'] = Variable<String>(peerPubkeyHex);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastMessageAt != null) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt);
    }
    if (!nullToAbsent || lastMessagePreview != null) {
      map['last_message_preview'] = Variable<String>(lastMessagePreview);
    }
    if (!nullToAbsent || bundleSentAt != null) {
      map['bundle_sent_at'] = Variable<DateTime>(bundleSentAt);
    }
    if (!nullToAbsent || peerBundleReceivedAt != null) {
      map['peer_bundle_received_at'] = Variable<DateTime>(peerBundleReceivedAt);
    }
    return map;
  }

  ChatsCompanion toCompanion(bool nullToAbsent) {
    return ChatsCompanion(
      peerPubkeyHex: Value(peerPubkeyHex),
      createdAt: Value(createdAt),
      lastMessageAt: lastMessageAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageAt),
      lastMessagePreview: lastMessagePreview == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessagePreview),
      bundleSentAt: bundleSentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(bundleSentAt),
      peerBundleReceivedAt: peerBundleReceivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(peerBundleReceivedAt),
    );
  }

  factory Chat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chat(
      peerPubkeyHex: serializer.fromJson<String>(json['peerPubkeyHex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastMessageAt: serializer.fromJson<DateTime?>(json['lastMessageAt']),
      lastMessagePreview: serializer.fromJson<String?>(
        json['lastMessagePreview'],
      ),
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
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastMessageAt': serializer.toJson<DateTime?>(lastMessageAt),
      'lastMessagePreview': serializer.toJson<String?>(lastMessagePreview),
      'bundleSentAt': serializer.toJson<DateTime?>(bundleSentAt),
      'peerBundleReceivedAt': serializer.toJson<DateTime?>(
        peerBundleReceivedAt,
      ),
    };
  }

  Chat copyWith({
    String? peerPubkeyHex,
    DateTime? createdAt,
    Value<DateTime?> lastMessageAt = const Value.absent(),
    Value<String?> lastMessagePreview = const Value.absent(),
    Value<DateTime?> bundleSentAt = const Value.absent(),
    Value<DateTime?> peerBundleReceivedAt = const Value.absent(),
  }) => Chat(
    peerPubkeyHex: peerPubkeyHex ?? this.peerPubkeyHex,
    createdAt: createdAt ?? this.createdAt,
    lastMessageAt: lastMessageAt.present
        ? lastMessageAt.value
        : this.lastMessageAt,
    lastMessagePreview: lastMessagePreview.present
        ? lastMessagePreview.value
        : this.lastMessagePreview,
    bundleSentAt: bundleSentAt.present ? bundleSentAt.value : this.bundleSentAt,
    peerBundleReceivedAt: peerBundleReceivedAt.present
        ? peerBundleReceivedAt.value
        : this.peerBundleReceivedAt,
  );
  Chat copyWithCompanion(ChatsCompanion data) {
    return Chat(
      peerPubkeyHex: data.peerPubkeyHex.present
          ? data.peerPubkeyHex.value
          : this.peerPubkeyHex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
      lastMessagePreview: data.lastMessagePreview.present
          ? data.lastMessagePreview.value
          : this.lastMessagePreview,
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
    return (StringBuffer('Chat(')
          ..write('peerPubkeyHex: $peerPubkeyHex, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('lastMessagePreview: $lastMessagePreview, ')
          ..write('bundleSentAt: $bundleSentAt, ')
          ..write('peerBundleReceivedAt: $peerBundleReceivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    peerPubkeyHex,
    createdAt,
    lastMessageAt,
    lastMessagePreview,
    bundleSentAt,
    peerBundleReceivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chat &&
          other.peerPubkeyHex == this.peerPubkeyHex &&
          other.createdAt == this.createdAt &&
          other.lastMessageAt == this.lastMessageAt &&
          other.lastMessagePreview == this.lastMessagePreview &&
          other.bundleSentAt == this.bundleSentAt &&
          other.peerBundleReceivedAt == this.peerBundleReceivedAt);
}

class ChatsCompanion extends UpdateCompanion<Chat> {
  final Value<String> peerPubkeyHex;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastMessageAt;
  final Value<String?> lastMessagePreview;
  final Value<DateTime?> bundleSentAt;
  final Value<DateTime?> peerBundleReceivedAt;
  final Value<int> rowid;
  const ChatsCompanion({
    this.peerPubkeyHex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.lastMessagePreview = const Value.absent(),
    this.bundleSentAt = const Value.absent(),
    this.peerBundleReceivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatsCompanion.insert({
    required String peerPubkeyHex,
    required DateTime createdAt,
    this.lastMessageAt = const Value.absent(),
    this.lastMessagePreview = const Value.absent(),
    this.bundleSentAt = const Value.absent(),
    this.peerBundleReceivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : peerPubkeyHex = Value(peerPubkeyHex),
       createdAt = Value(createdAt);
  static Insertable<Chat> custom({
    Expression<String>? peerPubkeyHex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastMessageAt,
    Expression<String>? lastMessagePreview,
    Expression<DateTime>? bundleSentAt,
    Expression<DateTime>? peerBundleReceivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerPubkeyHex != null) 'peer_pubkey_hex': peerPubkeyHex,
      if (createdAt != null) 'created_at': createdAt,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt,
      if (lastMessagePreview != null)
        'last_message_preview': lastMessagePreview,
      if (bundleSentAt != null) 'bundle_sent_at': bundleSentAt,
      if (peerBundleReceivedAt != null)
        'peer_bundle_received_at': peerBundleReceivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatsCompanion copyWith({
    Value<String>? peerPubkeyHex,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastMessageAt,
    Value<String?>? lastMessagePreview,
    Value<DateTime?>? bundleSentAt,
    Value<DateTime?>? peerBundleReceivedAt,
    Value<int>? rowid,
  }) {
    return ChatsCompanion(
      peerPubkeyHex: peerPubkeyHex ?? this.peerPubkeyHex,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
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
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastMessageAt.present) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt.value);
    }
    if (lastMessagePreview.present) {
      map['last_message_preview'] = Variable<String>(lastMessagePreview.value);
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
    return (StringBuffer('ChatsCompanion(')
          ..write('peerPubkeyHex: $peerPubkeyHex, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('lastMessagePreview: $lastMessagePreview, ')
          ..write('bundleSentAt: $bundleSentAt, ')
          ..write('peerBundleReceivedAt: $peerBundleReceivedAt, ')
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chatId,
    senderPubkeyHex,
    body,
    lamport,
    sentAt,
    receivedAt,
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
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String chatId;
  final String senderPubkeyHex;
  final String body;
  final int lamport;
  final DateTime sentAt;
  final DateTime? receivedAt;
  const Message({
    required this.id,
    required this.chatId,
    required this.senderPubkeyHex,
    required this.body,
    required this.lamport,
    required this.sentAt,
    this.receivedAt,
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
  }) => Message(
    id: id ?? this.id,
    chatId: chatId ?? this.chatId,
    senderPubkeyHex: senderPubkeyHex ?? this.senderPubkeyHex,
    body: body ?? this.body,
    lamport: lamport ?? this.lamport,
    sentAt: sentAt ?? this.sentAt,
    receivedAt: receivedAt.present ? receivedAt.value : this.receivedAt,
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
          ..write('receivedAt: $receivedAt')
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
          other.receivedAt == this.receivedAt);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> chatId;
  final Value<String> senderPubkeyHex;
  final Value<String> body;
  final Value<int> lamport;
  final Value<DateTime> sentAt;
  final Value<DateTime?> receivedAt;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.senderPubkeyHex = const Value.absent(),
    this.body = const Value.absent(),
    this.lamport = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.receivedAt = const Value.absent(),
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
      Value<int> rowid,
    });
typedef $$ContactsTableUpdateCompanionBuilder =
    ContactsCompanion Function({
      Value<String> pubkeyHex,
      Value<DateTime> addedAt,
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
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion(
                pubkeyHex: pubkeyHex,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pubkeyHex,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion.insert(
                pubkeyHex: pubkeyHex,
                addedAt: addedAt,
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
      required String peerPubkeyHex,
      required DateTime createdAt,
      Value<DateTime?> lastMessageAt,
      Value<String?> lastMessagePreview,
      Value<DateTime?> bundleSentAt,
      Value<DateTime?> peerBundleReceivedAt,
      Value<int> rowid,
    });
typedef $$ChatsTableUpdateCompanionBuilder =
    ChatsCompanion Function({
      Value<String> peerPubkeyHex,
      Value<DateTime> createdAt,
      Value<DateTime?> lastMessageAt,
      Value<String?> lastMessagePreview,
      Value<DateTime?> bundleSentAt,
      Value<DateTime?> peerBundleReceivedAt,
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
  ColumnFilters<String> get peerPubkeyHex => $composableBuilder(
    column: $table.peerPubkeyHex,
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

  ColumnFilters<DateTime> get bundleSentAt => $composableBuilder(
    column: $table.bundleSentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get peerBundleReceivedAt => $composableBuilder(
    column: $table.peerBundleReceivedAt,
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
  ColumnOrderings<String> get peerPubkeyHex => $composableBuilder(
    column: $table.peerPubkeyHex,
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

  ColumnOrderings<DateTime> get bundleSentAt => $composableBuilder(
    column: $table.bundleSentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get peerBundleReceivedAt => $composableBuilder(
    column: $table.peerBundleReceivedAt,
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
  GeneratedColumn<String> get peerPubkeyHex => $composableBuilder(
    column: $table.peerPubkeyHex,
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

  GeneratedColumn<DateTime> get bundleSentAt => $composableBuilder(
    column: $table.bundleSentAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get peerBundleReceivedAt => $composableBuilder(
    column: $table.peerBundleReceivedAt,
    builder: (column) => column,
  );
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
                Value<String> peerPubkeyHex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastMessageAt = const Value.absent(),
                Value<String?> lastMessagePreview = const Value.absent(),
                Value<DateTime?> bundleSentAt = const Value.absent(),
                Value<DateTime?> peerBundleReceivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatsCompanion(
                peerPubkeyHex: peerPubkeyHex,
                createdAt: createdAt,
                lastMessageAt: lastMessageAt,
                lastMessagePreview: lastMessagePreview,
                bundleSentAt: bundleSentAt,
                peerBundleReceivedAt: peerBundleReceivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String peerPubkeyHex,
                required DateTime createdAt,
                Value<DateTime?> lastMessageAt = const Value.absent(),
                Value<String?> lastMessagePreview = const Value.absent(),
                Value<DateTime?> bundleSentAt = const Value.absent(),
                Value<DateTime?> peerBundleReceivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatsCompanion.insert(
                peerPubkeyHex: peerPubkeyHex,
                createdAt: createdAt,
                lastMessageAt: lastMessageAt,
                lastMessagePreview: lastMessagePreview,
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
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                chatId: chatId,
                senderPubkeyHex: senderPubkeyHex,
                body: body,
                lamport: lamport,
                sentAt: sentAt,
                receivedAt: receivedAt,
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
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                chatId: chatId,
                senderPubkeyHex: senderPubkeyHex,
                body: body,
                lamport: lamport,
                sentAt: sentAt,
                receivedAt: receivedAt,
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
