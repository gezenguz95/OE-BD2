import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

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
import '../widgets/custom_charts_view.dart';
import '../widgets/ev_sensors_view.dart';
import '../widgets/ice_dashboard.dart';
import '../widgets/kitt_dashboard.dart';
import '../widgets/charging_monitor_view.dart';
import '../widgets/phev_dashboard.dart';
import '../widgets/phev_ice_view.dart';
import '../widgets/obd_monitor_view.dart';
import '../services/weather_service.dart';
import '../services/notification_service.dart';
import '../models/charge_data.dart';
import '../services/charge_storage.dart';
import '../l10n/app_localizations.dart';
import '../services/locale_notifier.dart';
import 'settings_page.dart';
import 'trips_page.dart';

// Dashboard definíciók
class _DashDef {
  final String id;
  final String name;
  final IconData icon;
  const _DashDef(this.id, this.name, this.icon);
}

class ObdDataPage extends StatefulWidget {
  final ObdConnection connection;
  final VehicleProfile profile;

  /// Ha meg van adva, az app visszatérésekor (és a gomb megnyomásakor) automatikusan
  /// megkísérli újraépíteni a kapcsolatot a belső oldal elhagyása nélkül.
  final Future<ObdConnection> Function()? reconnectFn;

  const ObdDataPage({
    super.key,
    required this.connection,
    required this.profile,
    this.reconnectFn,
  });
  @override
  _ObdDataPageState createState() => _ObdDataPageState();
}

class _ObdDataPageState extends State<ObdDataPage> with WidgetsBindingObserver {
  bool _isInitializing = true, _polling = false, _disposed = false;
  bool _isReconnecting = false;
  String _viewMode = 'list';  // 'list', 'driving', 'battery'

  /// Aktuálisan aktív kapcsolat — reconnect során kicserélhető.
  late ObdConnection _conn;

  /// Platform channel az OBDForegroundService indításához/leállításához.
  /// Ugyanaz a csatorna, mint az auto-connect — a MainActivity kezeli.
  static const _fgChannel =
      MethodChannel('com.example.obdreader2/auto_connect');

  final Map<String, String> _currentValues = {};
  final Map<String, double> _rawValues = {};
  final Map<String, String> _hexDumps = {};

  // OBD Monitor: nyers forgalom naplója
  final List<ObdLogEntry> _obdLog = [];
  static const _maxObdLog = 400;

  /// Utolsó vissza-gomb nyomás időpontja (két nyomás között 2 mp-en belül kell
  /// lennie, hogy az app kilépjen — különben csak egy snackbar jön).
  DateTime? _lastBackPress;

  // raw értékek lekérése, 0.0 alapértékkel
  double _raw(String id) => _rawValues[id] ?? 0.0;

  /// OBD Monitor naplóba ír egy bejegyzést (setState nélkül — csak puffer).
  void _obdLogAdd(ObdLogEntry entry) {
    _obdLog.add(entry);
    if (_obdLog.length > _maxObdLog) _obdLog.removeAt(0);
  }
  String _statusText = '';
  final List<double> _cellVoltBuffer = [];

  List<double> _cellVoltages = const [];

  final List<EvDataPoint> _chartPoints = [];
  static const _maxChartPoints = 120;

  String? _tripId;
  DateTime? _tripStart;
  double _tripStartSoc = 0;
  double _tripStartEnergy = 0;
  bool _tripStartSocRecorded = false;
  double _tripMaxSpeed = 0;
  double _tripSpeedSum = 0;
  int _tripSpeedCount = 0;
  DateTime? _tripLastSave;

  DateTime? _lastPollTime;
  double _tripDistanceKm = 0;   // akkumulált távolság (km)
  double _tripEnergyWh = 0;     // akkumulált fogyasztott energia (Wh, only discharge)
  double _rollingWhPerKm = 0;   // futó Wh/km átlag (session-szinten)

  bool _isCharging = false;
  DateTime? _chargeSessionStart;
  double _chargeSessionStartEnergy = 0; // remaining_kwh töltés elején
  double _chargedKwh = 0;               // ebben a session-ben hozzáadott kWh

  final List<OBDSample> _sampleHistory = [];
  DateTime? _lastSampleTime;

  final List<ChargeDataPoint> _chargePoints = [];
  DateTime? _lastChargePoint;
  double? _externalTemp;      // Kültéri hőmérséklet °C (GPS + időjárás)
  Map<String, String> _rangeDebug = {}; // Hatótáv becslés debug adatok

  double? _learnedWhPerKm;    // null = nincs elég history
  int     _learnedTripCount = 0;
  DateTime? _lastLearnRefresh;

  double? _lifetimeWhPerKm;   // null = kilométeróra még nem olvasható
  double  _odometerKm = 0;
  DateTime? _lastOdoQuery;

  /// GPS útvonalpontok — 10 másodpercenként rögzítve az aktív menet alatt.
  final List<TripLatLng> _gpsRoute = [];
  Timer? _gpsTimer;

  StreamSubscription<void>? _notifDisconnectSub;
  DateTime? _lastNotifUpdate;

  bool   _dashOverlayVisible = false;
  Timer? _overlayHideTimer;

  bool _socAlertFired     = false;
  bool _tempAlertFired    = false;
  bool _cellAlertFired    = false;
  // ICE-specifikus riasztási flagek
  bool _coolantAlertFired = false;
  bool _fuelAlertFired    = false;
  // Aktív riasztások halmaza — a képernyős banner ehhez köt.
  final Set<String> _activeAlerts = {};

  VehicleProfile get _p => widget.profile;
  bool get _isEv   => _p.evDataGroups.isNotEmpty;
  bool get _isPhev => _p.drivetrain == DrivetrainType.phev;
  bool get _isDashboard => _viewMode != 'list';

  AppLocalizations get _l10n => context.read<LocaleNotifier>().strings;

  List<_DashDef> get _evDashes {
    final l = _l10n;
    return [
      _DashDef('driving',       l.dashDriving,         Icons.speed),
      _DashDef('battery',       l.dashBattery,         Icons.battery_charging_full),
      _DashDef('charging',      l.dashChargingMonitor, Icons.electric_bolt),
      _DashDef('chart',         l.dashChart,           Icons.show_chart),
      _DashDef('custom_charts', l.dashCustomCharts,    Icons.dashboard_customize),
      _DashDef('sensors',       l.dashSensors,         Icons.sensors),
      _DashDef('kitt',          'K.I.T.T.',            Icons.auto_awesome),
    ];
  }

  List<_DashDef> get _iceDashes {
    final l = _l10n;
    return [
      _DashDef('ice_driving',   l.dashInstrumentPanel, Icons.speed),
      _DashDef('chart',         l.dashChart,           Icons.show_chart),
      _DashDef('custom_charts', l.dashCustomCharts,    Icons.dashboard_customize),
      _DashDef('sensors',       l.dashSensors,         Icons.sensors),
      _DashDef('kitt',          'K.I.T.T.',            Icons.auto_awesome),
    ];
  }

  /// PHEV nézetek: EV kijelző, akkumulátor, töltés, Plugin (kombinált),
  /// ICE kijelző, grafikon, egyéni grafikonok, szenzornézet, K.I.T.T.
  List<_DashDef> get _phevDashes {
    final l = _l10n;
    return [
      _DashDef('driving',       l.dashDriving,         Icons.electric_bolt),
      _DashDef('battery',       l.dashBattery,         Icons.battery_charging_full),
      _DashDef('charging',      l.dashChargingMonitor, Icons.power),
      _DashDef('phev',          l.dashPhevPlugin,      Icons.merge_type),
      _DashDef('phev_ice',      l.dashPhevIce,         Icons.local_gas_station),
      _DashDef('chart',         l.dashChart,           Icons.show_chart),
      _DashDef('custom_charts', l.dashCustomCharts,    Icons.dashboard_customize),
      _DashDef('sensors',       l.dashSensors,         Icons.sensors),
      _DashDef('kitt',          'K.I.T.T.',            Icons.auto_awesome),
    ];
  }

  @override
  void initState() {
    super.initState();
    _conn = widget.connection;
    WidgetsBinding.instance.addObserver(this);
    // AppSettings().init() már a main.dart-ban lefutott (idempotens singleton).
    _statusText = _l10n.initializing;
    _initValues();
    _runInit();
    // Értesítés "Lecsatlakozás" gomb → navigál vissza
    _notifDisconnectSub = NotificationService()
        .onDisconnectRequested
        .listen((_) => _handleNotifDisconnect());
  }

