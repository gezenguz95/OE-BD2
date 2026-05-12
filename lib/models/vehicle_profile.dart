//
// Járműprofil modellek: EV PID mezők, adatcsoportok, standard PID definíciók és járműprofil.

/// Egyetlen EV CAN adatmező definíciója — byte pozíció, skálázás, értéktartomány.
class EvPidField {
  final String id;
  final String name;
  final String unit;
  final int startByte;       // adatrész első byte-ja (0-tól indexelve); -1 = számított érték
  final int byteCount;       // 1 vagy 2
  final bool signed;
  final double factor;
  final double offset;
  final double minValue;
  final double maxValue;
  final bool dashboard;
  final bool littleEndian;   // true: (byte[start+1]<<8 + byte[start]) little-endian sorrendben

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

/// EV CAN adatcsoport: egyetlen OBD parancshoz tartozó mezők gyűjteménye.
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

/// Standard OBD-II PID definíció (Mode 01) — kód, név, mértékegység.
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

/// Járműprofil: azonosítja a jármű típusát, meghatározza az OBD protokollt és az elérhető PID-eket.
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
  final String evPlatform; // EV platform azonosító: 'hk_legacy', 'egmp', vagy üres

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