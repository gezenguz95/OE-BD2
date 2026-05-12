// Töltési session perzisztencia — JSON fájlba írva.
// Fájl helye: {ApplicationDocumentsDirectory}/obd_charges.json
//
// Ugyanaz az atomic write + single-writer lánc minta, mint a TripStorage-ban.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/charge_data.dart';

class ChargeStorage {
  static const _fileName = 'obd_charges.json';

  /// Egyetlen writer-lánc a versenyhelyzet ellen (TOCTOU védelem).
  static Future<void> _writeChain = Future.value();

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Visszaadja az összes rögzített töltési sessiont, legfrissebb elöl.
  static Future<List<ChargeSession>> loadAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final content = await f.readAsString();
      if (content.isEmpty) return [];
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => ChargeSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Sorba állítja a műveletet a single-writer láncon.
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

  /// Atomi fájlcsere: temp fájl → rename.
  static Future<void> _atomicWrite(File f, String json) async {
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(f.path);
  }

  /// Menti vagy frissíti a töltési sessiont (azonosító alapján upsert).
  static Future<void> save(ChargeSession session) {
    return _enqueue(() async {
      try {
        final sessions = await loadAll();
        final idx = sessions.indexWhere((s) => s.id == session.id);
        if (idx >= 0) {
          sessions[idx] = session;
        } else {
          sessions.add(session);
        }
        sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
        final f = await _file();
        final json = jsonEncode(sessions.map((s) => s.toJson()).toList());
        await _atomicWrite(f, json);
      } catch (e) {
        debugPrint('ChargeStorage.save error: $e');
      }
    });
  }

  /// Töröl egy sessiont azonosító alapján.
  static Future<void> delete(String id) {
    return _enqueue(() async {
      try {
        final sessions = await loadAll();
        sessions.removeWhere((s) => s.id == id);
        final f = await _file();
        final json = jsonEncode(sessions.map((s) => s.toJson()).toList());
        await _atomicWrite(f, json);
      } catch (e) {
        debugPrint('ChargeStorage.delete error: $e');
      }
    });
  }
}
