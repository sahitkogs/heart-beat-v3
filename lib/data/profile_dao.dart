import 'package:drift/drift.dart';
import 'app_database.dart';

part 'profile_dao.g.dart';

/// Singleton-row DAO for the local user's profile (display name, etc.).
/// Row id is always 0. setDisplayName upserts.
@DriftAccessor(tables: [Profile])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  Future<ProfileData?> get() =>
      (select(profile)..where((t) => t.id.equals(0))).getSingleOrNull();

  Stream<ProfileData?> watch() =>
      (select(profile)..where((t) => t.id.equals(0))).watchSingleOrNull();

  Future<void> setDisplayName(String name, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    await into(profile).insertOnConflictUpdate(
      ProfileCompanion.insert(
        id: const Value(0),
        displayName: name,
        updatedAt: now,
      ),
    );
  }
}
