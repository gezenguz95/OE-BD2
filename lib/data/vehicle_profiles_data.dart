import '../models/vehicle_profile.dart';

// ════════════════════════════════════════════════════════════════════════════
// Hyundai/Kia Legacy platform (hk_legacy)
// ════════════════════════════════════════════════════════════════════════════

const _hkLegacyBms2101 = EvDataGroup(
  name: 'BMS',
  canHeader: '7E4',
  command: '2101',
  fields: [
    EvPidField(id: 'soc_bms', name: 'Töltöttség (BMS)', unit: '%',
        startByte: 4, factor: 0.5, minValue: 0, maxValue: 100),
    EvPidField(id: 'battery_voltage', name: 'Feszültség', unit: 'V',
        startByte: 12, byteCount: 2, factor: 0.1, minValue: 200, maxValue: 420),
    EvPidField(id: 'battery_current', name: 'Áram', unit: 'A',
        startByte: 10, byteCount: 2, signed: true, factor: 0.1,
        minValue: -200, maxValue: 200),
    EvPidField(id: 'battery_power', name: 'Teljesítmény', unit: 'kW',
        startByte: -1, byteCount: 0, minValue: -80, maxValue: 120),
    EvPidField(id: 'battery_temp_max', name: 'Akku hőm. (max)', unit: '°C',
        startByte: 14, signed: true, minValue: -20, maxValue: 60),
    EvPidField(id: 'battery_temp_min', name: 'Akku hőm. (min)', unit: '°C',
        startByte: 15, signed: true, minValue: -20, maxValue: 60),
    EvPidField(id: 'aux_battery_voltage', name: '12V akku', unit: 'V',
        startByte: 29, factor: 0.1, minValue: 10, maxValue: 16),
    EvPidField(id: 'ccl', name: 'Max töltési telj.', unit: 'kW',
        startByte: 5, byteCount: 2, factor: 0.01, minValue: 0, maxValue: 120,
        dashboard: false),
    EvPidField(id: 'dcl', name: 'Max kisütési telj.', unit: 'kW',
        startByte: 7, byteCount: 2, factor: 0.01, minValue: 0, maxValue: 120,
        dashboard: false),
    EvPidField(id: 'cec', name: 'Összesen töltve', unit: 'kWh',
        startByte: -2, byteCount: 0, dashboard: false),
    EvPidField(id: 'ced', name: 'Összesen merítve', unit: 'kWh',
        startByte: -2, byteCount: 0, dashboard: false),
    EvPidField(id: 'op_time', name: 'Üzemóra', unit: 'h',
        startByte: -2, byteCount: 0, dashboard: false),
  ],
);

const _hkLegacyVmcu2101 = EvDataGroup(
  name: 'VMCU',
  canHeader: '7E2',
  command: '2101',
  fields: [
    EvPidField(id: 'speed', name: 'Sebesség', unit: 'km/h',
        startByte: 13, byteCount: 2, factor: 0.01667, littleEndian: true,
        signed: true, minValue: -300, maxValue: 300),
  ],
);

