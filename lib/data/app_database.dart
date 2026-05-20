import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Contacts extends Table {
  TextColumn get pubkeyHex => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {pubkeyHex};
}

class Chats extends Table {
  TextColumn get peerPubkeyHex => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  TextColumn get lastMessagePreview => text().nullable()();
  // Bundle-exchange state (schema v4). Replaces the in-memory
  // _bundleSentTo / _peerBundleReceived sets in MessageService so a background
  // isolate doesn't re-send bundles on every wake.
  DateTimeColumn get bundleSentAt => dateTime().nullable()();
  DateTimeColumn get peerBundleReceivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {peerPubkeyHex};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text()();                // == peerPubkeyHex
  TextColumn get senderPubkeyHex => text()();
  TextColumn get body => text()();
  IntColumn get lamport => integer()();
  DateTimeColumn get sentAt => dateTime()();
  DateTimeColumn get receivedAt => dateTime().nullable()();

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

@DriftDatabase(tables: [
  Contacts,
  Chats,
  Messages,
  LamportSeq,
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
  int get schemaVersion => 4;

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
              await m.addColumn(chats, chats.bundleSentAt);
              await m.addColumn(chats, chats.peerBundleReceivedAt);
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
