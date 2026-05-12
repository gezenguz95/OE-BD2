import 'package:drift/drift.dart';
import '../app_database.dart'; // Needed to extend DatabaseAccessor<AppDatabase>
import '../tables.dart'; // ✅ Required to bring in Sessions and Readings

part 'session_dao.g.dart';

@DriftAccessor(tables: [Sessions, Readings])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(AppDatabase db) : super(db);

  Future<int> startSession(String name) {
    return into(sessions).insert(SessionsCompanion(
      name: Value(name),
      startedAt: Value(DateTime.now()),
    ));
  }

  Future<void> endSession(int id) {
    return (update(sessions)..where((tbl) => tbl.id.equals(id))).write(
      SessionsCompanion(endedAt: Value(DateTime.now())),
    );
  }

  Future<void> insertReading({
    required int sessionId,
    required int pidCatalogId,
    required double value,
  }) {
    return into(readings).insert(ReadingsCompanion(
      sessionId: Value(sessionId),
      pidCatalogId: Value(pidCatalogId),
      value: Value(value),
      timestamp: Value(DateTime.now()),
    ));
  }

  Future<int> purgeOldSessions(Duration keepDuration) async {
    final cutoff = DateTime.now().subtract(keepDuration);

    final oldSessions = await (select(sessions)
          ..where((s) => s.startedAt.isSmallerThanValue(cutoff)))
        .get();

    for (final s in oldSessions) {
      await transaction(() async {
        await (delete(readings)..where((r) => r.sessionId.equals(s.id))).go();
        await (delete(sessions)..where((sess) => sess.id.equals(s.id))).go();
      });
    }

    return oldSessions.length;
  }
}
