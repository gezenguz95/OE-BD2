// lib/services/trip_storage.dart
//
// JSON fájl alapú menetnapló perzisztencia.
// Helye: {ApplicationDocumentsDirectory}/obd_trips.json

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/trip_data.dart';

class TripStorage {
  static const _fileName = 'obd_trips.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Visszaad minden mentett menetet, legfrissebb elöl.
  static Future<List<TripRecord>> loadAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final content = await f.readAsString();
      if (content.isEmpty) return [];
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => TripRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Ment vagy frissít egy menetet (id alapján).
  static Future<void> save(TripRecord trip) async {
    try {
      final trips = await loadAll();
      final idx = trips.indexWhere((t) => t.id == trip.id);
      if (idx >= 0) {
        trips[idx] = trip;
      } else {
        trips.add(trip);
      }
      trips.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      final f = await _file();
      await f.writeAsString(
          jsonEncode(trips.map((t) => t.toJson()).toList()));
    } catch (_) {}
  }

  /// Töröl egy menetet id alapján.
  static Future<void> delete(String id) async {
    try {
      final trips = await loadAll();
      trips.removeWhere((t) => t.id == id);
      final f = await _file();
      await f.writeAsString(
          jsonEncode(trips.map((t) => t.toJson()).toList()));
    } catch (_) {}
  }

  /// Törli az összes menetet.
  static Future<void> deleteAll() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.writeAsString('[]');
    } catch (_) {}
  }
}
