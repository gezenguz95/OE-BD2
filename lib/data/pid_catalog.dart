import 'package:drift/drift.dart';

/// This table holds the “master list” of all OBD-II PIDs you want to support.
class PidCatalog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get mode => text()(); // e.g. "01"
  TextColumn get pid => text()(); // e.g. "0C"
  TextColumn get description => text().withLength(min: 1, max: 255)();
  RealColumn get minValue => real().nullable()(); // e.g. 0.0
  RealColumn get maxValue => real().nullable()(); // e.g. 16383.75
  TextColumn get units => text().nullable()(); // e.g. "rpm"
  TextColumn get formula => text().nullable()(); // e.g. "((A*256)+B)/4"
}
