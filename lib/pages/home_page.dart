// Főoldal — Bluetooth eszközök keresése, járműprofil-választás és OBD kapcsolódás.
// Kezeli a Classic BT és BLE módokat, az auto-connectet és a megszakíthatóságot.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as bt;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../data/vehicle_profiles_data.dart';
import '../models/vehicle_profile.dart';
import '../services/obd_connection.dart';
import '../services/classic_obd_connection.dart';
import '../services/ble_obd_connection.dart';
import '../services/demo_obd_connection.dart';
import '../services/app_settings.dart';
import '../services/locale_notifier.dart';
import '../services/notification_service.dart';
import '../utils/file_logger.dart';
import 'obd_data_page.dart';
import 'trips_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _connectionType = 'classic'; // 'classic' | 'ble'

  String _selectedMake = 'Hyundai';
  late VehicleProfile _selectedProfile = allVehicleProfiles.firstWhere(
        (p) => p.id == 'hyundai_ioniq_ev_28',
    orElse: () => allVehicleProfiles.first,
  );

  bool _isScanning = false;
  bool _isConnecting = false;

  final List<bt.BluetoothDiscoveryResult> _classicDevices = [];
  List<ble.ScanResult> _bleDevices = [];
  StreamSubscription<bt.BluetoothDiscoveryResult>? _classicScanSub;
  StreamSubscription<List<ble.ScanResult>>? _bleScanSub;
  StreamSubscription<bool>? _bleScanStateSub;

  /// Bluetooth adapter állapotának figyelése — a BLE bekapcsolt-e épp.
  /// Ha hamis, a UI-on tartós figyelmeztető sávot mutatunk és a Search
  /// gombot letiltjuk, hogy ne nyomdosson hiába a felhasználó.
  bool _bleAdapterOn = true;
  StreamSubscription<ble.BluetoothAdapterState>? _bleAdapterSub;

  static const _autoChannel =
      MethodChannel('com.example.obdreader2/auto_connect');

  /// Re-entrancy guard: megakadályozza a párhuzamos auto-connect próbálkozásokat.
  bool _autoConnectInFlight = false;

  /// Ha igaz, a folyamatban lévő csatlakozási kísérlet megszakítandó.
  bool _connectCancelled = false;
  /// A .complete() hívása a Future.any() cancel-ágát aktiválja, azonnal kilép a retry-loopból.
  Completer<void>? _cancelCompleter;

  @override
  void initState() {
    super.initState();
    // BroadcastReceiver intent ellenőrzése és auto-connect indítása az első frame után.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoChannel.setMethodCallHandler((call) async {
        if (call.method == 'autoConnectTriggered' && mounted) {
          // Az app háttérben futott, és kocsi indításkor jött az intent.
          _tryAutoConnect();
        }
      });
      _checkAutoConnectIntent();
    });

    // BLE adapter állapot figyelése (ki/be kapcsolás runtime-ban).
    _bleAdapterSub = ble.FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;
      final on = state == ble.BluetoothAdapterState.on;
      if (on != _bleAdapterOn) setState(() => _bleAdapterOn = on);
    }, onError: (Object e) {
      FileLogger().log('Home', 'adapterState error: $e');
    });
  }

  @override
  void dispose() {
    _autoChannel.setMethodCallHandler(null);
    _classicScanSub?.cancel();
    _bleScanSub?.cancel();
    _bleScanStateSub?.cancel();
    _bleAdapterSub?.cancel();
    try {
      ble.FlutterBluePlus.stopScan();
    } catch (e) {
      FileLogger().log('Home', 'stopScan in dispose: $e');
    }
    super.dispose();
  }

  /// Lekérdezi az Android platformtól, hogy a BroadcastReceiver indította-e az appot.
  Future<void> _checkAutoConnectIntent() async {
    bool triggered = false;
    try {
      final result =
          await _autoChannel.invokeMapMethod<String, dynamic>('checkAutoConnectIntent');
      triggered = result?['triggered'] as bool? ?? false;
    } catch (e) {
      // Platform channel hiba (pl. túl korai hívás) — nem fatális, csak naplózzuk.
      debugPrint('checkAutoConnectIntent failed: $e');
    }

    if (triggered) {
      await _tryAutoConnect();
      return;
    }
    // Normál app megnyitáskor: ha az auto-connect be van kapcsolva, azonnal próbál.
    final s = AppSettings();
    if (s.autoConnectEnabled && s.lastDeviceAddress.isNotEmpty) {
      await _tryAutoConnect();
    }
  }

  /// Auto-csatlakozás az utolsó mentett eszközhöz.
  /// Re-entrancy védett: párhuzamos hívás esetén a második azonnal visszatér.
  Future<void> _tryAutoConnect() async {
    if (_autoConnectInFlight) return;
    _autoConnectInFlight = true;
    try {
      final s = AppSettings();
      final address = s.lastDeviceAddress;
      final connType = s.lastConnectionType;
      if (address.isEmpty) return;
      if (!await _requestPermissions()) return;
      if (!mounted) return;

      // Service leállítás + várakozás: ELM327 csak egy RFCOMM socketet kezel
      try {
        await _autoChannel.invokeMethod<void>('stopForegroundService');
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<LocaleNotifier>().strings.autoConnecting(s.lastDeviceName)),
        duration: const Duration(seconds: 4),
      ));

      if (connType == 'classic') {
        await _connectClassicByAddress(address);
      } else {
        final device = ble.BluetoothDevice.fromId(address);
        await _connectBle(device);
      }
    } finally {
      _autoConnectInFlight = false;
    }
  }

  /// A folyamatban lévő csatlakozási kísérlet leállítása, a retry-loop azonnal kilép.
  void _cancelConnect() {
    _connectCancelled = true;
    if (!(_cancelCompleter?.isCompleted ?? true)) {
      _cancelCompleter!.complete();
    }
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  /// Classic BT csatlakozás MAC-cím alapján, előzetes scan nélkül (auto-connecthez).
  Future<void> _connectClassicByAddress(String address) async {
    if (_isConnecting) return;
    _connectCancelled = false;
    _cancelCompleter  = Completer<void>();
    if (mounted) setState(() => _isConnecting = true);

    bt.BluetoothConnection? rawConn;
    for (int i = 1; i <= 3; i++) {
      if (_connectCancelled) break;
      try {
        rawConn = await Future.any([
          bt.BluetoothConnection.toAddress(address)
              .timeout(const Duration(seconds: 12)),
          _cancelCompleter!.future
              .then<bt.BluetoothConnection>((_) => throw const _ConnectCancelled()),
        ]);
        if (rawConn?.isConnected == true) break;
        rawConn = null;
      } on _ConnectCancelled {
        rawConn = null;
        break;
      } catch (e) {
        rawConn = null;
        FileLogger().log('AutoConnect', 'attempt $i failed: $e');
        if (!_connectCancelled && i < 3) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
    }

    if (!_connectCancelled && rawConn != null && rawConn.isConnected) {
      if (mounted) {
        _openObdPage(
          ClassicObdConnection(rawConn),
          reconnectFn: () async {
            final newRaw = await bt.BluetoothConnection.toAddress(address)
                .timeout(const Duration(seconds: 12));
            return ClassicObdConnection(newRaw);
          },
        );
      }
    } else if (!_connectCancelled) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.read<LocaleNotifier>().strings.autoConnectFailed),
          duration: const Duration(seconds: 5),
        ));
      }
    }

    if (mounted) setState(() => _isConnecting = false);
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
    final ok = statuses.values.every(
        (s) => s.isGranted || s == PermissionStatus.limited);
    if (ok || !mounted) return ok;

    final l10n = context.read<LocaleNotifier>().strings;
    final permanentlyDenied = statuses.values
        .any((s) => s == PermissionStatus.permanentlyDenied);

    if (permanentlyDenied) {
      // A felhasználó "Soha ne kérdezd újra" opciót választott — kézi
      // beavatkozás kell a rendszerbeállításokban.
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.permissionsPermanentlyDenied),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: l10n.openAppSettings,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.permissionsRequired)),
      );
    }
    return false;
  }

  Future<void> _startScan() async {
    if (!await _requestPermissions()) return;
    if (!mounted) return;

    final db = Provider.of<AppDatabase>(context, listen: false);
    await db.clearSessionValues();

    if (_connectionType == 'classic') {
      await _startClassicScan();
    } else {
      await _startBleScan();
    }
  }

  Future<void> _startClassicScan() async {
    final btState = await bt.FlutterBluetoothSerial.instance.state;
    if (btState == bt.BluetoothState.STATE_OFF) {
      final enabled =
      await bt.FlutterBluetoothSerial.instance.requestEnable();
      if (enabled != true) return;
    }

    setState(() {
      _isScanning = true;
      _classicDevices.clear();
    });

    _classicScanSub?.cancel();
    _classicScanSub = bt.FlutterBluetoothSerial.instance.startDiscovery().listen(
          (result) {
        if (!mounted) return;
        setState(() {
          final idx = _classicDevices.indexWhere(
                  (r) => r.device.address == result.device.address);
          if (idx >= 0) {
            _classicDevices[idx] = result;
          } else {
            _classicDevices.add(result);
          }
        });
      },
      onDone: () {
        if (mounted) setState(() => _isScanning = false);
      },
    );
  }

  Future<void> _startBleScan() async {
    final adapterState = await ble.FlutterBluePlus.adapterState.first;
    if (adapterState != ble.BluetoothAdapterState.on) {
      // flutter_blue_plus 2.x-ben a turnOn() eltávolításra került (Android 12+ API-korlát),
      // ezért a felhasználónak kézzel kell bekapcsolnia a Bluetooth-t.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.read<LocaleNotifier>().strings.enableBluetooth),
          duration: const Duration(seconds: 4),
        ));
      }
      return;
    }

    setState(() {
      _isScanning = true;
      _bleDevices = [];
    });

    _bleScanSub?.cancel();
    _bleScanSub = ble.FlutterBluePlus.scanResults.listen((results) {
      if (mounted) setState(() => _bleDevices = results);
    });

    // Az isScanning stream-re a scan indítása ELŐTT iratkozunk fel — különben
    // azonnali leállás esetén lemaradhatunk a 'scanning = false' eseményről.
    _bleScanStateSub?.cancel();
    _bleScanStateSub = ble.FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && mounted) {
        setState(() => _isScanning = false);
        _bleScanStateSub?.cancel();
      }
    });

    try {
      await ble.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      _bleScanStateSub?.cancel();
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<LocaleNotifier>().strings.bleScanError(e.toString()))),
        );
      }
      return;
    }
  }

  void _stopScan() {
    if (_connectionType == 'classic') {
      _classicScanSub?.cancel();
      try { bt.FlutterBluetoothSerial.instance.cancelDiscovery(); } catch (_) {}
    } else {
      ble.FlutterBluePlus.stopScan();
      _bleScanSub?.cancel();
      _bleScanStateSub?.cancel();
    }
    setState(() => _isScanning = false);
  }

  Future<void> _connectClassic(bt.BluetoothDevice device) async {
    if (_isConnecting) return;
    _connectCancelled = false;
    _cancelCompleter  = Completer<void>();
    setState(() => _isConnecting = true);

    try {
      await bt.FlutterBluetoothSerial.instance.cancelDiscovery();
    } catch (_) {}
    setState(() => _isScanning = false);

    // Service leállítás + várakozás: ELM327 csak egy RFCOMM socketet kezel
    try {
      await _autoChannel.invokeMethod<void>('stopForegroundService');
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 1500));

    const maxRetries = 3;
    bt.BluetoothConnection? rawConn;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      if (_connectCancelled) break;
      try {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.read<LocaleNotifier>().strings.connectingAttempt(attempt, maxRetries)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        rawConn = await Future.any([
          bt.BluetoothConnection.toAddress(device.address)
              .timeout(const Duration(seconds: 10)),
          _cancelCompleter!.future
              .then<bt.BluetoothConnection>((_) => throw const _ConnectCancelled()),
        ]);
        if (rawConn?.isConnected == true) break;
        rawConn = null;
      } on _ConnectCancelled {
        rawConn = null;
        break;
      } catch (e) {
        rawConn = null;
        FileLogger().error('home_page', 'Classic connect attempt $attempt failed', e);
        if (!_connectCancelled && attempt < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
    }

    if (!_connectCancelled && rawConn != null && rawConn.isConnected) {
      final savedAddress = device.address;
      await AppSettings().saveLastDevice(
        address: savedAddress,
        name: device.name ?? savedAddress,
        connType: 'classic',
        profileId: _selectedProfile.id,
      );
      await NotificationService().requestPermission();
      if (mounted) {
        _openObdPage(
          ClassicObdConnection(rawConn),
          reconnectFn: () async {
            final newRaw = await bt.BluetoothConnection.toAddress(savedAddress)
                .timeout(const Duration(seconds: 12));
            return ClassicObdConnection(newRaw);
          },
        );
      }
    } else if (!_connectCancelled) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<LocaleNotifier>().strings.classicConnectFailed),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    if (mounted) setState(() => _isConnecting = false);
  }

  Future<void> _connectBle(ble.BluetoothDevice device) async {
    if (_isConnecting) return;
    _connectCancelled = false;
    _cancelCompleter  = Completer<void>();
    setState(() => _isConnecting = true);

    try {
      await ble.FlutterBluePlus.stopScan();
      _bleScanSub?.cancel();
      _bleScanStateSub?.cancel();
    } catch (_) {}
    setState(() => _isScanning = false);

    await Future.delayed(const Duration(milliseconds: 400));

    const maxRetries = 3;
    BleObdConnection? obdConn;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      if (_connectCancelled) break;
      try {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.read<LocaleNotifier>().strings.bleConnectingAttempt(attempt, maxRetries)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        obdConn = await Future.any([
          BleObdConnection.connect(device),
          _cancelCompleter!.future
              .then<BleObdConnection>((_) => throw const _ConnectCancelled()),
        ]);
        break;
      } on _ConnectCancelled {
        obdConn = null;
        try { await device.disconnect(); } catch (_) {}
        break;
      } catch (e) {
        obdConn = null;
        FileLogger().error('home_page', 'BLE connect attempt $attempt failed', e);
        try { await device.disconnect(); } catch (_) {}
        if (!_connectCancelled && attempt < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
    }

    if (!_connectCancelled && obdConn != null) {
      await AppSettings().saveLastDevice(
        address: device.remoteId.str,
        name: device.platformName.isNotEmpty ? device.platformName : device.remoteId.str,
        connType: 'ble',
        profileId: _selectedProfile.id,
      );
      await NotificationService().requestPermission();
      if (mounted) {
        _openObdPage(
          obdConn,
          reconnectFn: () => BleObdConnection.connect(device),
        );
      }
    } else if (!_connectCancelled) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<LocaleNotifier>().strings.bleConnectFailed),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    if (mounted) setState(() => _isConnecting = false);
  }

  void _openObdPage(
    ObdConnection obdConn, {
    Future<ObdConnection> Function()? reconnectFn,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ObdDataPage(
          connection: obdConn,
          profile: _selectedProfile,
          reconnectFn: reconnectFn,
        ),
      ),
    );
  }

  /// Bemutató mód: valódi adapter nélkül nyitja meg az ObdDataPage-et.
  /// Az összes nézet, gomb és navigáció böngészhető — adatok nélkül.
  void _openDemoMode() {
    _cancelConnect();
    _autoChannel.invokeMethod<void>('stopForegroundService').catchError((_) {});
    // Demo módban nincs reconnect — az adapter mindig "online".
    _openObdPage(DemoObdConnection());
  }

  void _onMakeChanged(String make) {
    if (_selectedMake == make) return;
    final models = profilesForMake(make);
    setState(() {
      _selectedMake = make;
      if (!models.any((p) => p.id == _selectedProfile.id)) {
        _selectedProfile = models.isNotEmpty ? models.first : allVehicleProfiles.last;
      }
    });
  }

  Future<void> _showModelSelector() async {
    final models = profilesForMake(_selectedMake);
    final result = await showModalBottomSheet<VehicleProfile>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollCtrl) {
            return SafeArea(
              child: Column(
                children: [
                  // Húzható fogó vizuális jelzője
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car, size: 22),
                        const SizedBox(width: 8),
                        Builder(builder: (ctx) {
                          final l10n = ctx.read<LocaleNotifier>().strings;
                          return Text(
                            l10n.makeModelsLabel(_selectedMake),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          );
                        }),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: models.length,
                      itemBuilder: (_, i) {
                        final p = models[i];
                        final isSelected = p.id == _selectedProfile.id;
                        return ListTile(
                          leading: Icon(
                            _iconForDrivetrain(p.drivetrain),
                            color: _colorForDrivetrain(p.drivetrain),
                          ),
                          title: Text(
                            '${p.model} ${p.variant}',
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            _drivetrainLabel(p.drivetrain) +
                                (p.yearRange != null ? ' • ${p.yearRange}' : '') +
                                (p.evPlatform.isNotEmpty
                                    ? ' • ${p.evPlatform.toUpperCase()}'
                                    : ''),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                              color: Colors.green, size: 22)
                              : null,
                          selected: isSelected,
                          onTap: () => Navigator.pop(ctx, p),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _selectedProfile = result);
    }
  }

  IconData _iconForDrivetrain(DrivetrainType dt) {
    switch (dt) {
      case DrivetrainType.ev: return Icons.electric_car;
      case DrivetrainType.phev: return Icons.electric_car;
      case DrivetrainType.hybrid: return Icons.electric_car;
      case DrivetrainType.ice: return Icons.directions_car;
    }
  }

  Color _colorForDrivetrain(DrivetrainType dt) {
    switch (dt) {
      case DrivetrainType.ev: return Colors.green;
      case DrivetrainType.phev: return Colors.teal;
      case DrivetrainType.hybrid: return Colors.lightGreen;
      case DrivetrainType.ice: return Colors.blue;
    }
  }

  String _drivetrainLabel(DrivetrainType dt) {
    switch (dt) {
      case DrivetrainType.ev: return 'EV';
      case DrivetrainType.phev: return 'PHEV';
      case DrivetrainType.hybrid: return 'Hybrid';
      case DrivetrainType.ice: return 'ICE';
    }
  }

  String _bleName(ble.ScanResult r) {
    if (r.device.platformName.isNotEmpty) return r.device.platformName;
    if (r.advertisementData.advName.isNotEmpty) {
      return r.advertisementData.advName;
    }
    return r.device.remoteId.str;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleNotifier>().strings;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.route_outlined),
            tooltip: l10n.tripLog,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TripsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BLE kikapcsolva → tartós figyelmeztető sáv. A Search gomb is
            // disabled-be vált (lentebb a build-ben).
            if (!_bleAdapterOn && _connectionType == 'ble') ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  const Icon(Icons.bluetooth_disabled,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l10n.bluetoothOffWarning,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            Text(l10n.connectionType,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'classic',
                  label: Text('Classic BT'),
                  icon: Icon(Icons.bluetooth),
                ),
                ButtonSegment(
                  value: 'ble',
                  label: Text('BLE'),
                  icon: Icon(Icons.bluetooth_searching),
                ),
              ],
              selected: {_connectionType},
              onSelectionChanged: (v) {
                setState(() {
                  _connectionType = v.first;
                  _classicDevices.clear();
                  _bleDevices = [];
                  _isScanning = false;
                });
              },
            ),
            const SizedBox(height: 16),

            Text(l10n.brand,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: makeOrder.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final make = makeOrder[i];
                  final isSelected = _selectedMake == make;
                  return ChoiceChip(
                    label: Text(make),
                    selected: isSelected,
                    onSelected: (_) => _onMakeChanged(make),
                    selectedColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            Text(l10n.model,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: Icon(
                  _iconForDrivetrain(_selectedProfile.drivetrain),
                  color: _colorForDrivetrain(_selectedProfile.drivetrain),
                ),
                title: Text(
                  '${_selectedProfile.model} ${_selectedProfile.variant}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Builder(builder: (ctx) {
                  final l10n = ctx.read<LocaleNotifier>().strings;
                  final proto = _selectedProfile.obdProtocol == 0
                      ? 'auto'
                      : _selectedProfile.obdProtocol.toString();
                  final yearPart = _selectedProfile.yearRange != null
                      ? ' • ${_selectedProfile.yearRange}'
                      : '';
                  return Text(
                    '${_drivetrainLabel(_selectedProfile.drivetrain)}$yearPart • ${l10n.protocolLabel} $proto',
                  );
                }),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: _showModelSelector,
              ),
            ),
            const SizedBox(height: 20),

            // BLE módban a Search gomb is letiltódik, ha a BT kikapcsolt —
            // a banner már jelzi a problémát.
            Builder(builder: (ctx) {
              final disabled = _isConnecting ||
                  (!_bleAdapterOn && _connectionType == 'ble' && !_isScanning);
              return ElevatedButton.icon(
                onPressed: disabled
                    ? null
                    : (_isScanning ? _stopScan : _startScan),
                icon: Icon(_isScanning ? Icons.stop : Icons.search),
                label: Text(_isScanning
                    ? l10n.stopSearch
                    : l10n.searchDevices),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScanning
                      ? Theme.of(ctx).colorScheme.error
                      : Theme.of(ctx).colorScheme.primary,
                  foregroundColor:
                      Theme.of(ctx).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            }),
            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: _isConnecting ? null : _openDemoMode,
              icon: const Icon(Icons.preview_outlined, size: 18),
              label: Text(l10n.demoMode),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

            if (_isConnecting)
              Center(
                child: Column(children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(l10n.connectingInProgress),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _cancelConnect,
                    icon: const Icon(Icons.stop_circle_outlined,
                        color: Colors.red),
                    label: Text(l10n.stopConnection,
                        style: const TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                  ),
                ]),
              )
            else if (_isScanning && _deviceCount == 0)
              Center(
                child: Column(children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(l10n.searching),
                ]),
              )
            else if (_deviceCount == 0)
                Center(child: Text(l10n.noDevicesFound))
              else
                Expanded(child: _buildDeviceList()),
          ],
        ),
      ),
    );
  }

  int get _deviceCount => _connectionType == 'classic'
      ? _classicDevices.length
      : _bleDevices.length;

  Widget _buildDeviceList() {
    if (_connectionType == 'classic') {
      return ListView.builder(
        itemCount: _classicDevices.length,
        itemBuilder: (_, i) {
          final r = _classicDevices[i];
          return _DeviceTile(
            name: r.device.name ?? context.read<LocaleNotifier>().strings.unknownDevice,
            address: r.device.address,
            onTap: () => _connectClassic(r.device),
          );
        },
      );
    } else {
      return ListView.builder(
        itemCount: _bleDevices.length,
        itemBuilder: (_, i) {
          final r = _bleDevices[i];
          return _DeviceTile(
            name: _bleName(r),
            address: r.device.remoteId.str,
            rssi: r.rssi,
            onTap: () => _connectBle(r.device),
          );
        },
      );
    }
  }
}

/// Belső kivétel a csatlakozás felhasználó általi megszakításának jelzésére.
/// Csak a retry-loopokon belül elkapott, nem kerül ki a home_page-ből.
class _ConnectCancelled implements Exception {
  const _ConnectCancelled();
}

class _DeviceTile extends StatelessWidget {
  final String name;
  final String address;
  final int? rssi;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.name,
    required this.address,
    required this.onTap,
    this.rssi,
  });

  // RSSI értékből 1–4 sávos jelerősség (4 = erős jel, 1 = gyenge).
  int _signalBars(int rssi) {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  Widget _signalIcon(int rssiVal) {
    final bars = _signalBars(rssiVal);
    final color = bars >= 3
        ? const Color(0xFF66BB6A)
        : bars == 2
            ? const Color(0xFFFFA726)
            : const Color(0xFFEF5350);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final active = i < bars;
        return Container(
          width: 5,
          height: 5.0 + i * 3.5,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: active ? color : const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.bluetooth, color: Color(0xFF42A5F5)),
        title: Text(name),
        subtitle: Text(address,
            style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
        trailing: rssi != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _signalIcon(rssi!),
                  const SizedBox(height: 2),
                  Text('$rssi dBm',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF888888))),
                ],
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