const _hkLegacyBms2105 = EvDataGroup(
  name: 'BMS2',
  canHeader: '7E4',
  command: '2105',
  fields: [
    EvPidField(id: 'soc_display', name: 'Töltöttség (kijelző)', unit: '%',
        startByte: 31, factor: 0.5, minValue: 0, maxValue: 100),
    EvPidField(id: 'soh', name: 'Akku állapot (SOH)', unit: '%',
        startByte: -3, byteCount: 0, minValue: 0, maxValue: 110),
    EvPidField(id: 'mod_temp_1', name: 'Modul hőm. 1', unit: '°C',
        startByte: 9, signed: true, minValue: -40, maxValue: 80, dashboard: false),
    EvPidField(id: 'mod_temp_2', name: 'Modul hőm. 2', unit: '°C',
        startByte: 10, signed: true, minValue: -40, maxValue: 80, dashboard: false),
    EvPidField(id: 'mod_temp_3', name: 'Modul hőm. 3', unit: '°C',
        startByte: 11, signed: true, minValue: -40, maxValue: 80, dashboard: false),
    EvPidField(id: 'mod_temp_4', name: 'Modul hőm. 4', unit: '°C',
        startByte: 12, signed: true, minValue: -40, maxValue: 80, dashboard: false),
    EvPidField(id: 'mod_temp_5', name: 'Modul hőm. 5', unit: '°C',
        startByte: 13, signed: true, minValue: -40, maxValue: 80, dashboard: false),
    EvPidField(id: 'mod_temp_6', name: 'Modul hőm. 6', unit: '°C',
        startByte: 14, signed: true, minValue: -40, maxValue: 80, dashboard: false),
    EvPidField(id: 'mod_temp_7', name: 'Modul hőm. 7', unit: '°C',
        startByte: 15, signed: true, minValue: -40, maxValue: 80, dashboard: false),
    EvPidField(id: 'coolant_in',  name: 'Hűtő be', unit: '°C',
        startByte: 23, signed: true, minValue: -40, maxValue: 80, dashboard: false),
    EvPidField(id: 'coolant_out', name: 'Hűtő ki', unit: '°C',
        startByte: 24, signed: true, minValue: -40, maxValue: 80, dashboard: false),
  ],
);

// Cella feszültség csoportok — 2102/2103/2104 (7E4)
// 96 cella, 32 cella/PID. Nyers adat feldolgozása _computeDerived-ben.
const _hkLegacyCellV1 = EvDataGroup(
  name: 'CellV_1', canHeader: '7E4', command: '2102', fields: [],
);
const _hkLegacyCellV2 = EvDataGroup(
  name: 'CellV_2', canHeader: '7E4', command: '2103', fields: [],
);
const _hkLegacyCellV3 = EvDataGroup(
  name: 'CellV_3', canHeader: '7E4', command: '2104', fields: [],
);

const _hkLegacyEvGroups = [
  _hkLegacyBms2101, _hkLegacyVmcu2101, _hkLegacyBms2105,
  _hkLegacyCellV1, _hkLegacyCellV2, _hkLegacyCellV3,
];

// ════════════════════════════════════════════════════════════════════════════
// Ford Kuga PHEV — C2 platform (ford_phev)
// Forrás: ABRP iternio/ev-obd-pids ford/MachE.json
// Protokoll: ISO 15765-4 CAN 500 kbit/s, 11-bit ID (ATSP6)
// Init: ATZ  ATD  ATE0  ATS0  ATAL  ATSP6
//
// ECU modulok:
//   7E0 / 7E8  — PCM  (Powertrain Control Module)
//   7E4 / 7EC  — BECM (Battery Energy Control Module)
//   7E2 / 7EA  — TCM/VCM (Vehicle/Charging Control)
//   7E6 / 7EE  — TCM Gear/Park
// ════════════════════════════════════════════════════════════════════════════

/// PCM — Sebesség
/// 22 15 05  →  62 15 05 A B  →  ((A<<8)+B)/128 km/h
const _fordPhevPcmSpeed = EvDataGroup(
  name: 'PCM_Speed',
  canHeader: '7E0',
  command: '221505',
  fields: [
    EvPidField(
      id: 'speed', name: 'Sebesség', unit: 'km/h',
      startByte: 0, byteCount: 2,
      factor: 0.0078125, // = 1/128
      minValue: 0, maxValue: 200,
    ),
  ],
);

/// BECM — Töltöttség (BMS SOC)
/// 22 48 45  →  62 48 45 A  →  A × 0.5 %
const _fordPhevBecmSoc = EvDataGroup(
  name: 'BECM_SOC',
  canHeader: '7E4',
  command: '224845',
  fields: [
    EvPidField(
      id: 'soc_bms', name: 'Töltöttség (BMS)', unit: '%',
      startByte: 0, factor: 0.5,
      minValue: 0, maxValue: 100,
    ),
  ],
);

