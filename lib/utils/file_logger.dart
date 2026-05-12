import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileLogger {
  static final FileLogger _instance = FileLogger._internal();
  File? _logFile;
  Future<void>? _initFuture;

  Future<void> _writeChain = Future.value();

  factory FileLogger() {
    return _instance;
  }

  FileLogger._internal();

  Future<void> _init() {
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    final directory = await getApplicationDocumentsDirectory();
    _logFile = File('${directory.path}/obd_debug_log.txt');
  }

  static const _maxLogSize = 5 * 1024 * 1024; // 5 MB

  Future<T> _enqueue<T>(Future<T> Function() op) {
    final completer = Completer<T>();
    _writeChain = _writeChain.then((_) async {
      try {
        completer.complete(await op());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> log(String tag, String message) async {
    await _init();
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] [$tag] $message\n';

    debugPrint('$tag: $message');

    return _enqueue(() async {
      try {
        final f = _logFile;
        if (f == null) return;
        if (await f.exists() && (await f.length()) > _maxLogSize) {
          final content = await f.readAsString();
          await f.writeAsString(content.substring(content.length ~/ 2));
        }
        await f.writeAsString(logLine, mode: FileMode.append);
      } catch (e) {
        debugPrint('Failed to write log: $e');
      }
    });
  }

  Future<void> error(String tag, String message, [Object? error]) async {
    final errMsg = error != null ? ' | Error: $error' : '';
    await log('ERROR:$tag', '$message$errMsg');
  }

  Future<String> getLogContent() async {
    await _init();
    return _enqueue(() async {
      try {
        if (await _logFile?.exists() == true) {
          return await _logFile!.readAsString();
        }
      } catch (e) {
        return 'Error reading log: $e';
      }
      return 'No logs found.';
    });
  }

  Future<void> clearLog() async {
    await _init();
    return _enqueue(() async {
      try {
        if (await _logFile?.exists() == true) {
          await _logFile!.writeAsString('');
        }
      } catch (e) {
        debugPrint('Failed to clear log: $e');
      }
    });
  }
}
