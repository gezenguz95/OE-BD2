import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static final AppSettings _instance = AppSettings._();
  factory AppSettings() => _instance;
  AppSettings._();

  SharedPreferences? _prefs;
  Future<void>? _initFuture;

  Future<void> init() {
    _initFuture ??= SharedPreferences.getInstance().then((p) => _prefs = p);
    return _initFuture!;
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
    if (value is bool)        { await p.setBool(key, value); }
    else if (value is double) { await p.setDouble(key, value); }
    else if (value is int)    { await p.setInt(key, value); }
    else if (value is String) { await p.setString(key, value); }
  }

  static const _kWhPerKmValue   = 'whPerKmOverrideValue';
  static const _kRangeMode      = 'rangeEstimationMode';

  int get rangeMode => _get<int>(_kRangeMode, 0);
  bool get whPerKmOverrideEnabled => rangeMode == 2;
  double get whPerKmFallback => _get<double>(_kWhPerKmValue, 140.0);

  Future<void> setRangeMode(int mode) async => _set(_kRangeMode, mode);

  Future<void> setWhPerKm(bool enabled, double value) async {
    await _set(_kRangeMode, enabled ? 2 : (rangeMode == 2 ? 0 : rangeMode));
    await _set(_kWhPerKmValue, value);
  }

  Future<void> setWhPerKmValue(double value) async =>
      _set(_kWhPerKmValue, value);

  static const _kImperial    = 'useImperial';
  static const _kFahrenheit  = 'useFahrenheit';

  bool get useImperial   => _get<bool>(_kImperial, false);
  bool get useFahrenheit => _get<bool>(_kFahrenheit, false);

  Future<void> setUnits({required bool imperial, required bool fahrenheit}) async {
    await _set(_kImperial, imperial);
    await _set(_kFahrenheit, fahrenheit);
  }

  static const _kSocMin      = 'alertSocMin';
  static const _kTempMax     = 'alertTempMax';
  static const _kCellSpread  = 'alertCellSpread';
  // ICE-specifikus riasztási küszöbök
  static const _kCoolantMax  = 'alertCoolantMax';
  static const _kFuelMin     = 'alertFuelMin';

  double get alertSocMin     => _get<double>(_kSocMin, 15.0);
  double get alertTempMax    => _get<double>(_kTempMax, 40.0);
  double get alertCellSpread => _get<double>(_kCellSpread, 50.0);
  double get alertCoolantMax => _get<double>(_kCoolantMax, 105.0);
  double get alertFuelMin    => _get<double>(_kFuelMin, 10.0);

  Future<void> setAlerts({
    double? socMin,
    double? tempMax,
    double? cellSpread,
    double? coolantMax,
    double? fuelMin,
  }) async {
    if (socMin     != null) await _set(_kSocMin, socMin);
    if (tempMax    != null) await _set(_kTempMax, tempMax);
    if (cellSpread != null) await _set(_kCellSpread, cellSpread);
    if (coolantMax != null) await _set(_kCoolantMax, coolantMax);
    if (fuelMin    != null) await _set(_kFuelMin, fuelMin);
  }

  static const _kAutoConnect       = 'autoConnectEnabled';
  static const _kLastDeviceAddress = 'lastDeviceAddress';
  static const _kLastDeviceName    = 'lastDeviceName';
  static const _kLastConnType      = 'lastConnectionType'; // értéke: 'classic' vagy 'ble'
  static const _kLastProfileId     = 'lastProfileId';

  bool get autoConnectEnabled  => _get<bool>(_kAutoConnect, false);
  String get lastDeviceAddress => _get<String>(_kLastDeviceAddress, '');
  String get lastDeviceName    => _get<String>(_kLastDeviceName, '');
  String get lastConnectionType => _get<String>(_kLastConnType, 'classic');
  String get lastProfileId     => _get<String>(_kLastProfileId, '');

  Future<void> setAutoConnect(bool enabled) async =>
      _set(_kAutoConnect, enabled);

  Future<void> saveLastDevice({
    required String address,
    required String name,
    required String connType,
    required String profileId,
  }) async {
    await _set(_kLastDeviceAddress, address);
    await _set(_kLastDeviceName, name);
    await _set(_kLastConnType, connType);
    await _set(_kLastProfileId, profileId);
  }

  // Külső hőmérséklet lekérés engedélyezése (IP-geolokáció + Open-Meteo).
  // Ha kikapcsolva: az alkalmazás nem küld kérést harmadik fél szerverére,
  // a hőmérséklet-alapú hatótáv-becslés inaktív lesz.
  static const _kWeatherEnabled = 'weatherEnabled';
  bool get weatherEnabled => _get<bool>(_kWeatherEnabled, true);
  Future<void> setWeatherEnabled(bool enabled) async =>
      _set(_kWeatherEnabled, enabled);

  static const _kThemeMode    = 'themeMode';
  static const _kLanguageCode = 'languageCode';

  int get themeMode => _get<int>(_kThemeMode, 0);
  Future<void> setThemeMode(int mode) async => _set(_kThemeMode, mode);

  String get languageCode => _get<String>(_kLanguageCode, 'hu');
  Future<void> setLanguageCode(String code) async => _set(_kLanguageCode, code);

  double displayTemp(double celsius) =>
      useFahrenheit ? celsius * 9 / 5 + 32 : celsius;

  String get tempUnit => useFahrenheit ? '°F' : '°C';

  double displaySpeed(double kmh) => useImperial ? kmh * 0.621371 : kmh;
  String get speedUnit => useImperial ? 'mph' : 'km/h';

  double displayDist(double km) => useImperial ? km * 0.621371 : km;
  String get distUnit => useImperial ? 'mi' : 'km';
}
