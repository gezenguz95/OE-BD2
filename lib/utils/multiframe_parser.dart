// lib/utils/multiframe_parser.dart
//
// Multi-frame OBD-II válasz parser EV járművekhez.
// Az ELM327 Mode 21/22 válaszai több sorban (frame-ben) érkeznek.
//
// Példa nyers válasz (AT H0, AT S0):
//   02D
//   0:6101FFFFFFFF
//   1:00000000001616
//   2:161616161621FA
//   ...
//
// A parser kigyűjti az adat byte-okat és egy List<int>-be rendezi.

class MultiframeParser {
  /// Nyers ELM327 választ dolgoz fel.
  /// Visszaadja az adat byte-okat (a service + PID header NÉLKÜL).
  /// Ha a válasz hibás, üres listát ad.
  static List<int> parse(String raw) {
    if (raw.isEmpty) return [];

    final cleaned = raw
        .replaceAll('>', '')
        .replaceAll('\t', ' ')
        .trim();

    // "NO DATA", "ERROR", "UNABLE TO CONNECT" stb.
    final upper = cleaned.toUpperCase();
    if (upper.contains('NO DATA') ||
        upper.contains('ERROR') ||
        upper.contains('UNABLE') ||
        upper.contains('STOPPED') ||
        upper.contains('?')) {
      return [];
    }

    final lines = cleaned.split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return [];

    // Megpróbáljuk multi-frame-ként értelmezni
    // Multi-frame jellemzők: sorok "N:" formátummal kezdődnek
    final frameLines = <int, String>{};
    String? singleLine;

    for (final line in lines) {
      // Frame sor: "0:6101FFFFFFFF" vagy "1:00000000001616"
      final match = RegExp(r'^(\d+):(.+)$').firstMatch(line);
      if (match != null) {
        final frameNum = int.parse(match.group(1)!);
        final hexData = match.group(2)!.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
        frameLines[frameNum] = hexData;
      } else {
        // Nem frame sor — byte count vagy egyéb
        // Ha tisztán hex és megfelelő hosszú, lehet single-frame válasz
        final hex = line.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
        if (hex.length >= 4) {
          singleLine = hex;
        }
      }
    }

    List<int> allBytes = [];

    if (frameLines.isNotEmpty) {
      // Multi-frame válasz
      final sortedFrames = frameLines.keys.toList()..sort();

      for (final frameNum in sortedFrames) {
        final hex = frameLines[frameNum]!;

        String dataHex;
        if (frameNum == 0) {
          // Frame 0: "6101FFFFFFFF" — első 2 byte a service response + PID
          // Service 21 response = 61, PID pl. 01
          // Service 22 response = 62, PID pl. E011
          if (hex.length >= 4) {
            final serviceResponse = hex.substring(0, 2).toUpperCase();
            if (serviceResponse == '61') {
              // Mode 21 response: 61 + 1 byte PID = 4 hex chars header
              dataHex = hex.substring(4);
            } else if (serviceResponse == '62') {
              // Mode 22 response: 62 + 2 byte PID = 6 hex chars header
              dataHex = hex.length >= 6 ? hex.substring(6) : '';
            } else {
              // Ismeretlen — próbáljuk 4 char header-rel
              dataHex = hex.substring(4);
            }
          } else {
            dataHex = hex;
          }
        } else {
          // Későbbi frame-ek: teljes adat
          dataHex = hex;
        }

        // Hex string → byte lista
        for (int i = 0; i < dataHex.length - 1; i += 2) {
          final byteStr = dataHex.substring(i, i + 2);
          allBytes.add(int.parse(byteStr, radix: 16));
        }
      }
    } else if (singleLine != null && singleLine.length >= 6) {
      // Single-frame válasz
      final serviceResponse = singleLine.substring(0, 2).toUpperCase();
      String dataHex;
      if (serviceResponse == '61') {
        dataHex = singleLine.substring(4);
      } else if (serviceResponse == '62') {
        dataHex = singleLine.length >= 6 ? singleLine.substring(6) : '';
      } else if (serviceResponse == '41') {
        // Standard Mode 01 response
        dataHex = singleLine.substring(4);
      } else {
        dataHex = singleLine;
      }

      for (int i = 0; i < dataHex.length - 1; i += 2) {
        final byteStr = dataHex.substring(i, i + 2);
        allBytes.add(int.parse(byteStr, radix: 16));
      }
    }

    return allBytes;
  }

  /// Kinyeri egy mező értékét a byte tömbből.
  /// [startByte]: 0-indexed pozíció
  /// [byteCount]: 1 = 8bit, 2 = 16bit (big-endian)
  /// [signed]: előjeles értelmezés
  /// [factor]: szorzó
  /// [offset]: eltolás
  static double? extractValue(
      List<int> data, {
        required int startByte,
        int byteCount = 1,
        bool signed = false,
        double factor = 1.0,
        double offset = 0.0,
        bool littleEndian = false,
      }) {
    if (startByte < 0) return null; // számított mező
    if (startByte >= data.length) return null;
    if (byteCount == 2 && startByte + 1 >= data.length) return null;

    int rawValue;
    if (byteCount == 2) {
      if (littleEndian) {
        // (byte[start+1] << 8) | byte[start]
        rawValue = (data[startByte + 1] << 8) | data[startByte];
      } else {
        // (byte[start] << 8) | byte[start+1]  — big-endian (default)
        rawValue = (data[startByte] << 8) | data[startByte + 1];
      }
      if (signed && rawValue > 0x7FFF) {
        rawValue -= 0x10000;
      }
    } else {
      rawValue = data[startByte];
      if (signed && rawValue > 0x7F) {
        rawValue -= 0x100;
      }
    }

    return rawValue * factor + offset;
  }

  /// Debug: byte tömb hex dumpja
  static String hexDump(List<int> data) {
    return data
        .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
        .join(' ');
  }
}