/// BECM — HV feszültség
/// 22 48 0D  →  62 48 0D A B  →  ((A<<8)+B) × 0.01 V
const _fordPhevBecmVoltage = EvDataGroup(
  name: 'BECM_Volt',
  canHeader: '7E4',
  command: '22480D',
  fields: [
    EvPidField(
      id: 'battery_voltage', name: 'HV feszültség', unit: 'V',
      startByte: 0, byteCount: 2, factor: 0.01,
      minValue: 200, maxValue: 500,
    ),
  ],
);

/// BECM — HV áram  (negatív = töltés)
/// 22 48 F9  →  62 48 F9 A B  →  signed16(A,B) × 0.1 A
/// battery_power: számított mező (V × I / 1000 kW), _computeDerived-ben
const _fordPhevBecmCurrent = EvDataGroup(
  name: 'BECM_Curr',
  canHeader: '7E4',
  command: '2248F9',
  fields: [
    EvPidField(
      id: 'battery_current', name: 'Áram', unit: 'A',
      startByte: 0, byteCount: 2, signed: true, factor: 0.1,
      minValue: -500, maxValue: 300,
    ),
    EvPidField(
      id: 'battery_power', name: 'Teljesítmény', unit: 'kW',
      startByte: -1, byteCount: 0,
      minValue: -80, maxValue: 120,
    ),
  ],
);

/// BECM — Akkumulátor hőmérséklet
/// 22 48 00  →  62 48 00 A  →  A − 50 °C
const _fordPhevBecmTemp = EvDataGroup(
  name: 'BECM_Temp',
  canHeader: '7E4',
  command: '224800',
  fields: [
    EvPidField(
      id: 'battery_temp_max', name: 'Akku hőmérséklet', unit: '°C',
      startByte: 0, offset: -50,
      minValue: -40, maxValue: 80,
    ),
  ],
);

/// BECM — Állapotjelző (SOH)
/// 22 49 0C  →  62 49 0C A  →  A × 0.5 %
const _fordPhevBecmSoh = EvDataGroup(
  name: 'BECM_SOH',
  canHeader: '7E4',
  command: '22490C',
  fields: [
    EvPidField(
      id: 'soh', name: 'Akku állapot (SOH)', unit: '%',
      startByte: 0, factor: 0.5,
      minValue: 0, maxValue: 110,
    ),
  ],
);

/// TCM/VCM — Töltési állapot
/// 22 48 51  →  62 48 51 A
///   A = 6  → AC töltés
///   A = 8  → DC gyorstöltés
///   egyéb  → nem tölt
/// Értelmezés: _computeDerived-ben (ford_phev platform)
const _fordPhevTcmChargeState = EvDataGroup(
  name: 'TCM_Charge',
  canHeader: '7E2',
  command: '224851',
  fields: [
    EvPidField(
      id: 'charging_state_raw', name: 'Töltési állapot (nyers)', unit: '',
      startByte: 0, dashboard: false,
      minValue: 0, maxValue: 15,
    ),
  ],
);

/// TCM/VCM — Külső hőmérséklet
/// 22 DD 05  →  62 DD 05 A  →  A − 40 °C
const _fordPhevTcmExtTemp = EvDataGroup(
  name: 'TCM_ExtTemp',
  canHeader: '7E2',
  command: '22DD05',
  fields: [
    EvPidField(
      id: 'ext_temp', name: 'Külső hőmérséklet', unit: '°C',
      startByte: 0, offset: -40,
      minValue: -40, maxValue: 80,
    ),
  ],
);

/// PCM — Fordulatszám
/// Mode 01, PID 0x0C  →  41 0C A B  →  ((A<<8)+B)/4 rpm
const _fordPhevPcmRpm = EvDataGroup(
  name: 'PCM_RPM',
  canHeader: '7E0',
  command: '010C',
  fields: [
    EvPidField(
      id: 'rpm', name: 'Fordulatszám', unit: 'RPM',
      startByte: 0, byteCount: 2,
      factor: 0.25, // (A<<8+B) / 4
      minValue: 0, maxValue: 7000,
    ),
  ],
);

