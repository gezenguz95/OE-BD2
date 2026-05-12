// Töltési session adatmodelljei:
//   ChargeDataPoint — egyetlen mérési pont (SOC, teljesítmény, hőmérséklet)
//   ChargeSession   — egy teljes töltési folyamat rekordja pontlistával

/// Egyetlen mérési pont a töltési görbéhez — SOC az X tengely értéke.
class ChargeDataPoint {
  /// Töltöttségi szint (%) — ez az X tengely értéke a grafikonon.
  final double soc;

  /// Töltési teljesítmény kW-ban (pozitív érték, az áram abszolút értékéből számított).
  final double powerKw;

  /// Az akkumulátor maximális cellahőmérséklete (°C).
  final double tempC;

  /// Időbélyeg — a sorrend megőrzéséhez és a töltési idő kiszámításához.
  final DateTime time;

  const ChargeDataPoint({
    required this.soc,
    required this.powerKw,
    required this.tempC,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'soc': soc,
        'powerKw': powerKw,
        'tempC': tempC,
        'time': time.toIso8601String(),
      };

  factory ChargeDataPoint.fromJson(Map<String, dynamic> j) => ChargeDataPoint(
        soc: (j['soc'] as num).toDouble(),
        powerKw: (j['powerKw'] as num).toDouble(),
        tempC: (j['tempC'] as num).toDouble(),
        time: DateTime.parse(j['time'] as String),
      );
}

/// Egy rögzített töltési session teljes rekordja — JSON-ba sorosítható.
class ChargeSession {
  /// Milliszekundum-alapú egyedi azonosító.
  final String id;
  final String vehicleId;
  final String vehicleName;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// Töltöttségi szint a töltés elején (%).
  final double startSoc;

  /// Töltöttségi szint a töltés végén (%).
  final double endSoc;

  /// A session során mért csúcsteljesítmény (kW).
  final double peakPowerKw;

  /// A session során hozzáadott energia (kWh).
  final double addedKwh;

  /// Az összes rögzített mérési pont (a görbe alapadata).
  final List<ChargeDataPoint> points;

  const ChargeSession({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.startedAt,
    this.endedAt,
    required this.startSoc,
    required this.endSoc,
    required this.peakPowerKw,
    required this.addedKwh,
    required this.points,
  });

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'vehicleName': vehicleName,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'startSoc': startSoc,
        'endSoc': endSoc,
        'peakPowerKw': peakPowerKw,
        'addedKwh': addedKwh,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory ChargeSession.fromJson(Map<String, dynamic> j) => ChargeSession(
        id: j['id'] as String,
        vehicleId: j['vehicleId'] as String? ?? '',
        vehicleName: j['vehicleName'] as String? ?? '',
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: j['endedAt'] != null
            ? DateTime.parse(j['endedAt'] as String)
            : null,
        startSoc: (j['startSoc'] as num?)?.toDouble() ?? 0,
        endSoc: (j['endSoc'] as num?)?.toDouble() ?? 0,
        peakPowerKw: (j['peakPowerKw'] as num?)?.toDouble() ?? 0,
        addedKwh: (j['addedKwh'] as num?)?.toDouble() ?? 0,
        points: (j['points'] as List<dynamic>? ?? [])
            .map((e) => ChargeDataPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
