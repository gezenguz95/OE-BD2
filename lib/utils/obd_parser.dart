//
// ELM327 nyers hex válaszok feldolgozása OBD-II PID értékekké.
// Mode 01 PID-eket kezeli: belső égésű és EV szenzoradatok.

import 'file_logger.dart';

class ObdParser {
  /// Megtisztítja a nyers ELM327 választ: eltávolítja a '>' promptot, sortöréseket, és normalizálja a szóközöket.
  static String filterResponse(String raw) {
    if (raw.isEmpty) return '';
    String s = raw
        .replaceAll('>', '')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\t', ' ');
    s = s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).join(' ').trim();
    return s;
  }

  static bool _isEmptyOrNoData(String cleaned) {
    if (cleaned.isEmpty) return true;
    final upper = cleaned.toUpperCase();
    return upper == 'NO DATA' || upper.contains('NO DATA');
  }

  /// Szétbontja a megtisztított stringet 2 karakteres hex byte listává.
  /// Kezeli a szóközzel elválasztott ("41 0C 1A F8") és összefűzött ("410C1AF8") formátumot is.
  static List<String> _toHexBytes(String cleaned) {
    final parts = cleaned.split(RegExp(r'\s+'));
    final result = <String>[];
    for (final p in parts) {
      final s = p.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
      if (s.isEmpty) continue;
      if (s.length == 2) {
        result.add(s);
      } else {
        for (int i = 0; i < s.length; i += 2) {
          if (i + 2 <= s.length) result.add(s.substring(i, i + 2));
        }
      }
    }
    return result;
  }

  /// Megkeresi a Mode 01 válasz (41 + PID) pozícióját a byte listában.
  /// Visszatér a fejléc utáni első adatbyte indexével, vagy -1-gyel, ha nem találja.
  static int _findMode01DataStart(List<String> bytes, String pid) {
    final pidUpper = pid.toUpperCase();
    for (int i = 0; i < bytes.length - 1; i++) {
      if (bytes[i].toUpperCase() == '41' &&
          bytes[i + 1].toUpperCase() == pidUpper) {
        return i + 2;
      }
    }
    return -1;
  }

  /// Fordulatsszám (PID 0C) feldolgozása. Várja a "41 0C A B" Mode 01 választ.
  static String parseRPM(String data) {
    return parseGeneric(data, '0C');
  }

  /// Sebesség (PID 0D) feldolgozása. Várja a "41 0D A" Mode 01 választ.
  static String parseSpeed(String data) {
    return parseGeneric(data, '0D');
  }

  /// PID-et 2 karakteres nagybetűs formára hozza (pl. "05", "0C").
  static String _normalizePid(String pid) {
    final p = pid.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (p.length >= 2) return p.substring(p.length - 2).toUpperCase();
    return p.padLeft(2, '0').toUpperCase();
  }

  /// Általános Mode 01 PID feldolgozó. [pid]: 2 karakteres PID (pl. "05", "0C").
  /// Ismeretlen PID esetén a nyers hex byte-okat adja vissza hibakereséshez.
  static String parseGeneric(String data, String pid) {
    final cleaned = filterResponse(data);
    if (_isEmptyOrNoData(cleaned)) return '--';
    try {
      final bytes = _toHexBytes(cleaned);
      final pidNorm = _normalizePid(pid);
      final start = _findMode01DataStart(bytes, pidNorm);
      if (start < 0) return _rawHex(bytes, start);
      switch (pidNorm) {
        case '04': // Calculated Engine Load
          if (start >= bytes.length) return '--';
          return ((int.parse(bytes[start], radix: 16) * 100) / 255)
              .toStringAsFixed(1);
        case '05': // Coolant Temp
          if (start >= bytes.length) return '--';
          return (int.parse(bytes[start], radix: 16) - 40).toString();
        case '06': // Short Term Fuel Trim Bank 1
        case '07': // Long Term Fuel Trim Bank 1
        case '08': // Short Term Fuel Trim Bank 2
        case '09': // Long Term Fuel Trim Bank 2
        case '14': // O2 Sensor 1 Short Term
        case '15': // O2 Sensor 1 Long Term
        case '16': // O2 Sensor 2 Short Term
        case '17': // O2 Sensor 2 Long Term
          if (start >= bytes.length) return '--';
          return ((int.parse(bytes[start], radix: 16) - 128) * 100 / 128)
              .toStringAsFixed(1);
        case '0A': // Fuel Pressure
          if (start >= bytes.length) return '--';
          return (int.parse(bytes[start], radix: 16) * 3).toString();
        case '0B': // Intake Manifold Pressure
          if (start >= bytes.length) return '--';
          return int.parse(bytes[start], radix: 16).toString();
        case '0C': // RPM
          if (start + 2 > bytes.length) return '--';
          final a0C = int.parse(bytes[start], radix: 16);
          final b0C = int.parse(bytes[start + 1], radix: 16);
          return ((a0C * 256 + b0C) / 4).toStringAsFixed(0);
        case '0D': // Speed
          if (start >= bytes.length) return '--';
          return int.parse(bytes[start], radix: 16).toString();
        case '0E': // Timing Advance
          if (start >= bytes.length) return '--';
          return ((int.parse(bytes[start], radix: 16) - 128) / 2)
              .toStringAsFixed(1);
        case '0F': // Intake Air Temp
          if (start >= bytes.length) return '--';
          return (int.parse(bytes[start], radix: 16) - 40).toString();
        case '10': // MAF Rate
          if (start + 2 > bytes.length) return '--';
          final a10 = int.parse(bytes[start], radix: 16);
          final b10 = int.parse(bytes[start + 1], radix: 16);
          return ((a10 * 256 + b10) / 100).toStringAsFixed(2);
        case '11': // Throttle Position
        case '2F': // Fuel Level
        case '5B': // Hybrid Battery Life
          if (start >= bytes.length) return '--';
          return ((int.parse(bytes[start], radix: 16) * 100) / 255)
              .toStringAsFixed(1);
        case '1F': // Run Time
          if (start + 2 > bytes.length) return '--';
          final a1F = int.parse(bytes[start], radix: 16);
          final b1F = int.parse(bytes[start + 1], radix: 16);
          return (a1F * 256 + b1F).toString();
        case '33': // Barometric Pressure
          if (start >= bytes.length) return '--';
          return int.parse(bytes[start], radix: 16).toString();
        case '42': // Control Module Voltage
          if (start + 2 > bytes.length) return '--';
          final a42 = int.parse(bytes[start], radix: 16);
          final b42 = int.parse(bytes[start + 1], radix: 16);
          return ((a42 * 256 + b42) / 1000).toStringAsFixed(2);
        case '46': // Ambient Air Temp
          if (start >= bytes.length) return '--';
          return (int.parse(bytes[start], radix: 16) - 40).toString();
        case '5E': // Engine Fuel Rate
          if (start + 2 > bytes.length) return '--';
          final a5E = int.parse(bytes[start], radix: 16);
          final b5E = int.parse(bytes[start + 1], radix: 16);
          return ((a5E * 256 + b5E) / 20).toStringAsFixed(1);
        default:
          return _rawHex(bytes, start);
      }
    } catch (e) {
      FileLogger().error('PARSER', 'Error parsing PID $pid', e);
      return '--';
    }
  }

  static String _rawHex(List<String> bytes, int start) {
    if (start < 0 || start >= bytes.length) return '--';
    return bytes.sublist(start).join(' ');
  }
}
