// lib/pages/home_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as bt;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../data/vehicle_profiles_data.dart';
import '../models/vehicle_profile.dart';
import '../services/classic_obd_connection.dart';
import '../services/ble_obd_connection.dart';
import 'obd_data_page.dart';
import 'logs_page.dart';
import 'trips_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _connectionType = 'classic'; // 'classic' | 'ble'

  // ── Járműválasztás ─────────────────────────────────────────────────────
  String _selectedMake = 'Hyundai';
  late VehicleProfile _selectedProfile = allVehicleProfiles.firstWhere(
        (p) => p.id == 'hyundai_ioniq_ev_28',
    orElse: () => allVehicleProfiles.first,
  );

  bool _isScanning = false;
  bool _isConnecting = false;

  final List<bt.BluetoothDiscoveryResult> _classicDevices = [];
  List<ble.ScanResult> _bleDevices = [];
  StreamSubscription<List<ble.ScanResult>>? _bleScanSub;
  StreamSubscription<bool>? _bleScanStateSub;

  @override
  void dispose() {
    _bleScanSub?.cancel();
    _bleScanStateSub?.cancel();
    ble.FlutterBluePlus.stopScan();
    super.dispose();
  }

  // ── Engedélyek ──────────────────────────────────────────────────────────

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
    final ok = statuses.values.every((s) => s.isGranted || s.isLimited);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Bluetooth és helymeghatározási engedélyek szükségesek.'),
        ),
      );
    }
    return ok;
  }

  // ── Keresés ─────────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    if (!await _requestPermissions()) return;

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

    bt.FlutterBluetoothSerial.instance.startDiscovery().listen(
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
      await ble.FlutterBluePlus.turnOn();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      _isScanning = true;
      _bleDevices = [];
    });

    _bleScanSub?.cancel();
    _bleScanSub = ble.FlutterBluePlus.scanResults.listen((results) {
      if (mounted) setState(() => _bleDevices = results);
    });

    try {
      ble.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('BLE scan hiba: $e')),
        );
      }
      return;
    }

    await Future.delayed(const Duration(milliseconds: 200));

    _bleScanStateSub?.cancel();
    _bleScanStateSub = ble.FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && mounted) {
        setState(() => _isScanning = false);
        _bleScanStateSub?.cancel();
      }
    });
  }

  void _stopScan() {
    if (_connectionType == 'classic') {
      try { bt.FlutterBluetoothSerial.instance.cancelDiscovery(); } catch (_) {}
    } else {
      ble.FlutterBluePlus.stopScan();
      _bleScanSub?.cancel();
      _bleScanStateSub?.cancel();
    }
    setState(() => _isScanning = false);
  }

  // ── Kapcsolódás ─────────────────────────────────────────────────────────

  Future<void> _connectClassic(bt.BluetoothDevice device) async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    try {
      await bt.FlutterBluetoothSerial.instance.cancelDiscovery();
    } catch (_) {}
    setState(() => _isScanning = false);

    await Future.delayed(const Duration(milliseconds: 600));

    const maxRetries = 3;
    bt.BluetoothConnection? rawConn;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Csatlakozás... ($attempt/$maxRetries)'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        rawConn = await bt.BluetoothConnection.toAddress(device.address)
            .timeout(const Duration(seconds: 10));
        if (rawConn.isConnected) break;
        rawConn = null;
      } catch (e) {
        rawConn = null;
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
    }

    if (rawConn != null && rawConn.isConnected) {
      final obdConn = ClassicObdConnection(rawConn);
      if (mounted) _openObdPage(obdConn);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nem sikerült csatlakozni.\n'
                  'Ellenőrizd, hogy az eszköz párosítva van-e '
                  'az Android Bluetooth beállításokban.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }

    if (mounted) setState(() => _isConnecting = false);
  }

  Future<void> _connectBle(ble.BluetoothDevice device) async {
    if (_isConnecting) return;
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
      try {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('BLE csatlakozás... ($attempt/$maxRetries)'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        obdConn = await BleObdConnection.connect(device);
        break;
      } catch (e) {
        obdConn = null;
        try { await device.disconnect(); } catch (_) {}
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }
    }

    if (obdConn != null) {
      if (mounted) _openObdPage(obdConn);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'BLE csatlakozás sikertelen.\n'
                  'Ellenőrizd, hogy az adapter BLE módot támogat-e.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }

    if (mounted) setState(() => _isConnecting = false);
  }

  void _openObdPage(dynamic obdConn) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ObdDataPage(
          connection: obdConn,
          profile: _selectedProfile,
        ),
      ),
    );
  }

  // ── Márka kiválasztás ───────────────────────────────────────────────────

  void _onMakeChanged(String make) {
    final models = profilesForMake(make);
    setState(() {
      _selectedMake = make;
      if (!models.any((p) => p.id == _selectedProfile.id)) {
        _selectedProfile = models.isNotEmpty ? models.first : allVehicleProfiles.last;
      }
    });
  }

  // ── Modell kiválasztó bottom sheet ───────────────────────────────────────

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
                  // Fogó
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
                        Text(
                          '$_selectedMake modellek',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
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

  // ── Segédfüggvények ─────────────────────────────────────────────────────

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
    if (r.advertisementData.localName.isNotEmpty) {
      return r.advertisementData.localName;
    }
    return r.device.remoteId.str;
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.route_outlined),
            tooltip: 'Menetnapló',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TripsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.description),
            tooltip: 'Napló',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Beállítások',
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
            // ── Kapcsolat típusa ──────────────────────────────────────
            const Text('Kapcsolat típusa',
                style: TextStyle(fontWeight: FontWeight.bold)),
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

            // ── Márka szűrő ──────────────────────────────────────────
            const Text('Márka',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: makeOrder.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
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

            // ── Modell kiválasztó ─────────────────────────────────────
            const Text('Modell',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
                subtitle: Text(
                  _drivetrainLabel(_selectedProfile.drivetrain) +
                      (_selectedProfile.yearRange != null
                          ? ' • ${_selectedProfile.yearRange}'
                          : '') +
                      ' • Protokoll ${_selectedProfile.obdProtocol == 0 ? "auto" : _selectedProfile.obdProtocol.toString()}',
                ),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: _showModelSelector,
              ),
            ),
            const SizedBox(height: 20),

            // ── Keresés gomb ─────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _isConnecting
                  ? null
                  : (_isScanning ? _stopScan : _startScan),
              icon: Icon(_isScanning ? Icons.stop : Icons.search),
              label: Text(_isScanning
                  ? 'Keresés leállítása'
                  : 'Eszközök keresése'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isScanning ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

            // ── Állapot / lista ──────────────────────────────────────
            if (_isConnecting)
              const Center(
                child: Column(children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Kapcsolódás...'),
                ]),
              )
            else if (_isScanning && _deviceCount == 0)
              const Center(
                child: Column(children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Keresés folyamatban...'),
                ]),
              )
            else if (_deviceCount == 0)
                const Center(child: Text('Nem találhatók eszközök.'))
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
            name: r.device.name ?? 'Ismeretlen eszköz',
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

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.bluetooth),
        title: Text(name),
        subtitle: Text(address),
        trailing: rssi != null
            ? Text('$rssi dBm',
            style: const TextStyle(fontSize: 12))
            : null,
        onTap: onTap,
      ),
    );
  }
}
