class MultiframeParser {
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
        final hex = line.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
        if (hex.length >= 4) {
          singleLine = hex;
        }
      }
    }

    List<int> allBytes = [];

    if (frameLines.isNotEmpty) {
      final sortedFrames = frameLines.keys.toList()..sort();

      // NRC ellenőrzés multiframe esetén: ha az első frame 7F-fel kezdődik → hiba
      final firstHex = frameLines[sortedFrames.first] ?? '';
      if (firstHex.length >= 2 &&
          firstHex.substring(0, 2).toUpperCase() == '7F') {
        return [];
      }

      for (final frameNum in sortedFrames) {
        final hex = frameLines[frameNum]!;

        String dataHex;
        if (frameNum == 0) {
          if (hex.length >= 4) {
            final serviceResponse = hex.substring(0, 2).toUpperCase();
            if (serviceResponse == '61') {
              dataHex = hex.substring(4);
            } else if (serviceResponse == '62') {
              dataHex = hex.length >= 6 ? hex.substring(6) : '';
            } else {
              dataHex = hex.substring(4);
            }
          } else {
            dataHex = hex;
          }
        } else {
          dataHex = hex;
        }

        for (int i = 0; i < dataHex.length - 1; i += 2) {
          final byteStr = dataHex.substring(i, i + 2);
          allBytes.add(int.parse(byteStr, radix: 16));
        }
      }
    } else if (singleLine != null && singleLine.length >= 6) {
      // NRC ellenőrzés: 7F xx yy = Negative Response Code → nem adat
      if (singleLine.substring(0, 2).toUpperCase() == '7F') return [];

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
    if (startByte + byteCount > data.length) return null;

    int rawValue;
    if (byteCount == 2) {
      if (littleEndian) {
        rawValue = (data[startByte + 1] << 8) | data[startByte];
      } else {
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

  static String hexDump(List<int> data) {
    return data
        .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
        .join(' ');
  }
}