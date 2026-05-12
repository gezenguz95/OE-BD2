// lib/data/vehicle_profiles_data.dart
//
// Járműprofil adatbázis — Ford, Tesla, Hyundai, Kia, Volvo
// OBD-II protokoll és EV BMS konfiguráció modellenként.
//
// Protokollok:
//   0 = Auto-detect
//   6 = ISO 15765-4 CAN 11-bit 500 kbaud (2006+ EU modellek többsége)
//
// EV platformok:
//   hk_legacy = Hyundai/Kia 400V platform (Ioniq EV, Kona EV, Niro EV, Soul EV)
//   egmp      = Hyundai/Kia E-GMP 800V platform (Ioniq 5/6, EV6)

import '../models/vehicle_profile.dart';

// ═══════════════════════════════════════════════════════════════════════════
// KÖZÖS STANDARD OBD-II PID KÉSZLETEK
// ═══════════════════════════════════════════════════════════════════════════

const _stdIcePids = <StdPidDef>[
  StdPidDef(code: '010C', name: 'Fordulatszám', unit: 'RPM'),
  StdPidDef(code: '010D', name: 'Sebesség', unit: 'km/h'),
  StdPidDef(code: '0105', name: 'Hűtőfolyadék hőm.', unit: '°C'),
  StdPidDef(code: '0104', name: 'Motor terhelés', unit: '%'),
  StdPidDef(code: '012F', name: 'Üzemanyagszint', unit: '%'),
  StdPidDef(code: '0111', name: 'Gázpedál állás', unit: '%'),
  StdPidDef(code: '010F', name: 'Szívócső hőm.', unit: '°C'),
  StdPidDef(code: '0142', name: 'Fedélzeti feszültség', unit: 'V'),
];

/// EV-k standard OBD PID-jei (BMS csoport nélküli EV-khez)
const _stdEvPids = <StdPidDef>[
  StdPidDef(code: '010D', name: 'Sebesség', unit: 'km/h'),
  StdPidDef(code: '015B', name: 'HV akku töltöttség', unit: '%'),
  StdPidDef(code: '0142', name: '12V feszültség', unit: 'V'),
  StdPidDef(code: '0105', name: 'Hőmérséklet', unit: '°C'),
  StdPidDef(code: '0111', name: 'Gázpedál pozíció', unit: '%'),
  StdPidDef(code: '0146', name: 'Külső hőmérséklet', unit: '°C'),
];

// ═══════════════════════════════════════════════════════════════════════════
// HYUNDAI / KIA RÉGI (400V) PLATFORM — EV ADATCSOPORTOK
// Ioniq Electric, Kona Electric, Niro EV, Soul EV Mk2
// ═══════════════════════════════════════════════════════════════════════════

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
        startByte: 13, byteCount: 2, factor: 0.02, littleEndian: true,
        signed: false, minValue: 0, maxValue: 300),
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
        startByte: -3, byteCount: 0,
        minValue: 0, maxValue: 110),
    // Modul hőmérsékletek — bytes[9..15] (7 modul)
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
    // Hűtőfolyadék be/ki — bytes[23-24] (megerősítésre szorul)
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

// ═══════════════════════════════════════════════════════════════════════════
// HYUNDAI / KIA E-GMP (800V) PLATFORM — EV ADATCSOPORTOK
// Ioniq 5, Ioniq 6, EV6, GV60
// Byte pozíciók a legacy platformhoz képest eltolódnak.
// ═══════════════════════════════════════════════════════════════════════════

