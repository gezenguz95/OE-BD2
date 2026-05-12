import 'package:drift/drift.dart';
import 'app_database.dart';

/// Alapértelmezett OBD-II Mode 01 PID katalógus (00..20 + néhány gyakori 2x..5E),
/// amit az adatbázis első indításakor töltünk be.
final List<PidCatalogCompanion> pidSeeds = [
  // 01: Diagnosztikai monitor állapot DTC törlés óta
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '01',
    description: 'Monitor állapot DTC törlés óta',
  ),

  // 02: Az utolsó freeze frame-et okozó DTC kód
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '02',
    description: 'Freeze frame DTC',
  ),

  // 03: Üzemanyag rendszer állapota
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '03',
    description: 'Üzemanyag rendszer állapot',
  ),

  // 04: Számított motor terhelés (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '04',
    description: 'Motor terhelés',
    minValue: Value(0.0),
    maxValue: Value(100.0),
    unit: Value('%'),
  ),

  // 05: Motor hűtőfolyadék hőmérséklet (°C)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '05',
    description: 'Hűtőfolyadék hőmérséklet',
    minValue: Value(-40.0),
    maxValue: Value(215.0),
    unit: Value('°C'),
  ),

  // 06: Rövid távú üzemanyag korrekció — 1. bank (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '06',
    description: 'Rövid távú üzemanyag korrekció — 1. bank',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 07: Hosszú távú üzemanyag korrekció — 1. bank (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '07',
    description: 'Hosszú távú üzemanyag korrekció — 1. bank',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 08: Rövid távú üzemanyag korrekció — 2. bank (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '08',
    description: 'Rövid távú üzemanyag korrekció — 2. bank',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 09: Hosszú távú üzemanyag korrekció — 2. bank (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '09',
    description: 'Hosszú távú üzemanyag korrekció — 2. bank',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 0A: Üzemanyag nyomás (kPa)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '0A',
    description: 'Üzemanyag nyomás',
    minValue: Value(0.0),
    maxValue: Value(765.0),
    unit: Value('kPa'),
  ),

  // 0B: Szívócső abszolút nyomás (kPa)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '0B',
    description: 'Szívócső abszolút nyomás',
    minValue: Value(0.0),
    maxValue: Value(255.0),
    unit: Value('kPa'),
  ),

  // 0C: Motor fordulatszám (rpm)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '0C',
    description: 'Motor fordulatszám',
    minValue: Value(0.0),
    maxValue: Value(16383.75),
    unit: Value('rpm'),
  ),

  // 0D: Jármű sebesség (km/h)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '0D',
    description: 'Jármű sebesség',
    minValue: Value(0.0),
    maxValue: Value(255.0),
    unit: Value('km/h'),
  ),

  // 0E: Gyújtási előgyújtás (° BTDC)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '0E',
    description: 'Gyújtási előgyújtás',
    minValue: Value(-64.0),
    maxValue: Value(63.5),
    unit: Value('°'),
  ),

  // 0F: Beszívott levegő hőmérséklet (°C)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '0F',
    description: 'Szívott levegő hőmérséklet',
    minValue: Value(-40.0),
    maxValue: Value(215.0),
    unit: Value('°C'),
  ),

  // 10: Levegő tömegáram szenzor (g/s)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '10',
    description: 'Levegő tömegáram (MAF)',
    minValue: Value(0.0),
    maxValue: Value(655.35),
    unit: Value('g/s'),
  ),

  // 11: Fojtószelep pozíció (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '11',
    description: 'Fojtószelep pozíció',
    minValue: Value(0.0),
    maxValue: Value(100.0),
    unit: Value('%'),
  ),

  // 12: Másodlagos levegő rendszer állapot
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '12',
    description: 'Másodlagos levegő rendszer állapot',
  ),

  // 13: O₂ szenzorok bankok szerint
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '13',
    description: 'O₂ szenzorok (bank bitmap)',
  ),

  // 14: O₂ szenzor 1 — rövid távú korrekció (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '14',
    description: 'O₂ szenzor 1 — rövid távú korrekció',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 15: O₂ szenzor 1 — hosszú távú korrekció (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '15',
    description: 'O₂ szenzor 1 — hosszú távú korrekció',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 16: O₂ szenzor 2 — rövid távú korrekció (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '16',
    description: 'O₂ szenzor 2 — rövid távú korrekció',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 17: O₂ szenzor 2 — hosszú távú korrekció (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '17',
    description: 'O₂ szenzor 2 — hosszú távú korrekció',
    minValue: Value(-100.0),
    maxValue: Value(99.22),
    unit: Value('%'),
  ),

  // 18: A jármű OBD szabványai
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '18',
    description: 'OBD szabványok',
  ),

  // 19: O₂ szenzorok 4 bankra
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '19',
    description: 'O₂ szenzorok (4 bank bitmap)',
  ),

  // 1A: Külső bemenet állapota
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '1A',
    description: 'Külső bemenet állapot',
  ),

  // 1B: Motor üzemideje az indítás óta (s)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '1B',
    description: 'Motor üzemidő indítás óta',
    minValue: Value(0.0),
    maxValue: Value(65535.0),
    unit: Value('s'),
  ),

  // 1C: Támogatott PID-ek [21–40]
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '1C',
    description: 'Támogatott PID-ek [21–40]',
  ),

  // 1D: Megtett táv MIL bekapcsolva (km)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '1D',
    description: 'Megtett táv MIL bekapcsolva',
    minValue: Value(0.0),
    maxValue: Value(65535.0),
    unit: Value('km'),
  ),

  // 1E: Tankszellőzés gőznyomás (Pa)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '1E',
    description: 'Tankszellőzés gőznyomás',
    minValue: Value(-32768.0),
    maxValue: Value(32767.0),
    unit: Value('Pa'),
  ),

  // 1F: Hibakód törlés óta eltelt idő (perc)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '1F',
    description: 'Idő DTC törlés óta',
    minValue: Value(0.0),
    maxValue: Value(65535.0),
    unit: Value('min'),
  ),

  // 20: Támogatott PID-ek [41–60]
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '20',
    description: 'Támogatott PID-ek [41–60]',
  ),

  // 2F: Üzemanyagszint (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '2F',
    description: 'Üzemanyagszint',
    minValue: Value(0.0),
    maxValue: Value(100.0),
    unit: Value('%'),
  ),

  // 33: Légköri abszolút nyomás (kPa)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '33',
    description: 'Légköri abszolút nyomás',
    minValue: Value(0.0),
    maxValue: Value(255.0),
    unit: Value('kPa'),
  ),

  // 42: Vezérlőegység tápfeszültség (V)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '42',
    description: 'Vezérlőegység tápfeszültség',
    minValue: Value(0.0),
    maxValue: Value(20.0),
    unit: Value('V'),
  ),

  // 46: Külső levegő hőmérséklet (°C)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '46',
    description: 'Külső levegő hőmérséklet',
    minValue: Value(-40.0),
    maxValue: Value(215.0),
    unit: Value('°C'),
  ),

  // 5B: Hibrid akku hátralévő élettartam (%)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '5B',
    description: 'Hibrid akku hátralévő élettartam',
    minValue: Value(0.0),
    maxValue: Value(100.0),
    unit: Value('%'),
  ),

  // 5E: Pillanatnyi üzemanyag fogyasztás (L/h)
  PidCatalogCompanion.insert(
    mode: '01',
    pid: '5E',
    description: 'Pillanatnyi üzemanyag fogyasztás',
    minValue: Value(0.0),
    maxValue: Value(3212.75),
    unit: Value('L/h'),
  ),
];
