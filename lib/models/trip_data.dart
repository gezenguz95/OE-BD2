// lib/models/trip_data.dart

/// Egy időpillanat a valósidős grafikonhoz (in-memory).
class EvDataPoint {
  final DateTime time;
  final double soc;    // %
  final double power;  // kW (negatív = rekuperáció)
  final double speed;  // km/h

  const EvDataPoint({
    required this.time,
    required this.soc,
    required this.power,
    required this.speed,
  });
}

/// Egy rögzített menet teljes rekordja (JSON-ba mentve).
class TripRecord {
  final String id;           // millisecondsSinceEpoch string
  final String vehicleId;
  final String vehicleName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double startSoc;     // %
  final double endSoc;       // %
  final double energyKwh;    // fogyasztott kWh (maradék kWh különbsége)
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final double whPerKm;      // valódi mért fogyasztás Wh/km (0 = nincs adat)
  final double distanceKm;   // megtett távolság km-ben (integrált)

  const TripRecord({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.startedAt,
    this.endedAt,
    required this.startSoc,
    required this.endSoc,
    required this.energyKwh,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    this.whPerKm = 0,
    this.distanceKm = 0,
  });

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);
  double get socUsed => (startSoc - endSoc).clamp(0.0, 100.0);
  bool get isActive => endedAt == null;

  TripRecord copyWith({
    DateTime? endedAt,
    double? endSoc,
    double? energyKwh,
    double? maxSpeedKmh,
    double? avgSpeedKmh,
    double? whPerKm,
    double? distanceKm,
  }) =>
      TripRecord(
        id: id,
        vehicleId: vehicleId,
        vehicleName: vehicleName,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        startSoc: startSoc,
        endSoc: endSoc ?? this.endSoc,
        energyKwh: energyKwh ?? this.energyKwh,
        maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
        avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
        whPerKm: whPerKm ?? this.whPerKm,
        distanceKm: distanceKm ?? this.distanceKm,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleId': vehicleId,
        'vehicleName': vehicleName,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'startSoc': startSoc,
        'endSoc': endSoc,
        'energyKwh': energyKwh,
        'maxSpeedKmh': maxSpeedKmh,
        'avgSpeedKmh': avgSpeedKmh,
        'whPerKm': whPerKm,
        'distanceKm': distanceKm,
      };

  factory TripRecord.fromJson(Map<String, dynamic> j) => TripRecord(
        id: j['id'] as String,
        vehicleId: j['vehicleId'] as String? ?? '',
        vehicleName: j['vehicleName'] as String? ?? '',
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: j['endedAt'] != null
            ? DateTime.parse(j['endedAt'] as String)
            : null,
        startSoc: (j['startSoc'] as num?)?.toDouble() ?? 0,
        endSoc: (j['endSoc'] as num?)?.toDouble() ?? 0,
        energyKwh: (j['energyKwh'] as num?)?.toDouble() ?? 0,
        maxSpeedKmh: (j['maxSpeedKmh'] as num?)?.toDouble() ?? 0,
        avgSpeedKmh: (j['avgSpeedKmh'] as num?)?.toDouble() ?? 0,
        whPerKm: (j['whPerKm'] as num?)?.toDouble() ?? 0,
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
      );
}
