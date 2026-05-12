import 'dart:io';

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

  // Katalógus műveletek
  Future<List<PidCatalogData>> getAllPids() => select(pidCatalog).get();
  Future insertCatalog(PidCatalogCompanion p) => into(pidCatalog).insert(p);

  // Mért értékek beszúrása
  Future insertValue(PidValuesCompanion v) => into(pidValues).insert(v);

  // Egy adott PID-hez az utolsó N érték figyelése (Stream)
  Stream<List<PidValue>> watchValuesForPid(int pidId, {int limit = 50}) {
    return (select(pidValues)
          ..where((tbl) => tbl.pidId.equals(pidId))
          ..orderBy([(t) => OrderingTerm.desc(t.timeStamp)])
          ..limit(limit))
        .watch();
  }

  /// Az összes tárolt PID érték törlése (pl. új munkamenet indításakor).
  Future<int> clearSessionValues() {
    return delete(pidValues).go();
  }

  /// A [maxAge]-nél régebbi PID értékek törlése.
  Future<int> purgeValuesOlderThan(Duration maxAge) {
    final cutoff = DateTime.now().subtract(maxAge);
    return (delete(pidValues)
          ..where((tbl) => tbl.timeStamp.isSmallerThanValue(cutoff)))
        .go();
  }
}

/// Az SQLite adatbázis fájl lusta megnyitása (csak első hozzáféréskor).
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'obdreader.sqlite'));
    return NativeDatabase(file);
  });
}
