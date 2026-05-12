// lib/data/tables.dart
import 'package:drift/drift.dart';

class PidCatalog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get mode => text()();
  TextColumn get pid => text()();
  TextColumn get description => text()();
  RealColumn get minValue => real().nullable()();
  RealColumn get maxValue => real().nullable()();
  TextColumn get unit => text().nullable()();
}

class PidValues extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pidId =>
      integer().customConstraint('REFERENCES pid_catalog(id)')();
  RealColumn get value => real()();
  DateTimeColumn get timeStamp => dateTime().withDefault(currentDateAndTime)();
}

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name =>
      text().withDefault(const Constant('Unnamed Session'))();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endedAt => dateTime().nullable()();
}

class Readings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  IntColumn get pidCatalogId => integer().references(PidCatalog, #id)();
  RealColumn get value => real().nullable()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}
