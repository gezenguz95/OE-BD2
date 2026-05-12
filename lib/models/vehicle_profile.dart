// lib/models/vehicle_profile.dart

/// EV mező definíció
class EvPidField {
  final String id;
  final String name;
  final String unit;
  final int startByte;       // adat rész első byte (0-based), -1 = számított
  final int byteCount;       // 1 vagy 2
  final bool signed;
  final double factor;
  final double offset;
  final double minValue;
  final double maxValue;
  final bool dashboard;
  final bool littleEndian;   // true = (byte[start+1]<<8 + byte[start])

  const EvPidField({
    required this.id,
    required this.name,
    required this.unit,
    required this.startByte,
    this.byteCount = 1,
    this.signed = false,
    this.factor = 1.0,
    this.offset = 0.0,
    this.minValue = 0,
    this.maxValue = 100,
    this.dashboard = true,
    this.littleEndian = false,
  });
}

class EvDataGroup {
  final String name;
  final String canHeader;
  final String command;
  final List<EvPidField> fields;
  const EvDataGroup({
    required this.name, required this.canHeader,
    required this.command, required this.fields,
  });
}

class StdPidDef {
  final String code;
  final String name;
  final String unit;
  final bool dashboard;
  const StdPidDef({
    required this.code, required this.name,
    required this.unit, this.dashboard = true,
  });
}

enum DrivetrainType { ice, hybrid, phev, ev }

class VehicleProfile {
  final String id;
  final String make;
  final String model;
  final String variant;
  final DrivetrainType drivetrain;
  final String? yearRange;
  final List<EvDataGroup> evDataGroups;
  final List<StdPidDef> stdPids;
  final int obdProtocol;
  final double batteryCapacityKwh;
  final String evPlatform; // 'hk_legacy', 'egmp', ''

  const VehicleProfile({
    required this.id, required this.make, required this.model,
    required this.variant, required this.drivetrain,
    this.yearRange, this.evDataGroups = const [],
    this.stdPids = const [], this.obdProtocol = 6,
    this.batteryCapacityKwh = 0,
    this.evPlatform = '',
  });

  bool get isEv => drivetrain == DrivetrainType.ev || drivetrain == DrivetrainType.phev;
  String get displayName => '$make $model $variant';
}