/// PCM — Üzemanyagszint
/// Mode 01, PID 0x2F  →  41 2F A  →  A × 100/255 %
const _fordPhevPcmFuel = EvDataGroup(
  name: 'PCM_Fuel',
  canHeader: '7E0',
  command: '012F',
  fields: [
    EvPidField(
      id: 'fuel_level', name: 'Üzemanyagszint', unit: '%',
      startByte: 0,
      factor: 0.3922, // = 100/255
      minValue: 0, maxValue: 100,
    ),
  ],
);

/// PCM — Hűtőfolyadék hőmérséklet
/// Mode 01, PID 0x05  →  41 05 A  →  A − 40 °C
const _fordPhevPcmCoolant = EvDataGroup(
  name: 'PCM_Cool',
  canHeader: '7E0',
  command: '0105',
  fields: [
    EvPidField(
      id: 'coolant_temp', name: 'Hűtőfolyadék hőm.', unit: '°C',
      startByte: 0, offset: -40,
      minValue: -40, maxValue: 130,
    ),
  ],
);

/// PCM — Motor terhelés
/// Mode 01, PID 0x04  →  41 04 A  →  A × 100/255 %
const _fordPhevPcmLoad = EvDataGroup(
  name: 'PCM_Load',
  canHeader: '7E0',
  command: '0104',
  fields: [
    EvPidField(
      id: 'engine_load', name: 'Motor terhelés', unit: '%',
      startByte: 0,
      factor: 0.3922, // = 100/255
      minValue: 0, maxValue: 100,
    ),
  ],
);

/// Polling sorrend:
/// PCM speed → BECM soc/volt/curr/temp/soh → TCM charge/exttemp
/// → PCM ICE adatok (rpm/fuel/coolant/load) — az EV adatok után, alacsonyabb prioritással
const _fordPhevEvGroups = [
  _fordPhevPcmSpeed,
  _fordPhevBecmSoc,
  _fordPhevBecmVoltage,
  _fordPhevBecmCurrent,
  _fordPhevBecmTemp,
  _fordPhevBecmSoh,
  _fordPhevTcmChargeState,
  _fordPhevTcmExtTemp,
  // Benzinmotor adatok (Mode 01, PCM — 7E0)
  _fordPhevPcmRpm,
  _fordPhevPcmFuel,
  _fordPhevPcmCoolant,
  _fordPhevPcmLoad,
];

// ════════════════════════════════════════════════════════════════════════════
// Jármű profilok
// ════════════════════════════════════════════════════════════════════════════

const hyundaiIoniqEv28 = VehicleProfile(
  id: 'hyundai_ioniq_ev_28', make: 'Hyundai', model: 'Ioniq', variant: 'Electric 28kWh',
  drivetrain: DrivetrainType.ev, yearRange: '2017–2019', obdProtocol: 6,
  batteryCapacityKwh: 28.0, evPlatform: 'hk_legacy',
  evDataGroups: _hkLegacyEvGroups,
);

/// Ford Kuga Mk3 PHEV 2021 — 14.4 kWh Li-ion (Samsung SDI NMC)
/// Névleges csomag feszültség: ~315 V  |  Névleges kapacitás: 14.4 kWh
/// OBD adapter: OBDLink MX+ vagy EX ajánlott (Ford MS-CAN + HS-CAN)
const fordKugaMk3Phev = VehicleProfile(
  id: 'ford_kuga_mk3_phev', make: 'Ford', model: 'Kuga', variant: 'PHEV 2021',
  drivetrain: DrivetrainType.phev, yearRange: '2020–2024', obdProtocol: 6,
  batteryCapacityKwh: 14.4, evPlatform: 'ford_phev',
  evDataGroups: _fordPhevEvGroups,
);

const allVehicleProfiles = <VehicleProfile>[
  hyundaiIoniqEv28,
  fordKugaMk3Phev,
];

/// Márka sorrend a UI-ban.
const makeOrder = ['Hyundai', 'Ford'];

/// Profilok adott márkához.
List<VehicleProfile> profilesForMake(String make) =>
    allVehicleProfiles.where((p) => p.make == make).toList();
