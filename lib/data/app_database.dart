// lib/data/app_database.dart
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'pid_seeds.dart';
import 'tables.dart';
import 'dao/session_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [PidCatalog, PidValues, Sessions, Readings],
  daos: [SessionDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  late final SessionDao sessionDao = SessionDao(this);

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await batch((b) {
            b.insertAll(pidCatalog, pidSeeds);
          });
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from == 1) {
            await batch((b) {
              b.insertAll(
                pidCatalog,
                pidSeeds,
                mode: InsertMode.insertOrIgnore,
              );
            });
          }
        },
      );

  // Catalog CRUD
  Future<List<PidCatalogData>> getAllPids() => select(pidCatalog).get();
  Future insertCatalog(PidCatalogCompanion p) => into(pidCatalog).insert(p);

  // Values CRUD
  Future insertValue(PidValuesCompanion v) => into(pidValues).insert(v);

  // Stream last N values for a given PID
  Stream<List<PidValue>> watchValuesForPid(int pidId, {int limit = 50}) {
    return (select(pidValues)
          ..where((tbl) => tbl.pidId.equals(pidId))
          ..orderBy([(t) => OrderingTerm.desc(t.timeStamp)])
          ..limit(limit))
        .watch();
  }

  /// Completely clear out all stored PID values (e.g. on new session)
  Future<int> clearSessionValues() {
    return delete(pidValues).go();
  }

  /// Purge any PID values older than [maxAge]
  Future<int> purgeValuesOlderThan(Duration maxAge) {
    final cutoff = DateTime.now().subtract(maxAge);
    return (delete(pidValues)
          ..where((tbl) => tbl.timeStamp.isSmallerThanValue(cutoff)))
        .go();
  }
}

/// Opens the SQLite database file lazily.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'obdreader.sqlite'));
    return NativeDatabase(file);
  });
}

/// Extension to generate mock historical data for testing/demo purposes.
extension MockDataGenerator on AppDatabase {
  /// Inserts [countPerPid] fake entries for each PID in [pidIds],
  /// spaced evenly over the last [duration].
  Future<void> seedMockData({
    required List<int> pidIds,
    Duration duration = const Duration(hours: 1),
    int countPerPid = 50,
  }) async {
    final now = DateTime.now();
    final step = duration.inMilliseconds ~/ countPerPid;

    await batch((b) {
      for (var pidId in pidIds) {
        for (var i = 0; i < countPerPid; i++) {
          final timestamp =
              now.subtract(Duration(milliseconds: step * (countPerPid - i)));
          // generate a sine‐wave between 0 and 1, then scale to maybe 0–100
          final normalized = (sin(2 * pi * i / countPerPid) * 0.5 + 0.5);
          final value = (normalized * 100);

          b.insert(
            pidValues,
            PidValuesCompanion.insert(
              pidId: pidId,
              value: value,
              timeStamp: Value(timestamp),
            ),
          );
        }
      }
    });
  }
}
