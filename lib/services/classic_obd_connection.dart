// lib/services/classic_obd_connection.dart
//
// Classic Bluetooth (SPP/soros) ELM327 kapcsolat.
// Szekvenciális request-response: sendAndWait elküldi a parancsot
// és megvárja a teljes választ (a '>' prompt-ig).

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import 'obd_connection.dart';

class ClassicObdConnection implements ObdConnection {
  final BluetoothConnection _conn;
  final StringBuffer _buf = StringBuffer();
  StreamSubscription<Uint8List>? _sub;
  Completer<String>? _pending;
  bool _closed = false;

  ClassicObdConnection(this._conn) {
    _sub = _conn.input?.listen(
          (bytes) {
        if (_closed) return;
        _buf.write(String.fromCharCodes(bytes));
        _tryComplete();
      },
      onDone: () {
        _closed = true;
        if (_pending != null && !_pending!.isCompleted) {
          _pending!.completeError(
              StateError('Bluetooth connection closed'));
        }
        _pending = null;
      },
      onError: (e) {
        if (_pending != null && !_pending!.isCompleted) {
          _pending!.completeError(e);
        }
        _pending = null;
      },
    );
  }

  /// Megkeresi a '>' prompt-ot a bufferben és lezárja a várakozó Completer-t.
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
    if (_closed) throw StateError('Connection closed');

    // Előző várakozás eldobása
    if (_pending != null && !_pending!.isCompleted) {
      _pending!.completeError(StateError('Overridden by new command'));
    }

    // Korábbi (elavult) adat törlése – ne zavarjon bele az új válaszba
    _buf.clear();

    _pending = Completer<String>();
    final future = _pending!.future;

    // Parancs küldése
    _conn.output.add(Uint8List.fromList(command.codeUnits));
    await _conn.output.allSent;

    // Lehet, hogy a válasz már a bufferben van (gyors adapter)
    _tryComplete();

    return future.timeout(timeout, onTimeout: () {
      _pending = null;
      _buf.clear();
      throw TimeoutException('No response for: ${command.trim()}', timeout);
    });
  }

  @override
  Future<void> sendCommand(String command) async {
    if (_closed) return;
    _conn.output.add(Uint8List.fromList(command.codeUnits));
    await _conn.output.allSent;
  }

  @override
  bool get isConnected => _conn.isConnected;

  @override
  Future<void> close() async {
    _closed = true;
    _sub?.cancel();
    if (_pending != null && !_pending!.isCompleted) {
      _pending!.completeError(StateError('Connection closed'));
    }
    _pending = null;
    try { await _conn.close(); } catch (_) {}
  }
}