  // Képernyőzárkor a polling folytatódik, háttérből visszatéréskor ellenőrzi a kapcsolat állapotát.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Polling folytatódik — ForegroundService tartja életben a folyamatot.
        break;
      case AppLifecycleState.resumed:
        NotificationService()
            .checkAndClearDisconnectFlag()
            .then((requested) {
          if (!mounted || _disposed) return;
          if (requested) {
            _handleNotifDisconnect();
            return;
          }
          if (!_isInitializing && !_conn.isConnected) {
            // Kapcsolat az app háttérben léte alatt megszakadt.
            _stopPolling();
            _endTrip();
            _stopForegroundService();
            NotificationService().dismiss();
            setState(() => _viewMode = 'list');
            if (widget.reconnectFn != null) {
              // Ha van gyár-függvény, azonnal próbáljuk meg az újrakapcsolódást.
              _attemptReconnect();
            } else {
              setState(() => _statusText = _l10n.noActiveConnection);
            }
          }
        });
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _handleNotifDisconnect() {
    if (!mounted || _disposed) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _initValues() {
    if (_isEv) {
      for (final g in _p.evDataGroups)
        for (final f in g.fields) _currentValues[f.id] = '--';
    } else {
      for (final p in _p.stdPids) _currentValues[p.code] = '--';
    }
  }

  Future<void> _runInit() async {
    _setStatus(_l10n.adapterReset);
    try { await _conn.sendCommand('\r'); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 200));
    for (int a = 1; a <= 3; a++) {
      if (_disposed) return;
      _setStatus(_l10n.resetAttempt(a));
      try {
        final r = await _conn.sendAndWait('AT Z\r',
            timeout: const Duration(seconds: 5));
        if (r.toUpperCase().contains('ELM')) break;
      } on TimeoutException {
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) {}
    }
    await Future.delayed(const Duration(seconds: 1));
    if (_disposed) return;
    for (final cmd in [
      'AT E0\r', 'AT L0\r', 'AT H0\r', 'AT S0\r',
      if (_isEv) 'AT AL\r', // Allow Long — multi-frame UDS válaszokhoz (EV/PHEV)
      'AT SP ${_p.obdProtocol}\r',
    ]) {
      if (_disposed) return;
      _setStatus(_l10n.configuring);
      try { await _conn.sendAndWait(cmd,
          timeout: const Duration(seconds: 3)); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!_disposed && _isEv) {
      final g = _p.evDataGroups.first;
      await _sendAt('AT SH ${g.canHeader}');
      _setStatus(_l10n.ecuTest);
      try {
        final r = await _conn.sendAndWait('${g.command}\r',
            timeout: const Duration(seconds: 10));
        if (MultiframeParser.parse(r).isEmpty) _setStatus(_l10n.ecuNotResponding);
      } on TimeoutException { _setStatus(_l10n.ecuNotResponding); } catch (_) {}
    } else if (!_disposed) {
      try { await _conn.sendAndWait('0100\r',
          timeout: const Duration(seconds: 15)); } catch (_) {}
    }
    if (_disposed) return;
    await FileLogger().log('INIT', 'Kész. Polling indul.');
    if (mounted) setState(() {
      _isInitializing = false;
      if (!_statusText.contains(_l10n.ecuNotResponding)) _statusText = _l10n.liveConnection;
    });
    _startPolling();
  }

  Future<void> _sendAt(String cmd) async {
    try { await _conn.sendAndWait('$cmd\r',
        timeout: const Duration(seconds: 2)); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 50));
  }

  void _setStatus(String t) {
    if (!mounted || _disposed) return;
    if (_statusText == t) return; // ne építsünk fel azonos értékkel
    setState(() => _statusText = t);
  }

  void _startPolling() {
    if (_polling || _disposed) return;
    _polling = true;
    // ForegroundService indítása — folyamat életben marad képernyőzár alatt
    _startForegroundService();
    // Előtér értesítés megjelenítése (felülírja a service placeholder értesítését)
    NotificationService().show(
      deviceName: _p.displayName,
      status: _l10n.connected,
      disconnectLabel: _l10n.disconnect,
    );
    _initTrip();           // minden járműnél: menetnapló + GPS készítése
    _startGpsTracking();   // minden járműnél: GPS rögzítés 10 másodpercenként
    if (_isEv) {
      _refreshExternalTemp();
      _maybeRefreshLearnedWh(); // historikus Wh/km betöltése rögtön az induláskor
      _pollEv();
    } else {
      _pollIce();
    }
  }

  /// Értesítés frissítése 20 másodpercenként SOC-kal és töltési státusszal.
  void _updateNotification() {
    final now = DateTime.now();
    if (_lastNotifUpdate != null &&
        now.difference(_lastNotifUpdate!).inSeconds < 20) return;
    _lastNotifUpdate = now;
    final soc = _rawValues['soc_display'] ?? _raw('soc_bms');
    final status = _isCharging ? _l10n.charging : _l10n.connected;
    NotificationService().update(soc: soc, status: status);
  }

  /// Küszöb-riasztások ellenőrzése minden EV poll ciklus végén.
  ///
  /// Logika:
  ///  – Egy típusból egyszerre csak 1 értesítés él (flag védi az ismétlést).
  ///  – Hisztérézis gátolja a villogást: a flag csak akkor törlődik, ha az
  ///    érték kellően visszatért a biztonságos zónába.
  ///  – Csak érvényes szenzor adat esetén fut (pl. soc > 0, temp > −50).
  void _checkAlerts() {
    final s = AppSettings();

    final soc    = _rawValues['soc_display'] ?? _raw('soc_bms');
    final socMin = s.alertSocMin;
    if (soc > 0) {
      if (!_socAlertFired && soc <= socMin) {
        _socAlertFired = true;
        setState(() => _activeAlerts.add('soc'));
        NotificationService().showAlert(
          type:  'soc',
          title: '⚠ ${_l10n.lowSoc}',
          body:  'SOC: ${soc.toStringAsFixed(0)}%  •  '
                 '${_l10n.thresholdLabel}: ${socMin.toStringAsFixed(0)}%',
        );
      } else if (_socAlertFired && soc > socMin + 2) {
        _socAlertFired = false;
        setState(() => _activeAlerts.remove('soc'));
        NotificationService().dismissAlert('soc');
      }
    }

    final temp    = _raw('battery_temp_max');
    final tempMax = s.alertTempMax;
    if (temp > -50) {           // szenzor -40 offset sentinel kizárása
      if (!_tempAlertFired && temp >= tempMax) {
        _tempAlertFired = true;
        setState(() => _activeAlerts.add('temp'));
        NotificationService().showAlert(
          type:  'temp',
          title: '⚠ ${_l10n.highBatteryTemp}',
          body:  '${temp.toStringAsFixed(0)}°C  •  '
                 '${_l10n.thresholdLabel}: ${tempMax.toStringAsFixed(0)}°C',
        );
      } else if (_tempAlertFired && temp < tempMax - 2) {
        _tempAlertFired = false;
        setState(() => _activeAlerts.remove('temp'));
        NotificationService().dismissAlert('temp');
      }
    }

    final spread    = _raw('cell_volt_spread');  // mV
    final spreadMax = s.alertCellSpread;
    if (spread > 0) {           // csak ha cella adatok érkeztek
      if (!_cellAlertFired && spread >= spreadMax) {
        _cellAlertFired = true;
        setState(() => _activeAlerts.add('cell'));
        NotificationService().showAlert(
          type:  'cell',
          title: '⚠ ${_l10n.cellImbalance}',
          body:  'Max–Min: ${spread.toStringAsFixed(0)} mV  •  '
                 '${_l10n.thresholdLabel}: ${spreadMax.toStringAsFixed(0)} mV',
        );
      } else if (_cellAlertFired && spread < spreadMax - 5) {
        _cellAlertFired = false;
        setState(() => _activeAlerts.remove('cell'));
        NotificationService().dismissAlert('cell');
      }
    }

    // ── ICE riasztások: hűtővíz hőmérséklet és üzemanyag szint ─────────────
    // ICE: OBD PID kódok ('0105', '012F')
    // PHEV: EV field ID-k ('coolant_temp', 'fuel_level') — mindkét forrást nézzük
    final hasCoolant = !_isEv || _isPhev;
    final hasFuel    = !_isEv || _isPhev;

    if (hasCoolant) {
      // ICE: standard OBD PID; PHEV: EV field ID
      final coolant = !_isEv
          ? (_rawValues['0105'] ?? 0.0)
          : (_rawValues['coolant_temp'] ?? 0.0);
      final coolantMax = s.alertCoolantMax;
      if (coolant > 0) {
        if (!_coolantAlertFired && coolant >= coolantMax) {
          _coolantAlertFired = true;
          setState(() => _activeAlerts.add('coolant'));
          NotificationService().showAlert(
            type:  'coolant',
            title: '⚠ ${_l10n.highCoolantTemp}',
            body:  '${coolant.toStringAsFixed(0)}°C  •  '
                   '${_l10n.thresholdLabel}: ${coolantMax.toStringAsFixed(0)}°C',
          );
        } else if (_coolantAlertFired && coolant < coolantMax - 3) {
          _coolantAlertFired = false;
          setState(() => _activeAlerts.remove('coolant'));
          NotificationService().dismissAlert('coolant');
        }
      }
    }

    if (hasFuel) {
      // ICE: standard OBD PID; PHEV: EV field ID
      final fuel    = !_isEv
          ? (_rawValues['012F'] ?? 0.0)
          : (_rawValues['fuel_level'] ?? 0.0);
      final fuelMin = s.alertFuelMin;
      if (fuel > 0) {
        if (!_fuelAlertFired && fuel <= fuelMin) {
          _fuelAlertFired = true;
          setState(() => _activeAlerts.add('fuel'));
          NotificationService().showAlert(
            type:  'fuel',
            title: '⚠ ${_l10n.lowFuelLevel}',
            body:  '${_l10n.fuelLabel}: ${fuel.toStringAsFixed(0)}%  •  '
                   '${_l10n.thresholdLabel}: ${fuelMin.toStringAsFixed(0)}%',
          );
        } else if (_fuelAlertFired && fuel > fuelMin + 5) {
          _fuelAlertFired = false;
          setState(() => _activeAlerts.remove('fuel'));
          NotificationService().dismissAlert('fuel');
        }
      }
    }
  }

