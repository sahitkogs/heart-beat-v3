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

@DriftDatabase(tables: [Contacts, Chats, Messages, LamportSeq])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Use in tests with `NativeDatabase.memory()` to get an isolated in-memory DB.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from == 1 && to == 2) {
            await m.createTable(chats);
            await m.createTable(messages);
            await m.createTable(lamportSeq);
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
