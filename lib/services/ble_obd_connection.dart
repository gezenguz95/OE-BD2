// lib/services/ble_obd_connection.dart
//
// BLE ELM327 kapcsolat.
// Szekvenciális request-response: sendAndWait elküldi a parancsot
// és megvárja a teljes választ (a '>' prompt-ig).

import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'obd_connection.dart';

class BleObdConnection implements ObdConnection {
  final BluetoothDevice _device;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  final StringBuffer _buf = StringBuffer();
  StreamSubscription? _notifySub;
  StreamSubscription? _stateSub;
  Completer<String>? _pending;
  bool _connected = false;

  BleObdConnection._(this._device);

  /// Kapcsolódás és inicializálás.
  static Future<BleObdConnection> connect(BluetoothDevice device) async {
    final conn = BleObdConnection._(device);
    await conn._init();
    return conn;
  }

  Future<void> _init() async {
    await _device.connect(timeout: const Duration(seconds: 15));
    _connected = true;

    _stateSub = _device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _connected = false;
        if (_pending != null && !_pending!.isCompleted) {
          _pending!.completeError(StateError('BLE connection lost'));
        }
        _pending = null;
      }
    });

    try {
      await _device.requestMtu(512);
    } catch (_) {}

    final services = await _device.discoverServices();
    for (final svc in services) {
      for (final c in svc.characteristics) {
        if ((c.properties.notify || c.properties.indicate) &&
            _notifyChar == null) {
          _notifyChar = c;
        }
        if ((c.properties.write || c.properties.writeWithoutResponse) &&
            _writeChar == null) {
          _writeChar = c;
        }
      }
      if (_notifyChar != null && _writeChar != null) break;
    }

    if (_notifyChar == null || _writeChar == null) {
      await _device.disconnect();
      throw Exception(
          'BLE OBD: Nem találhatók megfelelő jellemzők az eszközön.');
    }

    await _notifyChar!.setNotifyValue(true);
    _notifySub = _notifyChar!.onValueReceived.listen((bytes) {
      if (bytes.isEmpty) return;
      _buf.write(String.fromCharCodes(bytes));
      _tryComplete();
    });
  }

  void _tryComplete() {
    final s = _buf.toString();
    final idx = s.indexOf('>');
    if (idx < 0) return;

    final response = s.substring(0, idx);
    _buf.clear();
    if (idx + 1 < s.length) {
      _buf.write(s.substring(idx + 1));
    }

    if (_pending != null && !_pending!.isCompleted) {
      _pending!.complete(response);
      _pending = null;
    }
  }

  @override
  Future<String> sendAndWait(
      String command, {
        Duration timeout = const Duration(seconds: 5),
      }) async {
    if (!_connected) throw StateError('Not connected');

    if (_pending != null && !_pending!.isCompleted) {
      _pending!.completeError(StateError('Overridden by new command'));
    }

    // Korábbi (elavult) adat törlése
    _buf.clear();

    _pending = Completer<String>();
    final future = _pending!.future;

    if (_writeChar != null) {
      await _writeChar!.write(
        command.codeUnits,
        withoutResponse: _writeChar!.properties.writeWithoutResponse,
      );
    }

    // Válasz már a bufferben lehet
    _tryComplete();

    return future.timeout(timeout, onTimeout: () {
      _pending = null;
      _buf.clear();
      throw TimeoutException('No response for: ${command.trim()}', timeout);
    });
  }

  @override
  Future<void> sendCommand(String command) async {
    if (_writeChar == null || !_connected) return;
    await _writeChar!.write(
      command.codeUnits,
      withoutResponse: _writeChar!.properties.writeWithoutResponse,
    );
  }

  @override
  bool get isConnected => _connected;

  @override
  Future<void> close() async {
    _notifySub?.cancel();
    _stateSub?.cancel();
    if (_pending != null && !_pending!.isCompleted) {
      _pending!.completeError(StateError('Connection closed'));
    }
    _pending = null;
    try {
      await _device.disconnect();
    } catch (_) {}
    _connected = false;
  }
}