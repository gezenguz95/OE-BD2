// lib/pages/obd_data_page.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/vehicle_profile.dart';
import '../services/obd_connection.dart';
import '../utils/obd_parser.dart';
import '../utils/multiframe_parser.dart';
import '../utils/file_logger.dart';
import '../models/trip_data.dart';
import '../services/trip_storage.dart';
import '../services/app_settings.dart';
import 'package:flutter/services.dart';
import '../widgets/ev_chart_view.dart';
import '../widgets/ev_dashboard.dart';
import '../widgets/ev_sensors_view.dart';
import '../widgets/ice_dashboard.dart';
import '../widgets/kitt_dashboard.dart';
import '../widgets/charging_monitor_view.dart';

// Dashboard definíciók
class _DashDef {
  final String id;
  final String name;
  final IconData icon;
  const _DashDef(this.id, this.name, this.icon);
}

const _evDashboards = [
  _DashDef('driving',    'Vezetés',         Icons.speed),
  _DashDef('battery',    'Akkumulátor',     Icons.battery_charging_full),
  _DashDef('charging',   'Töltési monitor', Icons.electric_bolt),
  _DashDef('chart',      'Grafikon',        Icons.show_chart),
  _DashDef('sensors',    'Összes szenzor',  Icons.sensors),
  _DashDef('kitt',       'K.I.T.T.',        Icons.auto_awesome),
];

const _iceDashboards = [
  _DashDef('ice_driving', 'Műszerfal',      Icons.speed),
  _DashDef('sensors',     'Összes szenzor', Icons.sensors),
  _DashDef('kitt',        'K.I.T.T.',       Icons.auto_awesome),
];

class ObdDataPage extends StatefulWidget {
  final ObdConnection connection;
  final VehicleProfile profile;
  const ObdDataPage({Key? key, required this.connection, required this.profile})
      : super(key: key);
  @override
  _ObdDataPageState createState() => _ObdDataPageState();
}

class _ObdDataPageState extends State<ObdDataPage> {
  bool _isInitializing = true, _polling = false, _disposed = false;
  bool _showHex = false;
  String _viewMode = 'list';  // 'list', 'driving', 'battery'

  Map<String, String> _currentValues = {};
  Map<String, double> _rawValues = {};
  Map<String, String> _hexDumps = {};
  String _statusText = 'Inicializálás...';
  final List<double> _cellVoltBuffer = [];

  // ── Cella rács ──────────────────────────────────────────────────────────
  List<double> _cellVoltages = const [];

  // ── Valósidős grafikon ──────────────────────────────────────────────────
  final List<EvDataPoint> _chartPoints = [];
  static const _maxChartPoints = 120;

  // ── Menetnapló ──────────────────────────────────────────────────────────
  String? _tripId;
  DateTime? _tripStart;
  double _tripStartSoc = 0;
  double _tripStartEnergy = 0;
  bool _tripStartSocRecorded = false;
  double _tripMaxSpeed = 0;
  double _tripSpeedSum = 0;
  int _tripSpeedCount = 0;
  DateTime? _tripLastSave;

  // ── Wh/km integrálás ────────────────────────────────────────────────────
  DateTime? _lastPollTime;
  double _tripDistanceKm = 0;   // akkumulált távolság (km)
  double _tripEnergyWh = 0;     // akkumulált fogyasztott energia (Wh, only discharge)
  double _rollingWhPerKm = 0;   // futó Wh/km átlag (session-szinten)

  // ── Töltési session ──────────────────────────────────────────────────────
  bool _isCharging = false;
  DateTime? _chargeSessionStart;
  double _chargeSessionStartEnergy = 0; // remaining_kwh töltés elején
  double _chargedKwh = 0;               // ebben a session-ben hozzáadott kWh

  VehicleProfile get _p => widget.profile;
  bool get _isEv => _p.evDataGroups.isNotEmpty;
  bool get _isDashboard => _viewMode != 'list';

  @override
  void initState() {
    super.initState();
    AppSettings().init(); // async, nem blokkolja az UI-t
    _initValues();
    _runInit();
  }

  void _initValues() {
    if (_isEv) {
      for (final g in _p.evDataGroups)
        for (final f in g.fields) _currentValues[f.id] = '--';
    } else {
      for (final p in _p.stdPids) _currentValues[p.code] = '--';
    }
  }

  // ═══ INIT ═══════════════════════════════════════════════════════════════════

