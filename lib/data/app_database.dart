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

@DriftDatabase(tables: [Contacts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Use in tests with `NativeDatabase.memory()` to get an isolated in-memory DB.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'hb_v3.sqlite'));
    return NativeDatabase(file);
  });
}
