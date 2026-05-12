//
// Témaváltó ChangeNotifier: rendszer / világos / sötét módot kezel.
// Változáskor azonnal értesíti a hallgatókat, és aszinkron módon menti az AppSettings-be.

import 'package:flutter/material.dart';
import 'app_settings.dart';

/// Témaállapot kezelője — értesíti a hallgatókat és perzisztálja a beállítást.
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode;

  ThemeNotifier(int savedMode) : _mode = _fromInt(savedMode);

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    // Az UI-t azonnal értesítjük, a mentés háttérben történik.
    // Fordított sorrend esetén (await → notify) egy sikertelen SharedPrefs írás megakadályozta volna a UI frissítését is.
    notifyListeners();
    try {
      await AppSettings().setThemeMode(_toInt(mode));
    } catch (e) {
      debugPrint('ThemeNotifier persist failed: $e');
    }
  }

  static ThemeMode _fromInt(int v) {
    if (v == 1) return ThemeMode.light;
    if (v == 2) return ThemeMode.dark;
    return ThemeMode.system;
  }

  static int _toInt(ThemeMode m) {
    if (m == ThemeMode.light) return 1;
    if (m == ThemeMode.dark) return 2;
    return 0;
  }
}
