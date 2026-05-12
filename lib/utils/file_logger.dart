import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileLogger {
  static final FileLogger _instance = FileLogger._internal();
  File? _logFile;

  factory FileLogger() {
    return _instance;
  }

  FileLogger._internal();

  Future<void> _init() async {
    if (_logFile != null) return;
    final directory = await getApplicationDocumentsDirectory();
    _logFile = File('${directory.path}/obd_debug_log.txt');
  }

  Future<void> log(String tag, String message) async {
    await _init();
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] [$tag] $message\n';
    
    // Print to console for dev
    print('$tag: $message');
    
    // Append to file
    try {
      await _logFile?.writeAsString(logLine, mode: FileMode.append);
    } catch (e) {
      print('Failed to write log: $e');
    }
  }

  Future<void> error(String tag, String message, [Object? error]) async {
    final errMsg = error != null ? ' | Error: $error' : '';
    await log('ERROR:$tag', '$message$errMsg');
  }

  Future<String> getLogContent() async {
    await _init();
    try {
      if (await _logFile?.exists() == true) {
        return await _logFile!.readAsString();
      }
    } catch (e) {
      return 'Error reading log: $e';
    }
    return 'No logs found.';
  }

  Future<void> clearLog() async {
    await _init();
    try {
      if (await _logFile?.exists() == true) {
        await _logFile!.writeAsString('');
      }
    } catch (e) {
      print('Failed to clear log: $e');
    }
  }
}
