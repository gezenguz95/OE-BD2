// Menetnapló mentése — JSON fájl az alkalmazás dokumentumkönyvtárában.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/trip_data.dart';

class TripStorage {
  static const _fileName = 'obd_trips.json';

  static Future<void> _writeChain = Future.value();

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

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
    } catch (e) {
      // Sérült JSON vagy I/O hiba: üres listával tér vissza, hogy az app
      // ne crasheljen, de a hiba nyomon követhető a debug log-ban.
      debugPrint('TripStorage.loadAll error: $e');
      return [];
    }
  }

  static Future<T> _enqueue<T>(Future<T> Function() op) {
    final completer = Completer<T>();
    _writeChain = _writeChain.then((_) async {
      try {
        completer.complete(await op());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static Future<void> _atomicWriteJson(File f, String json) async {
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(f.path);
  }

  static Future<void> save(TripRecord trip) {
    return _enqueue(() async {
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
        final json = jsonEncode(trips.map((t) => t.toJson()).toList());
        await _atomicWriteJson(f, json);
      } catch (e) {
        debugPrint('TripStorage.save error: $e');
      }
    });
  }

  static Future<void> delete(String id) {
    return _enqueue(() async {
      try {
        final trips = await loadAll();
        trips.removeWhere((t) => t.id == id);
        final f = await _file();
        final json = jsonEncode(trips.map((t) => t.toJson()).toList());
        await _atomicWriteJson(f, json);
      } catch (e) {
        debugPrint('TripStorage.delete error: $e');
      }
    });
  }

  static Future<void> deleteAll() {
    return _enqueue(() async {
      try {
        final f = await _file();
        await _atomicWriteJson(f, '[]');
      } catch (e) {
        debugPrint('TripStorage.deleteAll error: $e');
      }
    });
  }
}