  Future<void> _runInit() async {
    _setStatus('Adapter reset...');
    try { await widget.connection.sendCommand('\r'); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 200));
    for (int a = 1; a <= 3; a++) {
      if (_disposed) return;
      _setStatus('Reset... ($a/3)');
      try {
        final r = await widget.connection.sendAndWait('AT Z\r',
            timeout: const Duration(seconds: 5));
        if (r.toUpperCase().contains('ELM')) break;
      } on TimeoutException {
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) {}
    }
    await Future.delayed(const Duration(seconds: 1));
    if (_disposed) return;
    for (final cmd in ['AT E0\r','AT L0\r','AT H0\r','AT S0\r',
      'AT SP ${_p.obdProtocol}\r']) {
      if (_disposed) return;
      _setStatus('Beállítás...');
      try { await widget.connection.sendAndWait(cmd,
          timeout: const Duration(seconds: 3)); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!_disposed && _isEv) {
      final g = _p.evDataGroups.first;
      await _sendAt('AT SH ${g.canHeader}');
      _setStatus('ECU teszt...');
      try {
        final r = await widget.connection.sendAndWait('${g.command}\r',
            timeout: const Duration(seconds: 10));
        if (MultiframeParser.parse(r).isEmpty) _setStatus('ECU nem válaszol');
      } on TimeoutException { _setStatus('ECU nem válaszol'); } catch (_) {}
    } else if (!_disposed) {
      try { await widget.connection.sendAndWait('0100\r',
          timeout: const Duration(seconds: 15)); } catch (_) {}
    }
    if (_disposed) return;
    await FileLogger().log('INIT', 'Kész. Polling indul.');
    if (mounted) setState(() {
      _isInitializing = false;
      if (!_statusText.contains('ECU')) _statusText = 'Élő kapcsolat';
    });
    _startPolling();
  }

