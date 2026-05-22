import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Contacts extends Table {
  TextColumn get pubkeyHex => text()();
  DateTimeColumn get addedAt => dateTime()();
  // User-chosen nickname for this peer. Wins over claimedName in
  // resolveName() — once the user typed a nickname (or kept the
  // auto-filled one), peer-broadcasted name changes do not override.
  TextColumn get displayName => text().nullable()();
  // Last broadcast name received from this peer via an inbound
  // envelope's senderDisplayName field. Informational, not
  // authenticated beyond the libsignal-session sender binding.
  TextColumn get claimedName => text().nullable()();

  @override
  Set<Column> get primaryKey => {pubkeyHex};
}

/// Singleton row (id == 0) holding the local user's display name.
/// Created the first time the user passes through DisplayNameSetupScreen
/// on first launch. Row presence is the signal "displayName has been set."
class Profile extends Table {
  IntColumn get id => integer()();
  TextColumn get displayName => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Chats extends Table {
  TextColumn get chatId => text()();
  TextColumn get kind => text().withDefault(const Constant('direct'))();
  TextColumn get groupName => text().nullable()();
  TextColumn get creatorPubkeyHex => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  TextColumn get lastMessagePreview => text().nullable()();
  DateTimeColumn get leftAt => dateTime().nullable()();
  IntColumn get lastOpSeq => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {chatId};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text()();
  TextColumn get senderPubkeyHex => text()();
  TextColumn get body => text()();
  IntColumn get lamport => integer()();
  DateTimeColumn get sentAt => dateTime()();
  DateTimeColumn get receivedAt => dateTime().nullable()();
  TextColumn get kind => text().withDefault(const Constant('text'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LamportSeq extends Table {
  TextColumn get chatId => text()();                // == peerPubkeyHex
  IntColumn get value => integer()();

  @override
  Set<Column> get primaryKey => {chatId};
}

// ---------- libsignal protocol store (schema v3) ----------
//
// Each row holds a serialized libsignal record (record.serialize() -> Uint8List).
// Reconstructed lazily inside the Dart store implementations (T2.4-T2.9).

/// Singleton row (id == 0) holding the local identity keypair, the libsignal
/// registration id, and the device id. Created on first launch when the
/// libsignal store boots.
class SignalIdentity extends Table {
  IntColumn get id => integer()();
  BlobColumn get identityKeyPair => blob()();
  IntColumn get registrationId => integer()();
  IntColumn get deviceId => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One-time pre-keys. Consumed by libsignal once a session is built; rows are
/// deleted as the keys are used.
class SignalPreKeys extends Table {
  IntColumn get keyId => integer()();
  BlobColumn get record => blob()();

  @override
  Set<Column> get primaryKey => {keyId};
}

/// Long-lived signed pre-key. In 1:1 Heartbeat we keep a single row; multi-
/// peer rotation lands in 10.4/10.5.
class SignalSignedPreKeys extends Table {
  IntColumn get keyId => integer()();
  BlobColumn get record => blob()();

  @override
  Set<Column> get primaryKey => {keyId};
}

/// libsignal sessions keyed by the address string `"pubkeyHex:deviceId"` so
/// drift can use it as a TEXT primary key without a composite index.
class SignalSessions extends Table {
  TextColumn get address => text()();
  BlobColumn get record => blob()();

  @override
  Set<Column> get primaryKey => {address};
}

/// The peer's identity public key + our trust decision for it. libsignal asks
/// for this during `isTrustedIdentity` and updates it on `saveIdentity`.
class SignalPeerIdentities extends Table {
  TextColumn get peerPubkeyHex => text()();
  BlobColumn get identityKey => blob()();
  BoolColumn get trusted => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {peerPubkeyHex};
}

class GroupMembers extends Table {
  TextColumn get chatId => text()();
  TextColumn get memberPubkeyHex => text()();
  DateTimeColumn get addedAt => dateTime()();
  TextColumn get addedByPubkeyHex => text()();
  DateTimeColumn get removedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {chatId, memberPubkeyHex};
}

class GroupOpsLog extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text()();
  IntColumn get opSeq => integer().nullable()();
  TextColumn get kind => text()();
  TextColumn get targetPubkeyHex => text().nullable()();
  TextColumn get signerPubkeyHex => text()();
  TextColumn get signatureHex => text()();
  DateTimeColumn get receivedAt => dateTime()();
  BoolColumn get applied => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

class PeerBundleState extends Table {
  TextColumn get peerPubkeyHex => text()();
  DateTimeColumn get bundleSentAt => dateTime().nullable()();
  DateTimeColumn get peerBundleReceivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {peerPubkeyHex};
}

@DriftDatabase(tables: [
  Contacts,
  Chats,
  Messages,
  LamportSeq,
  GroupMembers,
  GroupOpsLog,
  PeerBundleState,
  Profile,
  SignalIdentity,
  SignalPreKeys,
  SignalSignedPreKeys,
  SignalSessions,
  SignalPeerIdentities,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Use in tests with `NativeDatabase.memory()` to get an isolated in-memory DB.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Step-by-step so any (from, to) gap is covered, not just adjacent
          // versions. Drift calls onUpgrade once per upgrade.
          for (var v = from; v < to; v++) {
            if (v == 1) {
              await m.createTable(chats);
              await m.createTable(messages);
              await m.createTable(lamportSeq);
            } else if (v == 2) {
              await m.createTable(signalIdentity);
              await m.createTable(signalPreKeys);
              await m.createTable(signalSignedPreKeys);
              await m.createTable(signalSessions);
              await m.createTable(signalPeerIdentities);
            } else if (v == 3) {
              // Original 10.3 T3.3 step added these columns to the v3-shape `chats` table
              // (which had `peer_pubkey_hex` as PK and no bundle columns). The columns are
              // dropped again by the v==4 step's table rebuild, but they must exist in the
              // intermediate state because v==4's INSERT INTO peer_bundle_state reads them.
              //
              // Done via raw SQL because the Chats Dart class has been re-shaped for v5
              // and no longer has bundleSentAt / peerBundleReceivedAt members, so
              // `m.addColumn(chats, chats.bundleSentAt)` won't compile here.
              await customStatement('ALTER TABLE chats ADD COLUMN bundle_sent_at INTEGER');
              await customStatement('ALTER TABLE chats ADD COLUMN peer_bundle_received_at INTEGER');
            } else if (v == 4) {
              // Atomic v4 -> v5 migration (one transaction, drift wraps onUpgrade).
              await m.createTable(groupMembers);
              await m.createTable(groupOpsLog);
              await m.createTable(peerBundleState);

              // Copy bundle state from chats -> peer_bundle_state.
              await customStatement('''
                INSERT INTO peer_bundle_state (peer_pubkey_hex, bundle_sent_at, peer_bundle_received_at)
                SELECT peer_pubkey_hex, bundle_sent_at, peer_bundle_received_at
                FROM chats
              ''');

              // Rebuild chats with new column shape.
              await customStatement('ALTER TABLE chats RENAME TO chats_v4');
              await m.createTable(chats);
              await customStatement('''
                INSERT INTO chats (chat_id, kind, group_name, creator_pubkey_hex, created_at,
                                   last_message_at, last_message_preview, left_at, last_op_seq)
                SELECT peer_pubkey_hex, 'direct', NULL, NULL, created_at,
                       last_message_at, last_message_preview, NULL, 0
                FROM chats_v4
              ''');
              await customStatement('DROP TABLE chats_v4');

              // Add the kind column to messages.
              await m.addColumn(messages, messages.kind);
            } else if (v == 5) {
              // Destructive v5 -> v6 per spec §2.3. User explicitly opted
              // out of backward compatibility; v3 is still dev-only.
              for (final t in const [
                'messages',
                'chats',
                'contacts',
                'group_members',
                'group_ops_log',
                'peer_bundle_state',
                'lamport_seq',
                'signal_identity',
                'signal_pre_keys',
                'signal_signed_pre_keys',
                'signal_sessions',
                'signal_peer_identities',
              ]) {
                await customStatement('DROP TABLE IF EXISTS $t');
              }
              // createAll recreates every table from the current (v6) schema.
              await m.createAll();
            }
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'hb_v3.sqlite'));
    return NativeDatabase(file);
  });
}
