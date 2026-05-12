//
// IP-alapú kültéri hőmérséklet lekérés – Open-Meteo API (kulcs nélkül).
//
// ADATVÉDELMI MEGJEGYZÉS:
//   A jelenlegi kérés a felhasználó publikus IP-jét két harmadik fél szervere
//   felé továbbítja:
//     1) ipapi.co – IP-alapú geolokáció (kb. város szintű pontosság)
//     2) api.open-meteo.com – aktuális hőmérséklet a koordinátákhoz
//
//   Sem fiók, sem API kulcs nem szükséges; az IP-cím viszont elhagyja a
//   készüléket. A felhasználó az AppSettings.weatherEnabled kapcsolóval
//   teljesen letilthatja ezt a funkciót — a hőmérséklet-alapú hatótáv
//   becslés ekkor inaktív marad.
//
// Gyorsítótár: 15 perc. A hálózati hibákat csendesen elnyeli, hogy ne blokkolja
// a UI-t.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_settings.dart';

class WeatherService {
  static final _instance = WeatherService._();
  factory WeatherService() => _instance;
  WeatherService._();

  double? _cachedTemp;
  DateTime? _lastFetch;

  // Folyamatban lévő fetch Future-ja: párhuzamos hívók ehhez csatlakoznak,
  // hogy ne induljon el több HTTP kérés ugyanarra az adatra egyszerre.
  Future<double?>? _inflight;

  static const _cacheDuration = Duration(minutes: 15);

  /// Utoljára ismert kültéri hőmérséklet (°C). Null ha még nem volt lekérdezés.
  double? get lastTemperature => _cachedTemp;

  /// Kültéri hőmérséklet alapján számított EV hatékonysági szorzó.
  /// 1.0 = optimális (20°C); valós EV méréseken alapuló darabos-lineáris modell.
  static double efficiencyFactor(double tempC) {
    const List<double> temps = [-25, -10,  0, 10,  20,  30,  40];
    const List<double> effs  = [0.50, 0.68, 0.81, 0.91, 1.00, 0.97, 0.94];
    if (tempC <= temps.first) return effs.first;
    if (tempC >= temps.last)  return effs.last;
    for (int i = 0; i < temps.length - 1; i++) {
      if (tempC >= temps[i] && tempC < temps[i + 1]) {
        final t = (tempC - temps[i]) / (temps[i + 1] - temps[i]);
        return effs[i] + t * (effs[i + 1] - effs[i]);
      }
    }
    return 1.0;
  }

  /// Lekéri az aktuális kültéri hőmérsékletet IP geolokáció + Open-Meteo segítségével.
  /// Nincs internetkapcsolat esetén null-lal tér vissza.
  /// Ha a felhasználó az AppSettings-ben kikapcsolta a hőmérséklet lekérést,
  /// szintén null-lal tér vissza (nincs hálózati kérés).
  /// Újra-belépés védett: folyamatban lévő fetch esetén ugyanazt a Future-t adja vissza.
  Future<double?> fetchTemperature() {
    // Adatvédelmi opt-out: ha a felhasználó kikapcsolta, nem küldünk kérést.
    if (!AppSettings().weatherEnabled) {
      return Future.value(null);
    }

    // Cache találat: nem kell új kérés
    if (_cachedTemp != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return Future.value(_cachedTemp);
    }

    // Már fut egy fetch: csatlakozunk hozzá, nem indítunk újat
    final existing = _inflight;
    if (existing != null) return existing;

    final future = _doFetch();
    _inflight = future;
    // Befejezéskor töröljük a referenciát (akár siker, akár hiba)
    future.whenComplete(() {
      if (identical(_inflight, future)) {
        _inflight = null;
      }
    });
    return future;
  }

  Future<double?> _doFetch() async {
    try {
      // 1. lépés: koordináták lekérése IP-alapú geolokációval
      final geoResp = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 8));

      if (geoResp.statusCode != 200) return null;

      final dynamic geoDecoded = jsonDecode(geoResp.body);
      if (geoDecoded is! Map<String, dynamic>) return null;
      final lat = (geoDecoded['latitude'] as num?)?.toDouble();
      final lon = (geoDecoded['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;

      // 2. lépés: aktuális hőmérséklet lekérése Open-Meteo-tól
      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${lat.toStringAsFixed(3)}'
        '&longitude=${lon.toStringAsFixed(3)}'
        '&current_weather=true',
      );

      final weatherResp =
          await http.get(weatherUri).timeout(const Duration(seconds: 10));
      if (weatherResp.statusCode != 200) return null;

      final dynamic decoded = jsonDecode(weatherResp.body);
      if (decoded is! Map<String, dynamic>) return null;
      final cw = decoded['current_weather'];
      if (cw is! Map<String, dynamic>) return null;
      final tempVal = cw['temperature'];
      if (tempVal is! num) return null;

      final temp = tempVal.toDouble();
      _cachedTemp = temp;
      _lastFetch  = DateTime.now();
      return temp;
    } catch (e) {
      // Hálózati hiba: csendesen null-lal tér vissza, nem blokkol
      debugPrint('WeatherService fetch error: $e');
      return null;
    }
  }
}