  Future<void> _sendAt(String cmd) async {
    try { await widget.connection.sendAndWait('$cmd\r',
        timeout: const Duration(seconds: 2)); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 50));
  }

  void _setStatus(String t) { if (mounted) setState(() => _statusText = t); }

  // ═══ POLLING ════════════════════════════════════════════════════════════════

  void _startPolling() {
    if (_polling || _disposed) return;
    _polling = true;
    if (_isEv) {
      _initTrip();
      _pollEv();
    } else {
      _pollIce();
    }
  }

  void _stopPolling() { _polling = false; }

  // ── Trip metódusok ───────────────────────────────────────────────────────

  void _initTrip() {
    _tripId = '${DateTime.now().millisecondsSinceEpoch}';
    _tripStart = DateTime.now();
    _tripStartSoc = 0;
    _tripStartEnergy = 0;
    _tripStartSocRecorded = false;
    _tripMaxSpeed = 0;
    _tripSpeedSum = 0;
    _tripSpeedCount = 0;
    _tripLastSave = DateTime.now();
    // Wh/km reset
    _lastPollTime = null;
    _tripDistanceKm = 0;
    _tripEnergyWh = 0;
    _rollingWhPerKm = 0;
  }

  void _endTrip() {
    if (_tripId == null) return;
    _saveTripToStorage(endedAt: DateTime.now());
    _tripId = null;
  }

  void _saveTripToStorage({DateTime? endedAt}) {
    if (_tripId == null || _tripStart == null) return;
    final curSoc =
        _rawValues['soc_display'] ?? _rawValues['soc_bms'] ?? _tripStartSoc;
    final curEnergy = _rawValues['remaining_kwh'] ?? 0;
    final energyUsed = (_tripStartEnergy > 0 && curEnergy >= 0)
        ? (_tripStartEnergy - curEnergy).clamp(0.0, 999.0)
        : 0.0;
    final avgSpeed =
        _tripSpeedCount > 0 ? _tripSpeedSum / _tripSpeedCount : 0.0;

    TripStorage.save(TripRecord(
      id: _tripId!,
      vehicleId: _p.id,
      vehicleName: _p.displayName,
      startedAt: _tripStart!,
      endedAt: endedAt,
      startSoc: _tripStartSoc,
      endSoc: curSoc,
      energyKwh: energyUsed,
      maxSpeedKmh: _tripMaxSpeed,
      avgSpeedKmh: avgSpeed,
      whPerKm: _rollingWhPerKm,
      distanceKm: _tripDistanceKm,
    ));
  }

  /// Valódi Wh/km számítás: sebesség × teljesítmény integrálás.
  /// Töltés detektálás és auto-nézet váltás.
  void _updateEnergyTracking() {
    final now = DateTime.now();
    final last = _lastPollTime;
    _lastPollTime = now;
    if (last == null) return;

    final dt = now.difference(last).inMilliseconds / 1000.0; // mp
    if (dt <= 0 || dt > 10) return; // skip ha túl nagy az ugrás

    final speed  = (_rawValues['speed'] ?? 0).abs();   // km/h
    final power  = _rawValues['battery_power'] ?? 0;   // kW (negatív = tölt)
    final current = _rawValues['battery_current'] ?? 0; // A (negatív = tölt)

    // ── Töltés detektálás ─────────────────────────────────────────────────
    final charging = current < -1.0;
    if (charging != _isCharging) {
      if (charging) {
        // Töltés kezdődött
        _chargeSessionStart = now;
        _chargeSessionStartEnergy = _rawValues['remaining_kwh'] ?? 0;
        _chargedKwh = 0;
        // Auto-váltás töltési nézetre (csak ha nem KITT)
        if (_viewMode != 'kitt' && _viewMode != 'charging') {
          _setViewMode('charging');
        }
      }
      if (mounted) setState(() => _isCharging = charging);
    }

    if (charging) {
      // Hozzáadott kWh kiszámítása (remaining_kwh növekedése)
      final curEnergy = _rawValues['remaining_kwh'] ?? 0;
      if (_chargeSessionStartEnergy > 0 && curEnergy > _chargeSessionStartEnergy) {
        if (mounted) setState(() {
          _chargedKwh = curEnergy - _chargeSessionStartEnergy;
          _currentValues['charged_kwh'] = _chargedKwh.toStringAsFixed(2);
        });
      }
      return; // Töltés alatt nem számolunk Wh/km-t
    }

    // ── Wh/km integrálás (vezetés közben) ────────────────────────────────
    if (speed > 2.0 && power > 0) {
      // distDelta = v [km/h] × dt [s] / 3600 = km
      final distDelta = speed * dt / 3600.0;
      // energyDelta = P [kW] × dt [s] / 3600 = kWh → × 1000 = Wh
      final energyDelta = power * dt / 3.6; // Wh

      _tripDistanceKm += distDelta;
      _tripEnergyWh   += energyDelta;

      if (_tripDistanceKm > 0.5) {
        // Csak 500m után kezdünk el bízni az értékben
        final computed = _tripEnergyWh / _tripDistanceKm;
        if (mounted) setState(() {
          _rollingWhPerKm = computed;
          _currentValues['wh_per_km'] = computed.toStringAsFixed(0);
        });
      }
    }
  }

  void _addChartPoint() {
    final soc = _rawValues['soc_display'] ?? _rawValues['soc_bms'] ?? 0;
    final power = _rawValues['battery_power'] ?? 0;
    final speed = (_rawValues['speed'] ?? 0).abs();
    if (soc == 0 && power == 0 && speed == 0) return;
    if (!mounted) return;
    setState(() {
      _chartPoints.add(EvDataPoint(
          time: DateTime.now(), soc: soc, power: power, speed: speed));
      if (_chartPoints.length > _maxChartPoints) _chartPoints.removeAt(0);
    });
  }

  Future<void> _pollEv() async {
    int errors = 0;
    while (_polling && !_disposed && widget.connection.isConnected) {
      bool any = false;
      for (final g in _p.evDataGroups) {
        if (!_polling || _disposed) break;
        await _sendAt('AT SH ${g.canHeader}');
        try {
          final r = await widget.connection.sendAndWait('${g.command}\r',
              timeout: const Duration(seconds: 5));
          final bytes = MultiframeParser.parse(r);
          if (bytes.isEmpty) { errors++; continue; }
          await FileLogger().log('EV RX',
              '${g.name} → ${bytes.length} bytes: ${MultiframeParser.hexDump(bytes)}');
          any = true; errors = 0;
          if (mounted) setState(() =>
          _hexDumps[g.name] = MultiframeParser.hexDump(bytes));
          for (final f in g.fields) {
            if (f.startByte < 0) continue;
            final v = MultiframeParser.extractValue(bytes,
                startByte: f.startByte, byteCount: f.byteCount,
                signed: f.signed, factor: f.factor, offset: f.offset,
                littleEndian: f.littleEndian);
            if (v != null && mounted) setState(() {
              _rawValues[f.id] = v;
              // Sebesség: abszolút érték a kijelzőn
              if (f.id == 'speed') {
                _currentValues[f.id] = _fmt(v.abs(), f);
              } else {
                _currentValues[f.id] = _fmt(v, f);
              }
            });
          }
          _computeDerived(g, bytes);
        } on TimeoutException { errors++;
        } catch (e) {
          if (!widget.connection.isConnected) {
            _polling = false; _setStatus('Kapcsolat elveszett'); return;
          }
        }
      }
      if (any) {
        // Start SOC rögzítése az első valós adat után
        if (!_tripStartSocRecorded) {
          final soc =
              _rawValues['soc_display'] ?? _rawValues['soc_bms'] ?? 0;
          if (soc > 0) {
            _tripStartSoc = soc;
            _tripStartEnergy = _rawValues['remaining_kwh'] ?? 0;
            _tripStartSocRecorded = true;
          }
        }
        // Sebesség frissítése a trip statisztikához
        final spd = (_rawValues['speed'] ?? 0).abs();
        if (spd > 1) {
          _tripSpeedSum += spd;
          _tripSpeedCount++;
          if (spd > _tripMaxSpeed) _tripMaxSpeed = spd;
        }
        // Wh/km integrálás + töltés detektálás
        _updateEnergyTracking();
        // Grafikon pont
        _addChartPoint();
        // Trip mentés 10 másodpercenként
        if (_tripLastSave != null &&
            DateTime.now().difference(_tripLastSave!).inSeconds >= 10) {
          _saveTripToStorage();
          _tripLastSave = DateTime.now();
        }
      }

      if (errors > _p.evDataGroups.length * 3)
        _setStatus('Nincs adat – gyújtás?');
      else if (any && _statusText != 'Élő kapcsolat')
        _setStatus('Élő kapcsolat');
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _pollIce() async {
    int idx = 0;
    while (_polling && !_disposed && widget.connection.isConnected) {
      final p = _p.stdPids[idx % _p.stdPids.length]; idx++;
      try {
        final r = await widget.connection.sendAndWait('${p.code}\r',
            timeout: const Duration(seconds: 3));
        if (mounted) setState(() => _currentValues[p.code] = ObdParser.parseGeneric(r, p.code));
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  void _computeDerived(EvDataGroup g, List<int> bytes) {
    if (!mounted) return;

    // ── Cella feszültségek (2102 / 2103 / 2104) ─────────────────────────────
    if ((g.command == '2102' || g.command == '2103' || g.command == '2104')
        && g.canHeader == '7E4') {
      // 4×FF header után 1 bájt/cella, egység = 0.02 V
      // pl. 0xB2 = 178 → 3.56 V, 0xB3 = 179 → 3.58 V
      if (g.command == '2102') _cellVoltBuffer.clear();
      for (int i = 4; i < bytes.length; i++) {
        final raw = bytes[i];
        if (raw > 120 && raw < 220) _cellVoltBuffer.add(raw * 0.02);
      }
      if (g.command == '2104' && _cellVoltBuffer.isNotEmpty) {
        final minV = _cellVoltBuffer.reduce(math.min);
        final maxV = _cellVoltBuffer.reduce(math.max);
        final avg  = _cellVoltBuffer.fold(0.0, (s, v) => s + v) / _cellVoltBuffer.length;
        final spread = (maxV - minV) * 1000; // mV-ben
        setState(() {
          _rawValues['cell_volt_min']    = minV;
          _rawValues['cell_volt_max']    = maxV;
          _rawValues['cell_volt_avg']    = avg;
          _rawValues['cell_volt_spread'] = spread;
          _currentValues['cell_volt_min']    = minV.toStringAsFixed(3);
          _currentValues['cell_volt_max']    = maxV.toStringAsFixed(3);
          _currentValues['cell_volt_avg']    = avg.toStringAsFixed(3);
          _currentValues['cell_volt_spread'] = spread.toStringAsFixed(0);
          _cellVoltages = List.unmodifiable(_cellVoltBuffer);
        });
      }
      return;
    }

    if (g.command == '2101' && g.canHeader == '7E4') {
      // Teljesítmény
      final v = _rawValues['battery_voltage'] ?? 0;
      final i = _rawValues['battery_current'] ?? 0;
      if (v > 0) {
        final pw = v * i / 1000.0;
        setState(() { _rawValues['battery_power'] = pw;
        _currentValues['battery_power'] = pw.toStringAsFixed(1); });
      }
      // Maradék kWh + hatótáv becslés
      final soc = _rawValues['soc_bms'] ?? 0;
      if (soc > 0) {
        final cap = _p.batteryCapacityKwh > 0 ? _p.batteryCapacityKwh : 28.0;
        final rem = soc * cap / 100.0;
        // Hatótáv: tanult Wh/km (ha elég adat van) → beállítások → 170 default
        final settings = AppSettings();
        final whPerKm = settings.whPerKmOverrideEnabled
            ? settings.whPerKmFallback
            : (_rollingWhPerKm > 50 ? _rollingWhPerKm : settings.whPerKmFallback);
        final rangeKm  = rem * 1000.0 / whPerKm;
        final maxRange = cap  * 1000.0 / whPerKm;
        setState(() {
          _rawValues['remaining_kwh'] = rem;
          _currentValues['remaining_kwh'] = rem.toStringAsFixed(1);
          _rawValues['range_km']     = rangeKm;
          _rawValues['range_km_max'] = maxRange;
          _currentValues['range_km']     = rangeKm.toStringAsFixed(0);
          _currentValues['range_km_max'] = maxRange.toStringAsFixed(0);
        });
      }
      // 32-bit mezők
      if (_p.evPlatform == 'hk_legacy' && bytes.length >= 50) {
        final cec = (bytes[38]*16777216+bytes[39]*65536+bytes[40]*256+bytes[41])/10.0;
        final ced = (bytes[42]*16777216+bytes[43]*65536+bytes[44]*256+bytes[45])/10.0;
        final op = (bytes[46]*16777216+bytes[47]*65536+bytes[48]*256+bytes[49])/3600.0;
        setState(() {
          _rawValues['cec'] = cec; _currentValues['cec'] = cec.toStringAsFixed(0);
          _rawValues['ced'] = ced; _currentValues['ced'] = ced.toStringAsFixed(0);
          _rawValues['op_time'] = op; _currentValues['op_time'] = op.toStringAsFixed(0);
        });
      }
    }
    if (g.command == '2105' && g.canHeader == '7E4') {
      if (_p.evPlatform == 'hk_legacy' && bytes.length >= 30) {
        final cur = (bytes[25]*256+bytes[26])/10.0;
        final ref = (bytes[28]*256+bytes[29])/10.0;
        if (ref > 0) {
          final soh = cur/ref*100.0;
          setState(() { _rawValues['soh'] = soh;
          _currentValues['soh'] = soh.toStringAsFixed(1); });
        }
      } else if (_p.evPlatform == 'egmp' && bytes.length >= 32) {
        final cur = (bytes[27]*256+bytes[28])/10.0;
        final ref = (bytes[30]*256+bytes[31])/10.0;
        if (ref > 0) {
          final soh = cur/ref*100.0;
          setState(() { _rawValues['soh'] = soh;
          _currentValues['soh'] = soh.toStringAsFixed(1); });
        }
      }
    }
  }

  String _fmt(double v, EvPidField f) =>
      v.abs() < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0);

  // ═══ UI ═════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _disposed = true;
    _stopPolling();
    _endTrip();
    widget.connection.close();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _setViewMode(String mode) {
    setState(() => _viewMode = mode);
    // KITT: teljesen fullscreen immersive; minden más: edge-to-edge
    if (mode == 'kitt') {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _showDashboardPicker() {
    final items = _isEv ? _evDashboards : _iceDashboards;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Műszerfal kiválasztása',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          // Lista nézet opció
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Lista nézet'),
            selected: _viewMode == 'list',
            onTap: () { _setViewMode('list'); Navigator.pop(ctx); },
          ),
          const Divider(),
          ...items.map((d) => ListTile(
            leading: Icon(d.icon),
            title: Text(d.name),
            selected: _viewMode == d.id,
            onTap: () { _setViewMode(d.id); Navigator.pop(ctx); },
          )),
          const SizedBox(height: 8),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKitt = _viewMode == 'kitt';
    return Scaffold(
      backgroundColor: isKitt ? Colors.black : null,
      appBar: isKitt
          ? null
          : AppBar(
              title: Text(_p.displayName, overflow: TextOverflow.ellipsis),
              actions: [
                // Dashboard váltó
                IconButton(
                  icon: Icon(_isDashboard ? Icons.list : Icons.speed),
                  tooltip: 'Nézet váltás',
                  onPressed: _showDashboardPicker,
                ),
                if (!_isDashboard && _isEv)
                  IconButton(
                    icon: Icon(_showHex ? Icons.visibility_off : Icons.code),
                    tooltip: 'Raw hex',
                    onPressed: () => setState(() => _showHex = !_showHex),
                  ),
              ],
            ),
      body: _buildBody(),
      floatingActionButton: isKitt
          ? FloatingActionButton.small(
              backgroundColor: Colors.black,
              foregroundColor: const Color(0xFFFF1100),
              tooltip: 'Kilépés',
              onPressed: () => _setViewMode('list'),
              child: const Icon(Icons.close),
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_viewMode) {
      case 'driving':
        return EvDrivingDashboard(data: _currentValues);
      case 'battery':
        return EvBatteryDashboard(data: _currentValues);
      case 'chart':
        return EvChartView(points: List.unmodifiable(_chartPoints));
      case 'ice_driving':
        return IceDashboard(data: _currentValues);
      case 'charging':
        return ChargingMonitorView(
          data: _currentValues,
          chargedKwh: _chargedKwh,
          chargeStartTime: _chargeSessionStart,
        );
      case 'kitt':
        return KittDashboard(data: _currentValues, isEv: _isEv);
      case 'sensors':
        if (_isEv) {
          return EvSensorsView(
              data: _currentValues,
              hexDumps: _hexDumps,
              cellVoltages: _cellVoltages);
        }
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: _buildIceList(),
        );
      default:
        return _buildList();
    }
  }

  // ─── LISTA ──────────────────────────────────────────────────────────────

  Widget _buildList() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          Icon(_isInitializing ? Icons.settings_ethernet : Icons.sensors,
              size: 18, color: _isInitializing ? Colors.orange : Colors.green),
          const SizedBox(width: 6),
          Expanded(child: Text(_statusText,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
        ]),
      ),
      Expanded(child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: _isEv ? _buildEvGroups() : _buildIceList(),
      )),
      Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: () { _stopPolling(); _endTrip(); widget.connection.close(); Navigator.pop(context); },
          icon: const Icon(Icons.bluetooth_disabled),
          label: const Text('Lecsatlakozás'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        ),
      ),
    ]);
  }

  List<Widget> _buildEvGroups() {
    return [
      _group(Icons.battery_charging_full, 'Akkumulátor', Colors.green, true, [
        _tile('soc_display', 'Töltöttség (kijelző)', '%'),
        _tile('soc_bms', 'Töltöttség (BMS)', '%'),
        _tile('remaining_kwh', 'Maradék energia', 'kWh'),
        _tile('battery_voltage', 'Feszültség', 'V'),
        _tile('battery_current', 'Áram', 'A'),
        _tile('battery_power', 'Teljesítmény', 'kW'),
        _tile('soh', 'Állapot (SOH)', '%'),
        _tile('aux_battery_voltage', '12V akku', 'V'),
      ]),
      _group(Icons.thermostat, 'Hőmérséklet', Colors.orange, false, [
        _tile('battery_temp_max', 'Akku max hőm.', '°C'),
        _tile('battery_temp_min', 'Akku min hőm.', '°C'),
      ]),
      _group(Icons.speed, 'Menetparaméterek', Colors.blue, true, [
        _tile('speed', 'Sebesség', 'km/h'),
        _tile('ccl', 'Max töltési telj.', 'kW'),
        _tile('dcl', 'Max kisütési telj.', 'kW'),
      ]),
      _group(Icons.bar_chart, 'Statisztika', Colors.purple, false, [
        _tile('cec', 'Összesen töltve', 'kWh'),
        _tile('ced', 'Összesen merítve', 'kWh'),
        _tile('op_time', 'Üzemóra', 'h'),
      ]),
      if (_showHex) _group(Icons.code, 'Raw hex adat', Colors.grey, true,
        _hexDumps.entries.map((e) => Padding(
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(_fmtHex(e.value), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ]),
        )).toList(),
      ),
    ];
  }

  Widget _group(IconData icon, String title, Color color, bool open, List<Widget> items) {
    return Card(margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: open, childrenPadding: EdgeInsets.zero,
        children: items,
      ),
    );
  }

  Widget _tile(String id, String label, String unit) {
    final val = _currentValues[id] ?? '--';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text('$val $unit', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  List<Widget> _buildIceList() => _p.stdPids.map((p) {
    final val = _currentValues[p.code] ?? '--';
    return Card(margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(padding: const EdgeInsets.all(12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(p.name, style: const TextStyle(fontSize: 15))),
          Text('$val ${p.unit}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }).toList();

  String _fmtHex(String hex) {
    final bytes = hex.split(' ');
    return [for (int i = 0; i < bytes.length; i += 16)
      '[${i.toString().padLeft(2, '0')}] ${bytes.sublist(i, (i+16).clamp(0, bytes.length)).join(' ')}'
    ].join('\n');
  }
}