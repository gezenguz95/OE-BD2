// lib/services/app_settings.dart
//
// Singleton – alkalmazásbeállítások SharedPreferences-ben tárolva.
// Használat:
//   await AppSettings().init();      // egyszer, pl. main()-ben
//   final s = AppSettings();
//   s.whPerKmFallback                // getter
//   await s.setWhPerKm(true, 165.0); // setter (async)

import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  // ── Singleton ──────────────────────────────────────────────────────────
  static final AppSettings _instance = AppSettings._();
  factory AppSettings() => _instance;
  AppSettings._();

  SharedPreferences? _prefs;
  bool _loaded = false;

  /// Betölti a beállításokat. Hívd meg a main()-ben / initState-ben.
  Future<void> init() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    _loaded = true;
  }

  T _get<T>(String key, T def) {
    final p = _prefs;
    if (p == null) return def;
    if (T == bool) return (p.getBool(key) ?? def) as T;
    if (T == double) return (p.getDouble(key) ?? def) as T;
    if (T == int) return (p.getInt(key) ?? def) as T;
    if (T == String) return (p.getString(key) ?? def) as T;
    return def;
  }

  Future<void> _set<T>(String key, T value) async {
    await init();
    final p = _prefs!;
    if (value is bool) await p.setBool(key, value);
    else if (value is double) await p.setDouble(key, value);
    else if (value is int) await p.setInt(key, value);
    else if (value is String) await p.setString(key, value);
  }

  // ══ Fogyasztás ═══════════════════════════════════════════════════════════
  // Automatikus tanulási mód vagy manuális felülbírálat.

  static const _kWhPerKmEnabled = 'whPerKmOverrideEnabled';
  static const _kWhPerKmValue   = 'whPerKmOverrideValue';

  /// Ha igaz: a lenti whPerKmFallback értéket használja, nem a tanult átlagot.
  bool  get whPerKmOverrideEnabled => _get<bool>(_kWhPerKmEnabled, false);
  /// Manuális fogyasztás-norma (Wh/km). Default: 170.
  double get whPerKmFallback       => _get<double>(_kWhPerKmValue, 170.0);

  Future<void> setWhPerKm(bool enabled, double value) async {
    await _set(_kWhPerKmEnabled, enabled);
    await _set(_kWhPerKmValue, value);
  }

  // ══ Mértékegységek ════════════════════════════════════════════════════════

  static const _kImperial    = 'useImperial';
  static const _kFahrenheit  = 'useFahrenheit';

  /// Igaz → mérföld, gallon. Hamis (default) → km, liter.
  bool get useImperial   => _get<bool>(_kImperial, false);
  /// Igaz → °F. Hamis (default) → °C.
  bool get useFahrenheit => _get<bool>(_kFahrenheit, false);

  Future<void> setUnits({required bool imperial, required bool fahrenheit}) async {
    await _set(_kImperial, imperial);
    await _set(_kFahrenheit, fahrenheit);
  }

  // ══ Riasztási küszöbök ════════════════════════════════════════════════════

  static const _kSocMin      = 'alertSocMin';
  static const _kTempMax     = 'alertTempMax';
  static const _kCellSpread  = 'alertCellSpread';

  /// SOC riasztási szint (%). Default: 15.
  double get alertSocMin     => _get<double>(_kSocMin, 15.0);
  /// Hőmérséklet riasztás (°C). Default: 40.
  double get alertTempMax    => _get<double>(_kTempMax, 40.0);
  /// Cellaegyensúly riasztás (mV). Default: 50.
  double get alertCellSpread => _get<double>(_kCellSpread, 50.0);

  Future<void> setAlerts({
    double? socMin,
    double? tempMax,
    double? cellSpread,
  }) async {
    if (socMin     != null) await _set(_kSocMin, socMin);
    if (tempMax    != null) await _set(_kTempMax, tempMax);
    if (cellSpread != null) await _set(_kCellSpread, cellSpread);
  }

  // ══ Segédszámítások ═══════════════════════════════════════════════════════

  /// Hőmérséklet konverzió a beállítások szerint.
  double displayTemp(double celsius) =>
      useFahrenheit ? celsius * 9 / 5 + 32 : celsius;

  String get tempUnit => useFahrenheit ? '°F' : '°C';

  /// Sebesség konverzió a beállítások szerint.
  double displaySpeed(double kmh) => useImperial ? kmh * 0.621371 : kmh;
  String get speedUnit => useImperial ? 'mph' : 'km/h';

  /// Távolság konverzió a beállítások szerint.
  double displayDist(double km) => useImperial ? km * 0.621371 : km;
  String get distUnit => useImperial ? 'mi' : 'km';
}