  void _stopPolling() {
    _polling = false;
    _gpsTimer?.cancel();
    _gpsTimer = null;
  }

  /// Automatikus újrakapcsolódás — a meglévő oldalon marad, új kapcsolatot épít.
  /// Csak akkor hívható, ha [widget.reconnectFn] meg van adva.
  Future<void> _attemptReconnect() async {
    if (widget.reconnectFn == null || _isReconnecting || _disposed) return;
    setState(() {
      _isReconnecting = true;
      _isInitializing = true;
      _statusText = _l10n.reconnecting;
    });
    try {
      final oldConn = _conn;
      final newConn = await widget.reconnectFn!();
      // Régi kapcsolat lezárása (lehet már closed, ezért catchError)
      oldConn.close().catchError((_) {});
      if (_disposed || !mounted) {
        newConn.close().catchError((_) {});
        return;
      }
      _conn = newConn;
      setState(() => _isReconnecting = false);
      await FileLogger().log('Reconnect', 'Sikeres újrakapcsolódás.');
      await _runInit();          // inicializál + _startPolling() a végén
    } catch (e) {
      await FileLogger().error('Reconnect', 'Újrakapcsolódás sikertelen', e);
      if (!mounted || _disposed) return;
      setState(() {
        _isReconnecting = false;
        _isInitializing = false;
        _statusText = _l10n.noActiveConnection;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.autoConnectFailed),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Natív OBDForegroundService indítása — polling képernyőzár alatt is él.
  void _startForegroundService() {
    _fgChannel.invokeMethod('startForegroundService').catchError((Object e) {
      // Ha a service nem indul, a polling háttérben elhalhat — ezt fontos
      // látni a debug naplóban, de a UI-t nem blokkolja.
      FileLogger().log('FgService', 'start failed: $e');
    });
  }

  /// Natív OBDForegroundService leállítása — lecsatlakozáskor.
  void _stopForegroundService() {
    _fgChannel.invokeMethod('stopForegroundService').catchError((Object e) {
      FileLogger().log('FgService', 'stop failed: $e');
    });
  }

  void _initTrip() {
    // Előző session lezáratlan ("zombi") meneteit takarítjuk el aszinkron.
    // Ez nem blokkolja az init-et — az új trip előkészítése párhuzamosan fut.
    _closeZombieTrips();

    _tripId = '${DateTime.now().millisecondsSinceEpoch}';
    _tripStart = DateTime.now();
    _tripStartSoc = 0;
    _tripStartEnergy = 0;
    // ICE járműnél nincs SOC adat — az első poll után azonnal érvényes a menet.
    // (A flag neve EV-specifikus, ICE esetén azt jelzi: nem kell SOC-ot várni.)
    _tripStartSocRecorded = !_isEv;
    _tripMaxSpeed = 0;
    _tripSpeedSum = 0;
    _tripSpeedCount = 0;
    _tripLastSave = DateTime.now();
    // Wh/km reset
    _lastPollTime = null;
    _tripDistanceKm = 0;
    _tripEnergyWh = 0;
    _rollingWhPerKm = 0;
    // GPS útvonal reset
    _gpsRoute.clear();
  }

  /// Előző sessionből visszamaradt lezáratlan ("zombi") meneteket zárja le.
  /// Érvénytelen (SOC=0) rekordok törlésre kerülnek, érvényesek lezárásra.
  /// Teljesen aszinkron — nem befolyásolja az aktuális trip indítását.
  ///
  /// A végső időponthoz a trip ID-jét (millisecondsSinceEpoch) használjuk,
  /// nem a jelenlegi időt — így a rekord nem kap torz, órákon átnyúló időtartamot
  /// csak azért, mert a felhasználó a következő menetet napokkal később indítja.
  /// Az ID alapján megbecsült végpont: startedAt + max 4 óra (biztonsági korlát).
  Future<void> _closeZombieTrips() async {
    try {
      final all = await TripStorage.loadAll();
      for (final t in all.where((t) => t.isActive)) {
        // startSoc == 0 EV esetén azt jelenti: nem volt érvényes adat → törlés.
        // ICE trip-nek nincs SOC-ja, de lehet GPS adata — azokat meg kell tartani.
        final noData = t.startSoc <= 0 && t.route.isEmpty;
        if (noData) {
          // Nincs érvényes adat → törlés
          await TripStorage.delete(t.id);
        } else {
          // Lezárjuk a startedAt + max 4 óra korláttal — nem a jelenlegi idővel,
          // hogy a rekord ne kapjon napokig nyúló hamis időtartamot.
          final reasonableEnd = t.startedAt.add(const Duration(hours: 4));
          final clampedEnd = reasonableEnd.isBefore(DateTime.now())
              ? reasonableEnd
              : DateTime.now();
          await TripStorage.save(t.copyWith(endedAt: clampedEnd));
        }
      }
    } catch (e) {
      FileLogger().log('Trips', 'orphan cleanup failed: $e');
    }
  }

  void _endTrip() {
    if (_tripId == null) return;
    final id = _tripId!;

    // Nem volt érvényes SOC adat: az adapter nem válaszolt egyszer sem.
    if (!_tripStartSocRecorded) {
      _tripId = null;
      TripStorage.delete(id);
      return;
    }
    // Kevesebb mint 60 másodperc: csatlakozás + azonnal lekapcsolt.
    if (_tripStart != null &&
        DateTime.now().difference(_tripStart!).inSeconds < 60) {
      _tripId = null;
      TripStorage.delete(id);
      return;
    }

    // mentés után nullázunk, különben az early-return elkapja
    _saveTripToStorage(endedAt: DateTime.now());
    _tripId = null;
  }

  /// Elmenti az aktuális töltési session görbéjét a ChargeStorage-ba.
  /// Legalább 3 adatpont kell — rövidebb sessiont (pl. véletlen detektálás)
  /// figyelmen kívül hagyjuk.
  void _saveChargeSession() {
    if (_chargePoints.length < 3) return;
    final peakKw = _chargePoints
        .map((p) => p.powerKw)
        .reduce(math.max);
    ChargeStorage.save(ChargeSession(
      id:          '${DateTime.now().millisecondsSinceEpoch}',
      vehicleId:   _p.id,
      vehicleName: _p.displayName,
      startedAt:   _chargeSessionStart ?? _chargePoints.first.time,
      endedAt:     DateTime.now(),
      startSoc:    _chargePoints.first.soc,
      endSoc:      _chargePoints.last.soc,
      peakPowerKw: peakKw,
      addedKwh:    _chargedKwh,
      points:      List.unmodifiable(_chargePoints),
    ));
  }

  void _saveTripToStorage({DateTime? endedAt}) {
    if (_tripId == null || _tripStart == null) return;
    final curSoc =
        _rawValues['soc_display'] ?? _rawValues['soc_bms'] ?? _tripStartSoc;
    final curEnergy = _raw('remaining_kwh');
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
      route: List.from(_gpsRoute),
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

    final speed   = _raw('speed').abs();   // km/h
    final power   = _raw('battery_power'); // kW (negatív = tölt)
    final current = _raw('battery_current'); // A (negatív = tölt)

    final charging = current < -1.0 && speed < 1.0;
    if (charging != _isCharging) {
      if (charging) {
        // Új töltési session kezdete — görbeadatok resetje
        _chargeSessionStart = now;
        _chargeSessionStartEnergy = _raw('remaining_kwh');
        _chargedKwh = 0;
        _chargePoints.clear();
        _lastChargePoint = null;
      } else {
        // Töltési session vége — adatok mentése (ha volt elég pont)
        _saveChargeSession();
      }
      if (mounted) setState(() => _isCharging = charging);
    }

    if (charging) {
      // Hozzáadott kWh kiszámítása (remaining_kwh növekedése)
      final curEnergy = _raw('remaining_kwh');
      if (_chargeSessionStartEnergy > 0 && curEnergy > _chargeSessionStartEnergy) {
        if (mounted) setState(() {
          _chargedKwh = curEnergy - _chargeSessionStartEnergy;
          _currentValues['charged_kwh'] = _chargedKwh.toStringAsFixed(2);
        });
      }

      // 10 másodpercenként rögzítünk egy pontot
      if (_lastChargePoint == null ||
          now.difference(_lastChargePoint!).inSeconds >= 10) {
        _lastChargePoint = now;
        final soc = _rawValues['soc_display'] ?? _raw('soc_bms');
        final v   = _raw('battery_voltage');
        final pw  = v > 0 ? v * current.abs() / 1000.0 : 0.0;
        final tmp = _raw('battery_temp_max');
        // Csak akkor rögzítünk, ha mindkét adat érvényes
        if (soc > 0 && pw > 0.1) {
          setState(() {
            _chargePoints.add(ChargeDataPoint(
              soc:     soc,
              powerKw: pw,
              tempC:   tmp > -50 ? tmp : 0.0,
              time:    now,
            ));
          });
        }
      }

      return; // Töltés alatt nem számolunk Wh/km-t
    }

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

  /// Kültéri hőmérséklet lekérése háttérben (15 perces gyorsítótár).
  void _refreshExternalTemp() {
    WeatherService().fetchTemperature().then((temp) {
      if (temp != null && mounted) setState(() => _externalTemp = temp);
    }).catchError((Object e) {
      // Hálózati hiba esetén nem blokkoljuk a UI-t, csak a fájl-naplóba írunk.
      FileLogger().log('Weather', 'fetch failed: $e');
    });
  }

  // Tárolt menetekből súlyozott átlag Wh/km érték számítása (max 60 mp-enként).
  void _maybeRefreshLearnedWh() {
    final now = DateTime.now();
    if (_lastLearnRefresh != null &&
        now.difference(_lastLearnRefresh!).inSeconds < 60) return;
    _lastLearnRefresh = now;

    TripStorage.loadAll().then((trips) {
      // Csak befejezett, minimálisan 2 km-es, érvényes Wh/km adattal rendelkező menetek
      final valid = trips
          .where((t) =>
              t.vehicleId == _p.id &&
              !t.isActive &&
              t.whPerKm > 50 &&
              t.distanceKm > 2.0)
          .toList();

      if (valid.isEmpty) {
        if (mounted) setState(() { _learnedWhPerKm = null; _learnedTripCount = 0; });
        return;
      }

      double wSum = 0.0, wTot = 0.0;
      final ref = DateTime.now();
      for (final t in valid.take(50)) {
        final ageDays = ref.difference(t.startedAt).inDays.toDouble();
        // exp(−kor/60): 0 napos menet → 1.0, 60 napos → 0.37, 120 napos → 0.14
        final w = t.distanceKm * math.exp(-ageDays / 60.0);
        wSum += t.whPerKm * w;
        wTot += w;
      }

      if (mounted) setState(() {
        _learnedWhPerKm   = wTot > 0 ? wSum / wTot : null;
        _learnedTripCount = valid.length;
      });
    });
  }

  // Kilométeróra lekérése a műszerfal ECU-tól (7C6), max 60 mp-enként.
  void _maybeQueryOdometer() {
    if (_p.evPlatform != 'hk_legacy') return;
    final now = DateTime.now();
    if (_lastOdoQuery != null &&
        now.difference(_lastOdoQuery!).inSeconds < 60) return;
    _lastOdoQuery = now;
    _queryOdometer();
  }

  Future<void> _queryOdometer() async {
    if (_disposed || !_conn.isConnected) return;
    try {
      await _sendAt('AT SH 7C6');
      final r = await _conn.sendAndWait('22B002\r',
          timeout: const Duration(seconds: 3));
      final bytes = MultiframeParser.parse(r);

      if (bytes.length >= 6) {
        final raw = bytes[3] * 65536 + bytes[4] * 256 + bytes[5];
        // Sanity check: 0 és 2 000 000 km között reális
        if (raw > 0 && raw < 2000000) {
          final odo = raw.toDouble();
          final ced = _raw('ced');
          if (mounted) setState(() {
            _odometerKm = odo;
            _currentValues['odometer_km'] = odo.toStringAsFixed(0);
            _rawValues['odometer_km']     = odo;
            // Élettartam Wh/km csak ha van CED adat is
            if (ced > 0) _lifetimeWhPerKm = ced * 1000.0 / odo;
          });
        }
      }
    } catch (e) {
      // Sikertelen lekérdezés — következő ciklus újrapróbálja
      FileLogger().log('Odometer', 'query failed: $e');
    } finally {
      // CAN header visszaállítása a BMS-re, hogy a következő poll rendben fusson
      if (!_disposed && _conn.isConnected) {
        await _sendAt('AT SH 7E4');
      }
    }
  }

  // ── GPS útvonal rögzítése ────────────────────────────────────────────────────

  /// GPS engedély ellenőrzése és 10 másodperces polling indítása.
  /// Ha az engedély hiányzik, kéri a felhasználótól; megtagadás esetén csendes.
  Future<void> _startGpsTracking() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      // Első pont azonnal, utána 10 másodpercenként
      await _recordGpsPoint();
      _gpsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _recordGpsPoint();
      });
    } catch (e) {
      debugPrint('GPS tracking init error: $e');
    }
  }

