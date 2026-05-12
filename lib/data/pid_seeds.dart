// lib/data/pid_seeds.dart

import 'package:drift/drift.dart';
import 'app_database.dart';

/// A “seed” list of OBD-II Mode 01 PIDs [00..20] to populate the catalog on first run.
final List<PidCatalogCompanion> pidSeeds = [
  // // 00: bitmask of supported PIDs 01–20
  // PidCatalogCompanion.insert(
  //   mode: '01',
  //   pid: '00',
  //   description: 'PIDs supported [01–20]',
  // ),

  // 01: Monitor status since DTCs cleared
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '01',
    description: 'Monitor status since DTCs cleared',
  ),

  // 02: Freeze DTC that caused the last freeze frame
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '02',
    description: 'Freeze DTC that caused freeze frame',
  ),

  // 03: Fuel system status
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '03',
    description: 'Fuel system status',
  ),

  // 04: Calculated engine load (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '04',
    description: 'Calculated engine load',
    minValue: Value(0.0),
    maxValue: Value(100.0),
    unit: Value('%'),
  ),

  // 05: Engine coolant temperature (°C)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '05',
    description: 'Engine coolant temperature',
    minValue: Value(-40.0),
    maxValue: Value(215.0),
    unit: Value('°C'),
  ),

  // 06: Short term fuel trim — Bank 1 (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '06',
    description: 'Short term fuel trim — Bank 1',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 07: Long term fuel trim — Bank 1 (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '07',
    description: 'Long term fuel trim — Bank 1',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 08: Short term fuel trim — Bank 2 (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '08',
    description: 'Short term fuel trim — Bank 2',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 09: Long term fuel trim — Bank 2 (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '09',
    description: 'Long term fuel trim — Bank 2',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 0A: Fuel pressure (kPa)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '0A',
    description: 'Fuel pressure (gauge)',
    minValue: Value(0.0),
    maxValue: Value(765.0),
    unit: Value('kPa'),
  ),

  // 0B: Intake manifold absolute pressure (kPa)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '0B',
    description: 'Intake manifold absolute pressure',
    minValue: Value(0.0),
    maxValue: Value(255.0),
    unit: Value('kPa'),
  ),

  // 0C: Engine RPM
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '0C',
    description: 'Engine RPM',
    minValue: Value(0.0),
    maxValue: Value(16383.75),
    unit: Value('rpm'),
  ),

  // 0D: Vehicle speed (km/h)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '0D',
    description: 'Vehicle speed',
    minValue: Value(0.0),
    maxValue: Value(255.0),
    unit: Value('km/h'),
  ),

  // 0E: Timing advance (° before TDC)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '0E',
    description: 'Timing advance',
    minValue: Value(-64.0),
    maxValue: Value(63.5),
    unit: Value('°'),
  ),

  // 0F: Intake air temperature (°C)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '0F',
    description: 'Intake air temperature',
    minValue: Value(-40.0),
    maxValue: Value(215.0),
    unit: Value('°C'),
  ),

  // 10: Mass air flow sensor (g/s)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '10',
    description: 'Mass air flow sensor',
    minValue: Value(0.0),
    maxValue: Value(655.35),
    unit: Value('g/s'),
  ),

  // 11: Throttle position (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '11',
    description: 'Throttle position',
    minValue: Value(0.0),
    maxValue: Value(100.0),
    unit: Value('%'),
  ),

  // 12: Commanded secondary air status
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '12',
    description: 'Commanded secondary air status',
  ),

  // 13: Oxygen sensors present (in banks)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '13',
    description: 'Oxygen sensors present (banks bitmap)',
  ),

  // 14: O₂ Sensor 1 — short term trim (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '14',
    description: 'Oxygen Sensor 1 short term trim',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 15: O₂ Sensor 1 — long term trim (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '15',
    description: 'Oxygen Sensor 1 long term trim',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 16: O₂ Sensor 2 — short term trim (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '16',
    description: 'Oxygen Sensor 2 short term trim',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 17: O₂ Sensor 2 — long term trim (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '17',
    description: 'Oxygen Sensor 2 long term trim',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 18: OBD standards this vehicle conforms to
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '18',
    description: 'OBD standards this vehicle conforms to',
  ),

  // 19: Oxygen sensors present (4 banks)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '19',
    description: 'Oxygen sensors present (4-banks bitmap)',
  ),

  // 1A: Auxiliary input status
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '1A',
    description: 'Auxiliary input status',
  ),

  // 1B: Run time since engine start (s)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '1B',
    description: 'Run time since engine start',
    minValue: Value(0.0),
    maxValue: Value(65535.0),
    unit: Value('s'),
  ),

  // 1C: PIDs supported [21–40]
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '1C',
    description: 'PIDs supported [21–40]',
  ),

  // 1D: Distance traveled with MIL on (km)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '1D',
    description: 'Distance traveled with MIL on',
    minValue: Value(0.0),
    maxValue: Value(65535.0),
    unit: Value('km'),
  ),

  // 1E: Evap system vapor pressure (Pa)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '1E',
    description: 'Evap system vapor pressure',
    minValue: Value(-32768.0),
    maxValue: Value(32767.0),
    unit: Value('Pa'),
  ),

  // 1F: Time since trouble codes cleared (min)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '1F',
    description: 'Time since trouble codes cleared',
    minValue: Value(0.0),
    maxValue: Value(65535.0),
    unit: Value('min'),
  ),

  // 20: PIDs supported [41–60]
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '20',
    description: 'PIDs supported [41–60]',
  ),

  // 2F: Fuel Tank Level Input (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '2F',
    description: 'Fuel Tank Level Input',
    minValue: Value(0.0),
    maxValue: Value(100.0),
    unit: Value('%'),
  ),

  // 33: Absolute Barometric Pressure (kPa)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '33',
    description: 'Absolute Barometric Pressure',
    minValue: Value(0.0),
    maxValue: Value(255.0),
    unit: Value('kPa'),
  ),

  // 42: Control Module Voltage (V)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '42',
    description: 'Control Module Voltage',
    minValue: Value(0.0),
    maxValue: Value(20.0),
    unit: Value('V'),
  ),

  // 46: Ambient Air Temperature (°C)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '46',
    description: 'Ambient Air Temperature',
    minValue: Value(-40.0),
    maxValue: Value(215.0),
    unit: Value('°C'),
  ),

  // 5B: Hybrid Battery Pack Remaining Life (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '5B',
    description: 'Hybrid Battery Pack Remaining Life',
    minValue: Value(0.0),
    maxValue: Value(100.0),
    unit: Value('%'),
  ),

  // 5E: Engine Fuel Rate (L/h)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '5E',
    description: 'Engine Fuel Rate',
    minValue: Value(0.0),
    maxValue: Value(3212.75),
    unit: Value('L/h'),
  ),
];