const _egmpBms2101 = EvDataGroup(
  name: 'BMS',
  canHeader: '7E4',
  command: '2101',
  fields: [
    EvPidField(id: 'soc_bms', name: 'Töltöttség (BMS)', unit: '%',
        startByte: 5, factor: 0.5, minValue: 0, maxValue: 100),
    EvPidField(id: 'battery_voltage', name: 'Feszültség', unit: 'V',
        startByte: 13, byteCount: 2, factor: 0.1, minValue: 400, maxValue: 830),
    EvPidField(id: 'battery_current', name: 'Áram', unit: 'A',
        startByte: 11, byteCount: 2, signed: true, factor: 0.1,
        minValue: -400, maxValue: 400),
    EvPidField(id: 'battery_power', name: 'Teljesítmény', unit: 'kW',
        startByte: -1, byteCount: 0, minValue: -150, maxValue: 250),
    EvPidField(id: 'battery_temp_max', name: 'Akku hőm. (max)', unit: '°C',
        startByte: 16, signed: true, minValue: -20, maxValue: 60),
    EvPidField(id: 'battery_temp_min', name: 'Akku hőm. (min)', unit: '°C',
        startByte: 17, signed: true, minValue: -20, maxValue: 60),
    EvPidField(id: 'aux_battery_voltage', name: '12V akku', unit: 'V',
        startByte: 31, factor: 0.1, minValue: 10, maxValue: 16),
    EvPidField(id: 'ccl', name: 'Max töltési telj.', unit: 'kW',
        startByte: 6, byteCount: 2, factor: 0.01, minValue: 0, maxValue: 250,
        dashboard: false),
    EvPidField(id: 'dcl', name: 'Max kisütési telj.', unit: 'kW',
        startByte: 8, byteCount: 2, factor: 0.01, minValue: 0, maxValue: 250,
        dashboard: false),
  ],
);

const _egmpVmcu2101 = EvDataGroup(
  name: 'VMCU',
  canHeader: '7E2',
  command: '2101',
  fields: [
    EvPidField(id: 'speed', name: 'Sebesség', unit: 'km/h',
        startByte: 14, byteCount: 2, factor: 0.01, littleEndian: true,
        signed: true, minValue: -20, maxValue: 260),
  ],
);

const _egmpBms2105 = EvDataGroup(
  name: 'BMS2',
  canHeader: '7E4',
  command: '2105',
  fields: [
    EvPidField(id: 'soc_display', name: 'Töltöttség (kijelző)', unit: '%',
        startByte: 32, factor: 0.5, minValue: 0, maxValue: 100),
  ],
);

const _egmpEvGroups = [_egmpBms2101, _egmpVmcu2101, _egmpBms2105];

// ═══════════════════════════════════════════════════════════════════════════
//  F O R D
// ═══════════════════════════════════════════════════════════════════════════
// EU modellek 2006-tól CAN (P6), korábbiak vegyes (P0 = auto-detect).

