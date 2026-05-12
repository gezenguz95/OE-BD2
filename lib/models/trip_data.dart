/// GPS koordináta pont — GPS útvonalnaplóhoz.
class TripLatLng {
  final double lat;
  final double lng;
  const TripLatLng(this.lat, this.lng);

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  factory TripLatLng.fromJson(Map<String, dynamic> j) => TripLatLng(
        (j['lat'] as num).toDouble(),
        (j['lng'] as num).toDouble(),
      );
}

class OBDSample {
  final DateTime time;
  final Map<String, double> values;

  const OBDSample({required this.time, required this.values});
}

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

class TripRecord {
  final String id;
  final String vehicleId;
  final String vehicleName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double startSoc;
  final double endSoc;
  final double energyKwh;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final double whPerKm;
  final double distanceKm;
  /// GPS útvonal — 10 másodpercenként rögzített koordinátapontok listája.
  final List<TripLatLng> route;

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
    this.route = const [],
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
    List<TripLatLng>? route,
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
        route: route ?? this.route,
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
        'route': route.map((p) => p.toJson()).toList(),
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
        // Visszafelé kompatibilis: régebbi JSON-ban nincs 'route' mező → üres lista
        route: (j['route'] as List<dynamic>?)
                ?.map((e) => TripLatLng.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
