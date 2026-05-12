import 'package:drift/drift.dart';

/// Támogatott OBD-II PID-ek katalógusa.
class PidCatalog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get mode => text()(); // pl. "01"
  TextColumn get pid => text()(); // pl. "0C"
  TextColumn get description => text().withLength(min: 1, max: 255)();
  RealColumn get minValue => real().nullable()(); // pl. 0.0
  RealColumn get maxValue => real().nullable()(); // pl. 16383.75
  TextColumn get units => text().nullable()(); // pl. "rpm"
  TextColumn get formula => text().nullable()(); // pl. "((A*256)+B)/4"
}