const fordFiestaMk7 = VehicleProfile(
  id: 'ford_fiesta_mk7', make: 'Ford', model: 'Fiesta', variant: 'Mk7',
  drivetrain: DrivetrainType.ice, yearRange: '2008–2017', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const fordFiestaMk8 = VehicleProfile(
  id: 'ford_fiesta_mk8', make: 'Ford', model: 'Fiesta', variant: 'Mk8',
  drivetrain: DrivetrainType.ice, yearRange: '2017–2023', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const fordFocusMk2 = VehicleProfile(
  id: 'ford_focus_mk2', make: 'Ford', model: 'Focus', variant: 'Mk2',
  drivetrain: DrivetrainType.ice, yearRange: '2004–2011', obdProtocol: 0,
  stdPids: _stdIcePids,
);

const fordFocusMk3 = VehicleProfile(
  id: 'ford_focus_mk3', make: 'Ford', model: 'Focus', variant: 'Mk3',
  drivetrain: DrivetrainType.ice, yearRange: '2011–2018', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const fordFocusMk4 = VehicleProfile(
  id: 'ford_focus_mk4', make: 'Ford', model: 'Focus', variant: 'Mk4',
  drivetrain: DrivetrainType.ice, yearRange: '2018–2025', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const fordMondeoMk4 = VehicleProfile(
  id: 'ford_mondeo_mk4', make: 'Ford', model: 'Mondeo', variant: 'Mk4',
  drivetrain: DrivetrainType.ice, yearRange: '2007–2014', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const fordMondeoMk5 = VehicleProfile(
  id: 'ford_mondeo_mk5', make: 'Ford', model: 'Mondeo', variant: 'Mk5',
  drivetrain: DrivetrainType.ice, yearRange: '2014–2022', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const fordKugaMk2 = VehicleProfile(
  id: 'ford_kuga_mk2', make: 'Ford', model: 'Kuga', variant: 'Mk2',
  drivetrain: DrivetrainType.ice, yearRange: '2013–2019', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const fordKugaMk3 = VehicleProfile(
  id: 'ford_kuga_mk3', make: 'Ford', model: 'Kuga', variant: 'Mk3',
  drivetrain: DrivetrainType.ice, yearRange: '2020–2024', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const fordTransitCustom = VehicleProfile(
  id: 'ford_transit_custom', make: 'Ford', model: 'Transit', variant: 'Custom',
  drivetrain: DrivetrainType.ice, yearRange: '2013+', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const fordPuma = VehicleProfile(
  id: 'ford_puma', make: 'Ford', model: 'Puma', variant: '(2019+)',
  drivetrain: DrivetrainType.ice, yearRange: '2019+', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const fordMustangMachE = VehicleProfile(
  id: 'ford_mustang_mache', make: 'Ford', model: 'Mustang', variant: 'Mach-E',
  drivetrain: DrivetrainType.ev, yearRange: '2020+', obdProtocol: 6,
  batteryCapacityKwh: 75.7,
  stdPids: _stdEvPids,
);

// ═══════════════════════════════════════════════════════════════════════════
//  T E S L A
// ═══════════════════════════════════════════════════════════════════════════
// Tesla NEM támogatja a standard OBD-II protokollt.
// Saját CAN rendszert használ — ELM327 adapterrel csak korlátozott adat.

const teslaModelS = VehicleProfile(
  id: 'tesla_model_s', make: 'Tesla', model: 'Model S', variant: 'Korlátozott OBD',
  drivetrain: DrivetrainType.ev, yearRange: '2012+', obdProtocol: 6,
  batteryCapacityKwh: 100,
  stdPids: _stdEvPids,
);

const teslaModel3 = VehicleProfile(
  id: 'tesla_model_3', make: 'Tesla', model: 'Model 3', variant: 'Korlátozott OBD',
  drivetrain: DrivetrainType.ev, yearRange: '2017+', obdProtocol: 6,
  batteryCapacityKwh: 60,
  stdPids: _stdEvPids,
);

const teslaModelX = VehicleProfile(
  id: 'tesla_model_x', make: 'Tesla', model: 'Model X', variant: 'Korlátozott OBD',
  drivetrain: DrivetrainType.ev, yearRange: '2015+', obdProtocol: 6,
  batteryCapacityKwh: 100,
  stdPids: _stdEvPids,
);

const teslaModelY = VehicleProfile(
  id: 'tesla_model_y', make: 'Tesla', model: 'Model Y', variant: 'Korlátozott OBD',
  drivetrain: DrivetrainType.ev, yearRange: '2020+', obdProtocol: 6,
  batteryCapacityKwh: 75,
  stdPids: _stdEvPids,
);

// ═══════════════════════════════════════════════════════════════════════════
//  H Y U N D A I
// ═══════════════════════════════════════════════════════════════════════════
// 2010+ modellek: CAN 11-bit 500k (P6).
// EV-k: BMS on 7E4, VMCU on 7E2, Mode 21 parancsok.

const hyundaiI20Mk2 = VehicleProfile(
  id: 'hyundai_i20_mk2', make: 'Hyundai', model: 'i20', variant: 'Mk2',
  drivetrain: DrivetrainType.ice, yearRange: '2014–2020', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const hyundaiI20Mk3 = VehicleProfile(
  id: 'hyundai_i20_mk3', make: 'Hyundai', model: 'i20', variant: 'Mk3',
  drivetrain: DrivetrainType.ice, yearRange: '2020+', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const hyundaiI30Mk2 = VehicleProfile(
  id: 'hyundai_i30_mk2', make: 'Hyundai', model: 'i30', variant: 'Mk2 (GD)',
  drivetrain: DrivetrainType.ice, yearRange: '2012–2017', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const hyundaiI30Mk3 = VehicleProfile(
  id: 'hyundai_i30_mk3', make: 'Hyundai', model: 'i30', variant: 'Mk3 (PD)',
  drivetrain: DrivetrainType.ice, yearRange: '2017+', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const hyundaiTucsonMk3 = VehicleProfile(
  id: 'hyundai_tucson_mk3', make: 'Hyundai', model: 'Tucson', variant: 'Mk3 (TL)',
  drivetrain: DrivetrainType.ice, yearRange: '2015–2020', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const hyundaiTucsonMk4 = VehicleProfile(
  id: 'hyundai_tucson_mk4', make: 'Hyundai', model: 'Tucson', variant: 'Mk4 (NX4)',
  drivetrain: DrivetrainType.ice, yearRange: '2021+', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const hyundaiIoniqEv28 = VehicleProfile(
  id: 'hyundai_ioniq_ev_28', make: 'Hyundai', model: 'Ioniq', variant: 'Electric 28kWh',
  drivetrain: DrivetrainType.ev, yearRange: '2017–2019', obdProtocol: 6,
  batteryCapacityKwh: 28.0, evPlatform: 'hk_legacy',
  evDataGroups: _hkLegacyEvGroups,
);

const hyundaiIoniqEv38 = VehicleProfile(
  id: 'hyundai_ioniq_ev_38', make: 'Hyundai', model: 'Ioniq', variant: 'Electric 38kWh',
  drivetrain: DrivetrainType.ev, yearRange: '2019–2021', obdProtocol: 6,
  batteryCapacityKwh: 38.3, evPlatform: 'hk_legacy',
  evDataGroups: _hkLegacyEvGroups,
);

const hyundaiKonaEv39 = VehicleProfile(
  id: 'hyundai_kona_ev_39', make: 'Hyundai', model: 'Kona', variant: 'Electric 39kWh',
  drivetrain: DrivetrainType.ev, yearRange: '2018–2023', obdProtocol: 6,
  batteryCapacityKwh: 39.2, evPlatform: 'hk_legacy',
  evDataGroups: _hkLegacyEvGroups,
);

const hyundaiKonaEv64 = VehicleProfile(
  id: 'hyundai_kona_ev_64', make: 'Hyundai', model: 'Kona', variant: 'Electric 64kWh',
  drivetrain: DrivetrainType.ev, yearRange: '2018–2023', obdProtocol: 6,
  batteryCapacityKwh: 64.0, evPlatform: 'hk_legacy',
  evDataGroups: _hkLegacyEvGroups,
);

const hyundaiIoniq5Sr = VehicleProfile(
  id: 'hyundai_ioniq5_sr', make: 'Hyundai', model: 'Ioniq 5', variant: '58kWh (SR)',
  drivetrain: DrivetrainType.ev, yearRange: '2021+', obdProtocol: 6,
  batteryCapacityKwh: 58.0, evPlatform: 'egmp',
  evDataGroups: _egmpEvGroups,
);

const hyundaiIoniq5Lr = VehicleProfile(
  id: 'hyundai_ioniq5_lr', make: 'Hyundai', model: 'Ioniq 5', variant: '77.4kWh (LR)',
  drivetrain: DrivetrainType.ev, yearRange: '2021+', obdProtocol: 6,
  batteryCapacityKwh: 77.4, evPlatform: 'egmp',
  evDataGroups: _egmpEvGroups,
);

const hyundaiIoniq6 = VehicleProfile(
  id: 'hyundai_ioniq6_lr', make: 'Hyundai', model: 'Ioniq 6', variant: '77.4kWh (LR)',
  drivetrain: DrivetrainType.ev, yearRange: '2022+', obdProtocol: 6,
  batteryCapacityKwh: 77.4, evPlatform: 'egmp',
  evDataGroups: _egmpEvGroups,
);

// ═══════════════════════════════════════════════════════════════════════════
//  K I A
// ═══════════════════════════════════════════════════════════════════════════
// ICE modellek: CAN P6. EV-k: azonos BMS struktúra mint a Hyundai.

const kiaCeedMk3 = VehicleProfile(
  id: 'kia_ceed_mk3', make: 'Kia', model: 'Ceed', variant: 'Mk3 (CD)',
  drivetrain: DrivetrainType.ice, yearRange: '2018+', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const kiaRioMk4 = VehicleProfile(
  id: 'kia_rio_mk4', make: 'Kia', model: 'Rio', variant: 'Mk4 (YB)',
  drivetrain: DrivetrainType.ice, yearRange: '2017+', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const kiaSportageMk4 = VehicleProfile(
  id: 'kia_sportage_mk4', make: 'Kia', model: 'Sportage', variant: 'Mk4 (QL)',
  drivetrain: DrivetrainType.ice, yearRange: '2016–2021', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const kiaSportageMk5 = VehicleProfile(
  id: 'kia_sportage_mk5', make: 'Kia', model: 'Sportage', variant: 'Mk5 (NQ5)',
  drivetrain: DrivetrainType.ice, yearRange: '2022+', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const kiaNiroHev = VehicleProfile(
  id: 'kia_niro_hev', make: 'Kia', model: 'Niro', variant: 'HEV',
  drivetrain: DrivetrainType.hybrid, yearRange: '2016–2022', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const kiaNiroEv = VehicleProfile(
  id: 'kia_niro_ev', make: 'Kia', model: 'Niro', variant: 'EV 64kWh',
  drivetrain: DrivetrainType.ev, yearRange: '2018+', obdProtocol: 6,
  batteryCapacityKwh: 64.8, evPlatform: 'hk_legacy',
  evDataGroups: _hkLegacyEvGroups,
);

const kiaSoulEv = VehicleProfile(
  id: 'kia_soul_ev_mk2', make: 'Kia', model: 'Soul', variant: 'EV 64kWh (Mk2)',
  drivetrain: DrivetrainType.ev, yearRange: '2019+', obdProtocol: 6,
  batteryCapacityKwh: 64.0, evPlatform: 'hk_legacy',
  evDataGroups: _hkLegacyEvGroups,
);

const kiaEv6 = VehicleProfile(
  id: 'kia_ev6_lr', make: 'Kia', model: 'EV6', variant: '77.4kWh (LR)',
  drivetrain: DrivetrainType.ev, yearRange: '2021+', obdProtocol: 6,
  batteryCapacityKwh: 77.4, evPlatform: 'egmp',
  evDataGroups: _egmpEvGroups,
);

// ═══════════════════════════════════════════════════════════════════════════
//  V O L V O
// ═══════════════════════════════════════════════════════════════════════════
// 2010+ modellek: CAN P6.
// Recharge EV-k: saját CAN protokoll, standard OBD korlátozott.

const volvoV40 = VehicleProfile(
  id: 'volvo_v40', make: 'Volvo', model: 'V40', variant: '(2012–2019)',
  drivetrain: DrivetrainType.ice, yearRange: '2012–2019', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const volvoS60V60Mk2 = VehicleProfile(
  id: 'volvo_s60_v60_mk2', make: 'Volvo', model: 'S60 / V60', variant: 'Mk2',
  drivetrain: DrivetrainType.ice, yearRange: '2010–2018', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const volvoS60V60Mk3 = VehicleProfile(
  id: 'volvo_s60_v60_mk3', make: 'Volvo', model: 'S60 / V60', variant: 'Mk3 (SPA)',
  drivetrain: DrivetrainType.ice, yearRange: '2019+', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const volvoXc40 = VehicleProfile(
  id: 'volvo_xc40', make: 'Volvo', model: 'XC40', variant: 'ICE / Mild Hybrid',
  drivetrain: DrivetrainType.ice, yearRange: '2018+', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const volvoXc40Recharge = VehicleProfile(
  id: 'volvo_xc40_recharge', make: 'Volvo', model: 'XC40', variant: 'Recharge (EV)',
  drivetrain: DrivetrainType.ev, yearRange: '2020+', obdProtocol: 6,
  batteryCapacityKwh: 78.0,
  stdPids: _stdEvPids,
);

const volvoC40Recharge = VehicleProfile(
  id: 'volvo_c40_recharge', make: 'Volvo', model: 'C40', variant: 'Recharge (EV)',
  drivetrain: DrivetrainType.ev, yearRange: '2021+', obdProtocol: 6,
  batteryCapacityKwh: 78.0,
  stdPids: _stdEvPids,
);

const volvoXc60 = VehicleProfile(
  id: 'volvo_xc60_mk2', make: 'Volvo', model: 'XC60', variant: 'Mk2 (SPA)',
  drivetrain: DrivetrainType.ice, yearRange: '2017+', obdProtocol: 6,
  stdPids: _stdIcePids,
);

const volvoXc90 = VehicleProfile(
  id: 'volvo_xc90_mk2', make: 'Volvo', model: 'XC90', variant: 'Mk2 (SPA)',
  drivetrain: DrivetrainType.ice, yearRange: '2015+', obdProtocol: 6,
  stdPids: _stdIcePids,
);

// ═══════════════════════════════════════════════════════════════════════════
//  EGYÉB
// ═══════════════════════════════════════════════════════════════════════════

const genericIce = VehicleProfile(
  id: 'generic_ice', make: 'Egyéb', model: 'Általános', variant: 'Standard OBD-II',
  drivetrain: DrivetrainType.ice, obdProtocol: 0,
  stdPids: _stdIcePids,
);

// ═══════════════════════════════════════════════════════════════════════════
// ÖSSZES PROFIL + SEGÉDFÜGGVÉNYEK
// ═══════════════════════════════════════════════════════════════════════════

const allVehicleProfiles = <VehicleProfile>[
  // Ford
  fordFiestaMk7, fordFiestaMk8,
  fordFocusMk2, fordFocusMk3, fordFocusMk4,
  fordMondeoMk4, fordMondeoMk5,
  fordKugaMk2, fordKugaMk3,
  fordTransitCustom, fordPuma,
  fordMustangMachE,
  // Tesla
  teslaModelS, teslaModel3, teslaModelX, teslaModelY,
  // Hyundai
  hyundaiI20Mk2, hyundaiI20Mk3,
  hyundaiI30Mk2, hyundaiI30Mk3,
  hyundaiTucsonMk3, hyundaiTucsonMk4,
  hyundaiIoniqEv28, hyundaiIoniqEv38,
  hyundaiKonaEv39, hyundaiKonaEv64,
  hyundaiIoniq5Sr, hyundaiIoniq5Lr, hyundaiIoniq6,
  // Kia
  kiaCeedMk3, kiaRioMk4,
  kiaSportageMk4, kiaSportageMk5,
  kiaNiroHev, kiaNiroEv, kiaSoulEv, kiaEv6,
  // Volvo
  volvoV40, volvoS60V60Mk2, volvoS60V60Mk3,
  volvoXc40, volvoXc40Recharge, volvoC40Recharge,
  volvoXc60, volvoXc90,
  // Egyéb
  genericIce,
];

/// Márka sorrend a UI-ban.
const makeOrder = ['Ford', 'Hyundai', 'Kia', 'Tesla', 'Volvo', 'Egyéb'];

/// Profilok adott márkához.
List<VehicleProfile> profilesForMake(String make) =>
    allVehicleProfiles.where((p) => p.make == make).toList();
