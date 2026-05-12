// Debug napló oldal — a FileLogger által írt naplófájl megjelenítése és törlése.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/file_logger.dart';
import '../services/locale_notifier.dart';

/// Az alkalmazás belső debug naplóját megjelenítő oldal.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  String? _logContent;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final content = await FileLogger().getLogContent();
    if (!mounted) return;
    setState(() => _logContent = content);
  }

  Future<void> _clearLogs() async {
    await FileLogger().clearLog();
    await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.read<LocaleNotifier>().strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.debugLog),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
            tooltip: l10n.clearLogTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              final text = _logContent ?? '';
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.logCopiedSnackbar)),
              );
            },
            tooltip: l10n.copyToClipboardTooltip,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(_logContent ?? l10n.loading),
      ),
    );
  }
}