  /// Lekéri az aktuális GPS pozíciót és hozzáadja az útvonalhoz.
  /// Ha a lekérés 8 másodpercen belül nem sikerül (pl. GPS fix nincs), kihagyja.
  Future<void> _recordGpsPoint() async {
    if (_disposed || _tripId == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));
      if (_disposed || !mounted) return;
      setState(() {
        _gpsRoute.add(TripLatLng(pos.latitude, pos.longitude));
      });
    } catch (_) {
      // Timeout vagy nincs GPS jel — kihagyja ezt a pontot
    }
  }

  // Hatótáv-becsléshez Wh/km érték: history > élettartam > session > fallback sorrendben.
  double _computeRangeWhPerKm() {
    final settings = AppSettings();
    if (settings.rangeMode == 2) return settings.whPerKmFallback; // manuális

    final hasHistory  = _learnedWhPerKm != null && _learnedWhPerKm! > 0;
    final hasLifetime = _lifetimeWhPerKm != null && _lifetimeWhPerKm! > 0;
    final hasSession  = _rollingWhPerKm > 50;

    final base0 = hasHistory
        ? _learnedWhPerKm!
        : hasLifetime
            ? _lifetimeWhPerKm!
            : settings.whPerKmFallback;

    final sessConf = (_tripDistanceKm / 15.0).clamp(0.0, 1.0);
    double base;
    if (hasSession) {
      final sw = sessConf * 0.7;
      base = base0 * (1.0 - sw) + _rollingWhPerKm * sw;
    } else {
      base = base0;
    }

    if (settings.rangeMode == 1 && _externalTemp != null) {
      base = base / WeatherService.efficiencyFactor(_externalTemp!);
    }

    return base.clamp(50.0, 500.0);
  }

  /// Egyéni grafikon sample rögzítése (max 2 másodpercenként).
  /// A _rawValues aktuális pillanatképét másolja egy OBDSample-be.
  /// Max 600 elem → kb. 20 perces előzmény, ~50 kB memória.
  void _maybeAddSample() {
    if (_rawValues.isEmpty) return;
    final now = DateTime.now();
    if (_lastSampleTime != null &&
        now.difference(_lastSampleTime!).inSeconds < 2) return;
    _lastSampleTime = now;
    final snapshot = Map<String, double>.unmodifiable(Map.from(_rawValues));
    if (!mounted) return;
    setState(() {
      _sampleHistory.add(OBDSample(time: now, values: snapshot));
      if (_sampleHistory.length > 600) _sampleHistory.removeAt(0);
    });
  }

  void _addChartPoint() {
    final soc   = _rawValues['soc_display'] ?? _raw('soc_bms');
    final power = _raw('battery_power');
    final speed = _raw('speed').abs();
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
    while (_polling && !_disposed && _conn.isConnected) {
      bool any = false;
      for (final g in _p.evDataGroups) {
        if (!_polling || _disposed) break;
        await _sendAt('AT SH ${g.canHeader}');
        try {
          final r = await _conn.sendAndWait('${g.command}\r',
              timeout: const Duration(seconds: 5));
          final bytes = MultiframeParser.parse(r);
          final hexDump = bytes.isNotEmpty ? MultiframeParser.hexDump(bytes) : '';
          _obdLogAdd(ObdLogEntry(
            time: DateTime.now(),
            canHeader: g.canHeader,
            command: g.command,
            rawHex: hexDump,
            ok: bytes.isNotEmpty,
          ));
          if (bytes.isEmpty) { errors++; continue; }
          await FileLogger().log('EV RX',
              '${g.name} → ${bytes.length} bytes: $hexDump');
          if (_disposed || !mounted) return;
          any = true; errors = 0;

          setState(() {
            _hexDumps[g.name] = hexDump;
            for (final f in g.fields) {
              if (f.startByte < 0) continue;
              final v = MultiframeParser.extractValue(bytes,
                  startByte: f.startByte, byteCount: f.byteCount,
                  signed: f.signed, factor: f.factor, offset: f.offset,
                  littleEndian: f.littleEndian);
              if (v == null) continue;
              if (v < f.minValue || v > f.maxValue) continue;
              _rawValues[f.id] = v;
              _currentValues[f.id] =
                  f.id == 'speed' ? _fmt(v.abs(), f) : _fmt(v, f);
            }
          });
          _computeDerived(g, bytes);
        } on TimeoutException { errors++;
        } catch (e) {
          if (!_conn.isConnected) {
            _polling = false;
            _endTrip();           // lezárjuk a menetet ha a kapcsolat megszakad
            _stopForegroundService();
            _setStatus(_l10n.connectionLost);
            return;
          }
        }
      }
      if (any) {
        // Start SOC rögzítése az első valós adat után
        if (!_tripStartSocRecorded) {
          final soc = _rawValues['soc_display'] ?? _raw('soc_bms');
          if (soc > 0) {
            _tripStartSoc = soc;
            _tripStartEnergy = _raw('remaining_kwh');
            _tripStartSocRecorded = true;
          }
        }
        // Sebesség frissítése a trip statisztikához
        final spd = _raw('speed').abs();
        if (spd > 1) {
          _tripSpeedSum += spd;
          _tripSpeedCount++;
          if (spd > _tripMaxSpeed) _tripMaxSpeed = spd;
        }
        // Wh/km integrálás + töltés detektálás
        _updateEnergyTracking();
        // Grafikon pont
        _addChartPoint();
        // Értesítés frissítése + küszöb-riasztás ellenőrzés
        _updateNotification();
        _checkAlerts();
        // Trip mentés 10 másodpercenként
        if (_tripLastSave != null &&
            DateTime.now().difference(_tripLastSave!).inSeconds >= 10) {
          _saveTripToStorage();
          _tripLastSave = DateTime.now();
        }
      }

      if (errors > _p.evDataGroups.length * 3)
        _setStatus(_l10n.noDataIgnition);
      else if (any && _statusText != _l10n.liveConnection)
        _setStatus(_l10n.liveConnection);

      // Odometer lekérése a ciklus végén — nem zavarja a BMS pollozást
      _maybeQueryOdometer();

      // Egyéni grafikon sample (2 másodpercenként)
      _maybeAddSample();

      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _pollIce() async {
    int idx = 0;
    while (_polling && !_disposed && _conn.isConnected) {
      final p = _p.stdPids[idx % _p.stdPids.length]; idx++;
      try {
        final r = await _conn.sendAndWait('${p.code}\r',
            timeout: const Duration(seconds: 3));
        if (_disposed || !mounted) return;
        // ICE raw logolás (az r-ből a whitespace-mentes hex sorok)
        final rawTrimmed = r.trim().replaceAll('\r', ' ').replaceAll('\n', ' ');
        final hasResp = rawTrimmed.isNotEmpty && !rawTrimmed.startsWith('NO DATA');
        _obdLogAdd(ObdLogEntry(
          time: DateTime.now(),
          canHeader: '',
          command: p.code,
          rawHex: hasResp ? rawTrimmed : '',
          ok: hasResp,
        ));
        final parsed = ObdParser.parseGeneric(r, p.code);
        final asDouble = double.tryParse(parsed);
        setState(() {
          _currentValues[p.code] = parsed;
          if (asDouble != null) _rawValues[p.code] = asDouble;
        });

        // Sebesség (PID 010D) alapú távolság és trip statisztika
        if (p.code == '010D' && asDouble != null) {
          final speed = asDouble.abs();
          if (speed > 300) continue;
          final now = DateTime.now();
          if (_lastPollTime != null) {
            final dt = now.difference(_lastPollTime!).inMilliseconds / 1000.0;
            if (dt > 0 && dt <= 10 && speed > 1) {
              _tripDistanceKm += speed * dt / 3600.0;
            }
          }
          _lastPollTime = now;
          if (speed > 1) {
            _tripSpeedSum   += speed;
            _tripSpeedCount++;
            if (speed > _tripMaxSpeed) _tripMaxSpeed = speed;
          }
        }
      } catch (e) {
        // TimeoutException: adapter lassan válaszol → továbblépünk.
        // Egyéb (StateError, socket hiba): ha a kapcsolat elveszett, kilépünk.
        if (!_conn.isConnected) {
          _polling = false;
          _endTrip();
          _stopForegroundService();
          _setStatus(_l10n.connectionLost);
          return;
        }
      }
      // Menetmentés 10 másodpercenként
      if (_tripLastSave != null &&
          DateTime.now().difference(_tripLastSave!).inSeconds >= 10) {
        _saveTripToStorage();
        _tripLastSave = DateTime.now();
      }
      // Egyéni grafikon sample (2 másodpercenként)
      _maybeAddSample();
      // ICE riasztások ellenőrzése (hűtővíz, üzemanyag)
      _checkAlerts();
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  void _computeDerived(EvDataGroup g, List<int> bytes) {
    if (!mounted || _disposed) return;

    if ((g.command == '2102' || g.command == '2103' || g.command == '2104')
        && g.canHeader == '7E4') {
      // 1 bájt/cella, faktor 0.02 V
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
      final v = _raw('battery_voltage');
      final i = _raw('battery_current');
      if (v > 0) {
        final pw = v * i / 1000.0;
        setState(() { _rawValues['battery_power'] = pw;
        _currentValues['battery_power'] = pw.toStringAsFixed(1); });
      }
      // Maradék kWh + hatótáv becslés
      final soc = _raw('soc_bms');
      if (soc > 0) {
        final nomCap = _p.batteryCapacityKwh > 0 ? _p.batteryCapacityKwh : 28.0;
        final soh    = _raw('soh');
        // Valós kapacitás: névleges × SOH (ha ismert)
        final cap = soh > 50 ? nomCap * soh / 100.0 : nomCap;
        final rem = soc * cap / 100.0;

        // History frissítési kísérlet (max 60 mp-enként fut egyszer)
        _maybeRefreshLearnedWh();

        // Wh/km meghatározása: history + session blend
        final whPerKm  = _computeRangeWhPerKm();
        final rangeKm  = rem  * 1000.0 / whPerKm;
        final maxRange = cap  * 1000.0 / whPerKm;

        // Debug szöveg forráshoz
        final rMode  = AppSettings().rangeMode;
        final l = _l10n;
        final whSrc  = rMode == 2
            ? l.rangeManual
            : rMode == 1
                ? 'temp (${_externalTemp?.toStringAsFixed(1) ?? "?"}°C)'
                : _learnedWhPerKm != null && _rollingWhPerKm > 50
                    ? 'history+session (${l.dbgTripsLabel(_learnedTripCount)})'
                    : _learnedWhPerKm != null
                        ? 'history (${l.dbgTripsLabel(_learnedTripCount)})'
                        : _lifetimeWhPerKm != null && _rollingWhPerKm > 50
                            ? 'lifetime+session'
                            : _lifetimeWhPerKm != null
                                ? 'lifetime (CED÷km)'
                                : _rollingWhPerKm > 50
                                    ? 'session'
                                    : l.dbgDefault;

        setState(() {
          _rawValues['remaining_kwh']     = rem;
          _currentValues['remaining_kwh'] = rem.toStringAsFixed(1);
          _rawValues['range_km']          = rangeKm;
          _rawValues['range_km_max']      = maxRange;
          _currentValues['range_km']      = rangeKm.toStringAsFixed(0);
          _currentValues['range_km_max']  = maxRange.toStringAsFixed(0);
          _rangeDebug = {
            'SOC (BMS)':              '${soc.toStringAsFixed(2)} %',
            'SOH':                    soh > 0 ? '${soh.toStringAsFixed(1)} %' : l.dbgUnknown,
            l.dbgNominalCapacity:     '${nomCap.toStringAsFixed(1)} kWh',
            l.dbgActualCapacity:      '${cap.toStringAsFixed(2)} kWh',
            l.remainingEnergyLabel:   '${rem.toStringAsFixed(3)} kWh',
            'App history Wh/km':      _learnedWhPerKm != null
                ? '${_learnedWhPerKm!.toStringAsFixed(0)} Wh/km (${l.dbgTripsLabel(_learnedTripCount)})'
                : l.dbgNotEnoughData,
            l.dbgLifetimeWhKm:        _lifetimeWhPerKm != null
                ? '${_lifetimeWhPerKm!.toStringAsFixed(0)} Wh/km'
                  ' (km: ${_odometerKm.toStringAsFixed(0)})'
                : l.dbgOdometerUnreadable,
            'Session Wh/km':          _rollingWhPerKm > 0
                ? '${_rollingWhPerKm.toStringAsFixed(0)} Wh/km'
                  ' (${_tripDistanceKm.toStringAsFixed(1)} km)'
                : '--',
            l.dbgExternalTemp:        _externalTemp != null
                ? '${_externalTemp!.toStringAsFixed(1)} °C'
                : l.dbgUnknown,
            l.dbgWhSource:            whSrc,
            l.dbgFinalWh:             '${whPerKm.toStringAsFixed(0)} Wh/km',
            l.rangeEstimateLabel:     '${rangeKm.toStringAsFixed(1)} km',
            l.dbgMaxRange:            '${maxRange.toStringAsFixed(1)} km',
          };
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

    // ── Ford Kuga PHEV (ford_phev platform) ─────────────────────────────────
    if (_p.evPlatform == 'ford_phev') {
      // 1. Teljesítmény — áram beérkezésekor (BECM_Curr: 2248F9)
      if (g.command == '2248F9') {
        final v = _raw('battery_voltage');
        final i = _raw('battery_current');
        if (v > 0) {
          final pw = v * i / 1000.0;
          setState(() {
            _rawValues['battery_power']    = pw;
            _currentValues['battery_power'] = pw.toStringAsFixed(1);
          });
        }
      }

      // 2. Hőmérséklet min = max (Ford PHEV egycsatornás hőmérő)
      if (g.command == '224800') {
        final t = _raw('battery_temp_max');
        setState(() {
          _rawValues['battery_temp_min']    = t;
          _currentValues['battery_temp_min'] = t.toStringAsFixed(0);
        });
      }

      // 3. SOC → soc_display, remaining_kwh, range_km (BECM_SOC: 224845)
      if (g.command == '224845') {
        final soc = _raw('soc_bms');
        if (soc > 0) {
          // soc_display = soc_bms (Ford PHEV-nél nincs külön kijelző SOC PID)
          setState(() {
            _rawValues['soc_display']        = soc;
            _currentValues['soc_display']    = soc.toStringAsFixed(1);
          });
          final nomCap  = _p.batteryCapacityKwh > 0 ? _p.batteryCapacityKwh : 14.4;
          final soh     = _raw('soh');
          final cap     = soh > 50 ? nomCap * soh / 100.0 : nomCap;
          final rem     = soc * cap / 100.0;
          _maybeRefreshLearnedWh();
          final whPerKm  = _computeRangeWhPerKm();
          final rangeKm  = rem  * 1000.0 / whPerKm;
          final maxRange = cap  * 1000.0 / whPerKm;
          setState(() {
            _rawValues['remaining_kwh']       = rem;
            _currentValues['remaining_kwh']   = rem.toStringAsFixed(1);
            _rawValues['range_km']            = rangeKm;
            _rawValues['range_km_max']        = maxRange;
            _currentValues['range_km']        = rangeKm.toStringAsFixed(0);
            _currentValues['range_km_max']    = maxRange.toStringAsFixed(0);
            _rangeDebug = {
              'SOC (BMS)':               '${soc.toStringAsFixed(2)} %',
              'SOH':                     soh > 0 ? '${soh.toStringAsFixed(1)} %' : _l10n.dbgUnknown,
              _l10n.dbgNominalCapacity:  '${nomCap.toStringAsFixed(1)} kWh',
              _l10n.dbgActualCapacity:   '${cap.toStringAsFixed(2)} kWh',
              _l10n.remainingEnergyLabel: '${rem.toStringAsFixed(3)} kWh',
              'App history Wh/km':       _learnedWhPerKm != null
                  ? '${_learnedWhPerKm!.toStringAsFixed(0)} Wh/km (${_l10n.dbgTripsLabel(_learnedTripCount)})'
                  : _l10n.dbgNotEnoughData,
              'Session Wh/km':           _rollingWhPerKm > 0
                  ? '${_rollingWhPerKm.toStringAsFixed(0)} Wh/km'
                    ' (${_tripDistanceKm.toStringAsFixed(1)} km)'
                  : '--',
              _l10n.dbgFinalWh:          '${whPerKm.toStringAsFixed(0)} Wh/km',
              _l10n.rangeEstimateLabel:  '${rangeKm.toStringAsFixed(1)} km',
              _l10n.dbgMaxRange:         '${maxRange.toStringAsFixed(1)} km',
            };
          });
        }
      }

      // 4. Külső hőmérséklet átadása a hatótáv-becslőnek
      if (g.command == '22DD05') {
        final t = _raw('ext_temp');
        if (t != 0.0) _externalTemp = t;
      }
    }
  }

  String _fmt(double v, EvPidField f) =>
      v.abs() < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0);

  @override
  void dispose() {
    _disposed = true;
    _stopPolling();
    _endTrip();
    // Service leállítása
    _stopForegroundService();
    _conn.close().catchError(
      (e) => debugPrint('connection.close failed: $e'),
    );
    NotificationService().dismiss();                         // kapcsolat értesítő
    for (final t in ['soc', 'temp', 'cell', 'coolant', 'fuel']) {
      NotificationService().dismissAlert(t);               // küszöb riasztások
    }
    _gpsTimer?.cancel();
    _overlayHideTimer?.cancel();
    _notifDisconnectSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  /// Rendszer UI mód beállítása az aktuális nézet + tájolás alapján:
  ///  – KITT            → immersiveSticky (teljes fullscreen)
  ///  – Dashboard + landscape → immersiveSticky (max képernyőterület)
  ///  – Dashboard + portrait  → normál (státuszsor + navsor látszik)
  ///  – Lista nézet     → mindig normál
  void _updateSystemUi() {
    if (_viewMode == 'kitt') {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return;
    }
    if (_isDashboard) {
      final size =
          WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
      if (size.width > size.height) {
        // Fekvő → teljes képernyő
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        // Álló → normál nézet (nincs overflow, státuszsor látszik)
        SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual, overlays: SystemUiOverlay.values);
      }
      return;
    }
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual, overlays: SystemUiOverlay.values);
  }

  /// Orientáció váltás észlelése — WidgetsBindingObserver-en keresztül.
  @override
  void didChangeMetrics() {
    if (_isDashboard) _updateSystemUi();
  }

  void _setViewMode(String mode) {
    _overlayHideTimer?.cancel();
    setState(() {
      _viewMode = mode;
      // Dashboard belépéskor röviden megmutatjuk a vezérlőket,
      // hogy a felhasználó tudja: tap → overlay
      _dashOverlayVisible = (mode != 'list' && mode != 'kitt');
    });
    _updateSystemUi();
    if (_dashOverlayVisible) {
      _overlayHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _dashOverlayVisible = false);
      });
    }
  }

  /// Érintésre 3 mp-re megmutatja a dashboard vezérlőket.
  void _showDashOverlay() {
    _overlayHideTimer?.cancel();
    setState(() => _dashOverlayVisible = true);
    _overlayHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _dashOverlayVisible = false);
    });
  }

  void _showRangeDebugDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l10n.rangeDebugTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _rangeDebug.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, style: const TextStyle(
                      color: Color(0xFF9E9E9E), fontSize: 13)),
                  const SizedBox(width: 16),
                  Text(e.value, style: const TextStyle(
                      color: Color(0xFFF0F0F0),
                      fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.close),
          ),
        ],
      ),
    );
  }

  void _showDashboardPicker() {
    final items = _isPhev ? _phevDashes : (_isEv ? _evDashes : _iceDashes);
    final l = _l10n;
    showModalBottomSheet(
      context: context,
      // isScrollControlled: a sheet saját magasságát szabhatja meg (nincs fix 9/16 korlát)
      isScrollControlled: true,
      builder: (ctx) {
        // Max magasság: képernyő 70%-a — így fekvő módban sem folyik le a tartalom
        final maxH = MediaQuery.of(ctx).size.height * 0.70;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    l.dashboardPickerTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.list),
                        title: Text(l.listView),
                        selected: _viewMode == 'list',
                        onTap: () { _setViewMode('list'); Navigator.pop(ctx); },
                      ),
                      const Divider(height: 1),
                      ...items.map((d) => ListTile(
                        leading: Icon(d.icon),
                        title: Text(d.name),
                        selected: _viewMode == d.id,
                        onTap: () { _setViewMode(d.id); Navigator.pop(ctx); },
                      )),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.terminal),
                        title: Text(l.obdMonitorTitle),
                        subtitle: Text(l.obdMonitorSubtitle(_obdLog.length),
                            style: const TextStyle(fontSize: 11)),
                        selected: _viewMode == 'obd_monitor',
                        onTap: () { _setViewMode('obd_monitor'); Navigator.pop(ctx); },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleNotifier>(); // rebuild when language changes
    final isKitt = _viewMode == 'kitt';
    final isDark = isKitt;

    // Vissza-gomb logika:
    //   • Dashboard nézet → vissza listára (azonnal, nem konzumálja a kilépést).
    //   • Lista nézet → első nyomás snackbar; második nyomás 2 mp-en belül kilép.
    final now = DateTime.now();
    final canPopNow = _viewMode == 'list' &&
        _lastBackPress != null &&
        now.difference(_lastBackPress!).inSeconds < 2;

    return PopScope(
      canPop: canPopNow,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) return;
        if (_viewMode != 'list') {
          _setViewMode('list');
          return;
        }
        // Lista nézet, első vissza-nyomás → toast.
        _lastBackPress = DateTime.now();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.backOnceMore),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : null,
        // AppBar csak lista nézetben látható — dashboard módban elrejtjük,
        // hogy a tartalom a teljes képernyőt kapja (overflow megszűnik).
        appBar: (isKitt || _isDashboard)
            ? null
            : AppBar(
                title: Text(_p.displayName, overflow: TextOverflow.ellipsis),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.speed),
                    tooltip: _l10n.viewSwitch,
                    onPressed: _showDashboardPicker,
                  ),
                  IconButton(
                    icon: const Icon(Icons.history),
                    tooltip: _l10n.tripLog,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TripsPage()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: _l10n.settings,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsPage(drivetrain: _p.drivetrain),
                      ),
                    ),
                  ),
                ],
              ),
        // SafeArea a tetején: amikor nincs AppBar (dashboard mód), a Scaffold
        // nem tolja le magától a tartalmat a státuszsor alá — erre van a SafeArea.
        // Lista módban az AppBar már elfogyasztja a státuszsor magasságát,
        // így ott a SafeArea.top = 0 (nincs dupla hézag).
        // Immersive módban (fekvő, KITT) a státuszsor rejtett → padding.top = 0.
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildAlertBanners(),
              Expanded(
                child: _isDashboard
                    // Dashboard: Stack — az egész tartalom tappintható → overlay előjön
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          // Teljes tartalom burkolva GestureDetector-ral.
                          // HitTestBehavior.translucent: az érintés átmegy a gyerek
                          // widgetekhez is, scroll/gauge érintések nem vesznek el.
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _showDashOverlay,
                            child: _buildBody(),
                          ),
                          // ECU figyelmeztető chip dashboard módban — ha a
                          // státusz nem-aktív kapcsolatot jelez, a felhasználó
                          // tudja, hogy a kijelzett értékek elavultak lehetnek.
                          if (!_isInitializing &&
                              _statusText.contains(_l10n.ecuNotResponding))
                            Positioned(
                              top: 6, right: 6,
                              child: _ecuWarningChip(),
                            ),
                          // Lebegő vezérlősor: SafeArea a külső szinten fogyasztja
                          // a padding.top értéket, itt már 0 — a Row az usable area
                          // tetején jelenik meg.
                          if (_dashOverlayVisible)
                            Positioned(
                              top: 0, left: 0, right: 0,
                              child: _buildDashboardOverlay(),
                            ),
                        ],
                      )
                    : _buildBody(),
              ),
            ],
          ),
        ),
        floatingActionButton: isKitt
            ? FloatingActionButton.small(
                backgroundColor: Colors.black,
                foregroundColor: const Color(0xFFFF1100),
                tooltip: _l10n.exit,
                onPressed: () => _setViewMode('list'),
                child: const Icon(Icons.close),
              )
            : null,
      ),
    );
  }

  /// Félátlátszó vezérlősor — 3 mp után auto-eltűnik, tap-ra újra eljön.
  Widget _buildDashboardOverlay() {
    // Az aktuális nézet neve a középső felirathoz
    final allDashes = _isPhev ? _phevDashes : (_isEv ? _evDashes : _iceDashes);
    final def = allDashes.where((d) => d.id == _viewMode).firstOrNull;
    final title = def?.name ?? _p.displayName;

    return Container(
      color: Colors.black.withValues(alpha: 0.70),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // ← Vissza a lista nézetbe
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: _l10n.listView,
              onPressed: () {
                _overlayHideTimer?.cancel();
                setState(() => _dashOverlayVisible = false);
                _setViewMode('list');
              },
            ),
            // Hatótáv debug — driving és phev nézetben, ha van adat
            if ((_viewMode == 'driving' || _viewMode == 'phev') && _isEv && _rangeDebug.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white70),
                tooltip: _l10n.rangeDebugTitle,
                onPressed: () {
                  _overlayHideTimer?.cancel();
                  setState(() => _dashOverlayVisible = false);
                  _showRangeDebugDialog();
                },
              ),
            // Középső cím
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Nézet váltó
            IconButton(
              icon: const Icon(Icons.grid_view, color: Colors.white),
              tooltip: _l10n.viewSwitch,
              onPressed: () {
                _overlayHideTimer?.cancel();
                setState(() => _dashOverlayVisible = false);
                _showDashboardPicker();
              },
            ),
            // Menetnapló
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              tooltip: _l10n.tripLog,
              onPressed: () {
                _overlayHideTimer?.cancel();
                setState(() => _dashOverlayVisible = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TripsPage()),
                );
              },
            ),
            // Beállítások
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              tooltip: _l10n.settings,
              onPressed: () {
                _overlayHideTimer?.cancel();
                setState(() => _dashOverlayVisible = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(drivetrain: _p.drivetrain),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Apró figyelmeztető chip, amit dashboard módban mutatunk, ha az ECU
  /// nem válaszol — különben a felhasználó nem látná a státusz-szöveget.
  Widget _ecuWarningChip() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.black87, size: 14),
          const SizedBox(width: 4),
          Text(_l10n.ecuNotResponding,
              style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  /// Aktív küszöb-riasztások megjelenítése a tartalom fölött.
  /// Minden aktív riasztás egy piros sávban jelenik meg piros ⚠ ikonnal,
  /// a mért értékkel és a beállított küszöbbel.
  /// Automatikusan eltűnik, amint az érték visszatér a biztonságos zónába.
  Widget _buildAlertBanners() {
    if (_activeAlerts.isEmpty) return const SizedBox.shrink();

    final s = AppSettings();
    final banners = <Widget>[];

    for (final type in _activeAlerts) {
      String title, detail;
      IconData icon;

      final l = _l10n;
      switch (type) {
        case 'soc':
          final soc = _rawValues['soc_display'] ?? _raw('soc_bms');
          icon   = Icons.battery_alert;
          title  = l.lowSoc;
          detail = 'SOC: ${soc.toStringAsFixed(0)}%  •  '
                   '${l.thresholdLabel}: ${s.alertSocMin.toStringAsFixed(0)}%';
        case 'temp':
          final temp = _raw('battery_temp_max');
          icon   = Icons.thermostat;
          title  = l.highBatteryTemp;
          detail = '${temp.toStringAsFixed(0)} °C  •  '
                   '${l.thresholdLabel}: ${s.alertTempMax.toStringAsFixed(0)} °C';
        case 'cell':
          final spread = _raw('cell_volt_spread');
          icon   = Icons.grid_on;
          title  = l.cellImbalance;
          detail = 'Max–Min: ${spread.toStringAsFixed(0)} mV  •  '
                   '${l.thresholdLabel}: ${s.alertCellSpread.toStringAsFixed(0)} mV';
        case 'coolant':
          // ICE: OBD PID '0105'; PHEV: EV field 'coolant_temp'
          final coolant = !_isEv
              ? (_rawValues['0105'] ?? 0.0)
              : (_rawValues['coolant_temp'] ?? 0.0);
          icon   = Icons.thermostat;
          title  = l.highCoolantTemp;
          detail = '${coolant.toStringAsFixed(0)} °C  •  '
                   '${l.thresholdLabel}: ${s.alertCoolantMax.toStringAsFixed(0)} °C';
        case 'fuel':
          // ICE: OBD PID '012F'; PHEV: EV field 'fuel_level'
          final fuelLvl = !_isEv
              ? (_rawValues['012F'] ?? 0.0)
              : (_rawValues['fuel_level'] ?? 0.0);
          icon   = Icons.local_gas_station;
          title  = l.lowFuelLevel;
          detail = '${l.fuelLabel}: ${fuelLvl.toStringAsFixed(0)}%  •  '
                   '${l.thresholdLabel}: ${s.alertFuelMin.toStringAsFixed(0)}%';
        default:
          continue;
      }

      banners.add(Container(
        width: double.infinity,
        color: const Color(0xFFB71C1C),           // mélypiros
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            // Villogó ikon helyett statikus — kevésbé zavaró, de szembetűnő
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    const Icon(Icons.warning_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        )),
                  ]),
                  const SizedBox(height: 2),
                  Text(detail,
                      style: const TextStyle(
                        color: Color(0xFFFFCDD2),  // halvány piros-fehér
                        fontSize: 11,
                      )),
                ],
              ),
            ),
          ],
        ),
      ));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: banners);
  }

  /// Az összes ismert mező emberi neve az egyéni grafikon választóhoz.
  /// EV esetén statikus lista; ICE esetén a profil stdPids-ből generált.
  Map<String, String> get _chartFieldLabels {
    if (_isEv) {
      final l = _l10n;
      return {
        'soc_display':         l.socDisplayLabel,
        'soc_bms':             l.socBmsLabel,
        'remaining_kwh':       l.remainingEnergyLabel,
        'battery_voltage':     l.voltageLabel,
        'battery_current':     l.currentLabel,
        'battery_power':       l.powerLabel,
        'soh':                 l.sohLabel,
        'aux_battery_voltage': l.aux12VLabel,
        'battery_temp_max':    l.batteryMaxTempLabel,
        'battery_temp_min':    l.batteryMinTempLabel,
        'speed':               l.speedLabel,
        'ccl':                 l.maxChargePowerLabel,
        'dcl':                 l.maxDischargePowerLabel,
        'cec':                 l.chargedKwhLabel,
        'ced':                 l.dischargedKwhLabel,
        'op_time':             l.operatingHoursLabel,
        'range_km':            l.rangeEstimateLabel,
        'wh_per_km':           l.chartConsumptionLabel,
        'cell_volt_min':       l.minCellVoltLabel,
        'cell_volt_max':       l.maxCellVoltLabel,
        'cell_volt_avg':       l.avgCellVoltLabel,
        'cell_volt_spread':    l.cellSpreadLabel,
      };
    }
    return {for (final p in _p.stdPids) p.code: p.name};
  }

  /// Az összes ismert mező mértékegysége az egyéni grafikon tengelycímkéihez.
  Map<String, String> get _chartFieldUnits {
    if (_isEv) {
      return const {
        'soc_display':         '%',
        'soc_bms':             '%',
        'remaining_kwh':       'kWh',
        'battery_voltage':     'V',
        'battery_current':     'A',
        'battery_power':       'kW',
        'soh':                 '%',
        'aux_battery_voltage': 'V',
        'battery_temp_max':    '°C',
        'battery_temp_min':    '°C',
        'speed':               'km/h',
        'ccl':                 'kW',
        'dcl':                 'kW',
        'cec':                 'kWh',
        'ced':                 'kWh',
        'op_time':             'h',
        'range_km':            'km',
        'wh_per_km':           'Wh/km',
        'cell_volt_min':       'V',
        'cell_volt_max':       'V',
        'cell_volt_avg':       'V',
        'cell_volt_spread':    'mV',
      };
    }
    return {for (final p in _p.stdPids) p.code: p.unit};
  }

  Widget _buildBody() {
    switch (_viewMode) {
      case 'driving':
        return EvDrivingDashboard(
          data: _currentValues,
          externalTemp: _externalTemp,
          rangeMode: AppSettings().rangeMode,
        );
      case 'battery':
        return EvBatteryDashboard(data: _currentValues);
      case 'chart':
        // EV/PHEV: fix SOC–teljesítmény–sebesség grafikon
        // ICE: egyéni grafikon (sebesség, RPM, hőmérséklet, üzemanyag)
        if (_isEv) return EvChartView(points: List.unmodifiable(_chartPoints));
        return CustomChartsView(
          samples:     List.unmodifiable(_sampleHistory),
          fieldLabels: _chartFieldLabels,
          fieldUnits:  _chartFieldUnits,
        );
      case 'ice_driving':
        return IceDashboard(data: _currentValues);
      case 'charging':
        return ChargingMonitorView(
          data: _currentValues,
          chargedKwh: _chargedKwh,
          chargeStartTime: _chargeSessionStart,
          chargePoints: List.unmodifiable(_chargePoints),
          nominalCapacityKwh: _p.batteryCapacityKwh,
        );
      case 'phev':
        return PhevDashboard(
          data: _currentValues,
          externalTemp: _externalTemp,
          rangeMode: AppSettings().rangeMode,
        );
      case 'phev_ice':
        return PhevIceView(data: _currentValues);
      case 'custom_charts':
        return CustomChartsView(
          samples:     List.unmodifiable(_sampleHistory),
          fieldLabels: _chartFieldLabels,
          fieldUnits:  _chartFieldUnits,
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
      case 'obd_monitor':
        return ObdMonitorView(
          entries: List.unmodifiable(_obdLog),
          onClear: () => setState(() => _obdLog.clear()),
        );
      default:
        return _buildList();
    }
  }

  Widget _buildList() {
    final isDisconnected =
        !_isInitializing && !_conn.isConnected;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(children: [
          Icon(_isInitializing
                  ? Icons.settings_ethernet
                  : (isDisconnected ? Icons.signal_wifi_off : Icons.sensors),
              size: 16,
              color: _isInitializing
                  ? const Color(0xFFFFA726)
                  : (isDisconnected
                      ? const Color(0xFFEF5350)
                      : const Color(0xFF66BB6A))),
          const SizedBox(width: 6),
          Expanded(
            child: Text(_statusText,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodySmall?.color)),
          ),
          // Kapcsolat-kiesés esetén újrakapcsolódás gomb.
          if (isDisconnected) ...[
            const SizedBox(width: 6),
            if (_isReconnecting)
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton.icon(
                onPressed: widget.reconnectFn != null
                    ? _attemptReconnect
                    : () {
                        _stopPolling();
                        _endTrip();
                        _conn.close();
                        if (mounted) Navigator.pop(context);
                      },
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(_l10n.reconnect,
                    style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ]),
      ),
      if (!_isInitializing)
        _isEv ? _buildStatusStrip() : _buildIceStatusStrip(),
      Expanded(child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: _isEv ? _buildEvGroups() : _buildIceList(),
      )),
      Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: () {
            _stopPolling();
            _endTrip();
            _conn.close();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.bluetooth_disabled),
          label: Text(_l10n.disconnect),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        ),
      ),
    ]);
  }

  Widget _buildStatusStrip() {
    final soc    = _rawValues['soc_display'] ?? _raw('soc_bms');
    final remKwh = _raw('remaining_kwh');
    final temp   = _raw('battery_temp_max');
    final aux    = _raw('aux_battery_voltage');

    Color tempColor = const Color(0xFF9E9E9E);
    if (temp >= 40) tempColor = const Color(0xFFEF5350);
    else if (temp >= 30) tempColor = const Color(0xFFFFA726);

    Color auxColor = const Color(0xFFFDD835);
    if (aux > 0 && aux < 11.5) auxColor = const Color(0xFFEF5350);
    else if (aux > 0 && aux < 12.0) auxColor = const Color(0xFFFFA726);

    Color socColor = const Color(0xFF66BB6A);
    if (soc < 10) socColor = const Color(0xFFEF5350);
    else if (soc < 20) socColor = const Color(0xFFFFA726);

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stripItem(Icons.battery_full, soc > 0
              ? '${soc.toStringAsFixed(0)}%'
              : '--', socColor),
          _stripItem(Icons.electric_bolt, remKwh > 0
              ? '${remKwh.toStringAsFixed(1)} kWh'
              : '--', const Color(0xFF42A5F5)),
          _stripItem(Icons.thermostat, temp > 0
              ? '${temp.toStringAsFixed(0)}°C'
              : '--', tempColor),
          _stripItem(Icons.car_repair, aux > 0
              ? '${aux.toStringAsFixed(1)}V'
              : '--', auxColor),
        ],
      ),
    );
  }

  /// ICE státusz sáv — sebesség, RPM, hűtővíz, üzemanyag.
  Widget _buildIceStatusStrip() {
    final speed   = _rawValues['010D'] ?? 0.0;
    final rpm     = _rawValues['010C'] ?? 0.0;
    final coolant = _rawValues['0105'] ?? 0.0;
    final fuel    = _rawValues['012F'] ?? 0.0;

    Color coolantColor = const Color(0xFF9E9E9E);
    if (coolant >= 105)              coolantColor = const Color(0xFFEF5350);
    else if (coolant >= 95)          coolantColor = const Color(0xFFFFA726);
    else if (coolant > 0 && coolant < 60) coolantColor = const Color(0xFF42A5F5);

    Color fuelColor = const Color(0xFF9E9E9E);
    if (fuel > 0 && fuel <= 10)  fuelColor = const Color(0xFFEF5350);
    else if (fuel > 0 && fuel <= 20) fuelColor = const Color(0xFFFFA726);
    else if (fuel > 20)          fuelColor = const Color(0xFF66BB6A);

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stripItem(Icons.speed,
              speed > 0 ? '${speed.toStringAsFixed(0)} km/h' : '--',
              const Color(0xFF42A5F5)),
          _stripItem(Icons.rotate_right,
              rpm > 0 ? '${rpm.toStringAsFixed(0)} rpm' : '--',
              const Color(0xFF9E9E9E)),
          _stripItem(Icons.thermostat,
              coolant > 0 ? '${coolant.toStringAsFixed(0)}°C' : '--',
              coolantColor),
          _stripItem(Icons.local_gas_station,
              fuel > 0 ? '${fuel.toStringAsFixed(0)}%' : '--',
              fuelColor),
        ],
      ),
    );
  }

  Widget _stripItem(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }

  List<Widget> _buildEvGroups() {
    final l = _l10n;
    return [
      _group(Icons.battery_charging_full, l.dashBattery, Colors.green, true, [
        _tile('soc_display', l.socDisplayLabel, '%'),
        _tile('soc_bms', l.socBmsLabel, '%'),
        _tile('remaining_kwh', l.remainingEnergyLabel, 'kWh'),
        _tile('battery_voltage', l.voltageLabel, 'V'),
        _tile('battery_current', l.currentLabel, 'A'),
        _tile('battery_power', l.powerLabel, 'kW'),
        _tile('soh', l.sohLabel, '%'),
        _tile('aux_battery_voltage', l.aux12VLabel, 'V'),
      ]),
      _group(Icons.thermostat, l.temperature, Colors.orange, false, [
        _tile('battery_temp_max', l.batteryMaxTempLabel, '°C'),
        _tile('battery_temp_min', l.batteryMinTempLabel, '°C'),
      ]),
      _group(Icons.speed, l.drivingParamsLabel, Colors.blue, true, [
        _tile('speed', l.speedLabel, 'km/h'),
        _tile('ccl', l.maxChargePowerLabel, 'kW'),
        _tile('dcl', l.maxDischargePowerLabel, 'kW'),
      ]),
      _group(Icons.bar_chart, l.statisticsLabel, Colors.purple, false, [
        _tile('cec', l.chargedKwhLabel, 'kWh'),
        _tile('ced', l.dischargedKwhLabel, 'kWh'),
        _tile('op_time', l.operatingHoursLabel, 'h'),
      ]),
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

}