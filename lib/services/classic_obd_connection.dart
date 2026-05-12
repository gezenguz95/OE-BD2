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
        final p = _pending;
        _pending = null;
        if (p != null && !p.isCompleted) {
          p.completeError(StateError('Bluetooth connection closed'));
        }
      },
      onError: (e) {
        final p = _pending;
        _pending = null;
        if (p != null && !p.isCompleted) {
          p.completeError(e);
        }
      },
    );
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

    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) {
      p.complete(response);
    }
  }

  @override
  Future<String> sendAndWait(
      String command, {
        Duration timeout = const Duration(seconds: 5),
      }) async {
    if (_closed) throw StateError('Connection closed');

    final prev = _pending;
    if (prev != null && !prev.isCompleted) {
      prev.future.ignore();
      prev.completeError(StateError('Overridden by new command'));
    }

    _buf.clear();

    final pending = Completer<String>();
    _pending = pending;
    final future = pending.future;

    try {
      _conn.output.add(Uint8List.fromList(command.codeUnits));
      await _conn.output.allSent;
    } catch (e) {
      if (identical(_pending, pending)) {
        _pending = null;
      }
      if (!pending.isCompleted) {
        pending.completeError(e);
      }
      rethrow;
    }

    _tryComplete();

    return future.timeout(timeout, onTimeout: () {
      if (identical(_pending, pending)) {
        _pending = null;
        _buf.clear();
      }
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
    await _sub?.cancel();
    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) {
      p.completeError(StateError('Connection closed'));
    }
    try { await _conn.close(); } catch (_) {}
  }
}
