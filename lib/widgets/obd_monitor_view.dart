// OBD Monitor — az összes raw OBD kérés-válasz pár élő naplója.
// Legfrissebb bejegyzés felül, szűrhető parancs / CAN fejléc / hex tartalom szerint.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/locale_notifier.dart';

/// Egy OBD csere: küldött parancs + nyers byte válasz.
class ObdLogEntry {
  final DateTime time;
  final String canHeader; // pl. '7E0' vagy '' Mode 01 esetén
  final String command;   // pl. '22480D' vagy '010D'
  final String rawHex;    // pl. '62 48 0D 00 3B 26 ...'
  final bool ok;          // false = timeout / üres válasz / NRC

  const ObdLogEntry({
    required this.time,
    required this.canHeader,
    required this.command,
    required this.rawHex,
    required this.ok,
  });
}

class ObdMonitorView extends StatefulWidget {
  final List<ObdLogEntry> entries;
  final VoidCallback onClear;

  const ObdMonitorView({
    super.key,
    required this.entries,
    required this.onClear,
  });

  @override
  State<ObdMonitorView> createState() => _ObdMonitorViewState();
}

class _ObdMonitorViewState extends State<ObdMonitorView> {
  final _filterCtrl = TextEditingController();
  String _filter = '';
  bool _onlyErrors = false;

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  List<ObdLogEntry> get _filtered {
    var list = widget.entries;
    if (_onlyErrors) list = list.where((e) => !e.ok).toList();
    if (_filter.isNotEmpty) {
      final f = _filter.toUpperCase();
      list = list.where((e) =>
          e.command.toUpperCase().contains(f) ||
          e.rawHex.toUpperCase().contains(f) ||
          e.canHeader.toUpperCase().contains(f)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final tt      = Theme.of(context).textTheme;
    final l10n    = context.read<LocaleNotifier>().strings;
    final entries = widget.entries;
    final shown   = _filtered;
    final okCount  = entries.where((e) => e.ok).length;
    final errCount = entries.length - okCount;

    return Column(
      children: [
        // ── Fejléc sáv: szűrő + gomb ─────────────────────────────────────
        Container(
          color: cs.surface,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _filterCtrl,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: l10n.obdMonFilterHint,
                        hintStyle: TextStyle(fontSize: 11, color: tt.labelSmall?.color),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) => setState(() => _filter = v.trim()),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Csak hibák
                Tooltip(
                  message: l10n.obdMonOnlyErrorsTip,
                  child: FilterChip(
                    label: Text(l10n.obdMonErr, style: const TextStyle(fontSize: 10)),
                    selected: _onlyErrors,
                    onSelected: (v) => setState(() => _onlyErrors = v),
                    selectedColor: Colors.red.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                        color: _onlyErrors ? Colors.red : tt.labelSmall?.color),
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                // Másolás vágólapra
                Tooltip(
                  message: l10n.obdMonCopyTip,
                  child: IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: entries.isEmpty ? null : () {
                      final buf = StringBuffer();
                      final noResp = l10n.obdMonNoResponse;
                      for (final e in entries) {
                        buf.writeln('${_fmtTime(e.time)}  [${e.canHeader}]  ${e.command}  →  ${e.ok ? e.rawHex : noResp}');
                      }
                      Clipboard.setData(ClipboardData(text: buf.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.obdMonCopiedSnack),
                            duration: const Duration(seconds: 2)),
                      );
                    },
                  ),
                ),
                // Törlés
                Tooltip(
                  message: l10n.obdMonDeleteTip,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: entries.isEmpty ? null : widget.onClear,
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              // Statisztika
              Row(children: [
                Text(l10n.obdMonEntries(entries.length),
                    style: tt.labelSmall?.copyWith(fontSize: 10)),
                const SizedBox(width: 10),
                _badge(l10n.obdMonOk, okCount, Colors.green),
                const SizedBox(width: 6),
                _badge(l10n.obdMonErr, errCount, Colors.red),
                if (shown.length != entries.length) ...[
                  const SizedBox(width: 10),
                  Text(l10n.obdMonShown(shown.length),
                      style: TextStyle(
                          color: cs.primary, fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ],
              ]),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Napló lista (legfrissebb felül) ───────────────────────────────
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.sensors_off, size: 32,
                        color: cs.outline),
                    const SizedBox(height: 8),
                    Text(
                      entries.isEmpty ? l10n.obdMonNoTraffic : l10n.obdMonNoMatch,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tt.labelSmall?.color, fontSize: 13),
                    ),
                  ]),
                )
              : ListView.builder(
                  reverse: true, // legfrissebb felül
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  itemCount: shown.length,
                  itemBuilder: (ctx, i) =>
                      _buildRow(ctx, shown[shown.length - 1 - i]),
                ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, ObdLogEntry e) {
    final cs        = Theme.of(context).colorScheme;
    final tt        = Theme.of(context).textTheme;
    final okColor   = Colors.green[600]!;
    final errColor  = Colors.red[600]!;
    final entryClr  = e.ok ? okColor : errColor;
    final bgColor   = e.ok
        ? Colors.green.withValues(alpha: 0.06)
        : Colors.red.withValues(alpha: 0.06);

    // Nyers hex tördelése 16 byte-os sorokba (hosszú válaszok olvashatók maradnak)
    final hexLines = _wrapHex(e.rawHex);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
        border: Border(left: BorderSide(color: entryClr, width: 2.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Időbélyeg
        SizedBox(
          width: 62,
          child: Text(_fmtTime(e.time),
              style: TextStyle(
                  fontFamily: 'monospace', fontSize: 9,
                  color: tt.labelSmall?.color)),
        ),

        // CAN fejléc + parancs (fix szélességű badge)
        Container(
          width: 110,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: entryClr.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            e.canHeader.isNotEmpty ? '[${e.canHeader}] ${e.command}' : e.command,
            style: TextStyle(
                fontFamily: 'monospace', fontSize: 9.5,
                fontWeight: FontWeight.w700, color: entryClr),
          ),
        ),

        // Hex tartalom (vagy hibajelzés)
        Expanded(
          child: Text(
            e.ok ? hexLines : context.read<LocaleNotifier>().strings.obdMonNoResponse,
            style: TextStyle(
                fontFamily: 'monospace', fontSize: 9.5,
                color: e.ok ? cs.onSurface : errColor,
                height: 1.5),
          ),
        ),
      ]),
    );
  }

  Widget _badge(String label, int count, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 7, height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 3),
      Text('$label: $count',
          style: TextStyle(fontSize: 10,
              color: count > 0 ? color : Theme.of(context).textTheme.labelSmall?.color,
              fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal)),
    ]);
  }

  /// Nyers hex-et 16 byte-onként új sorba tördeli (olvashatóság).
  String _wrapHex(String hex) {
    final parts = hex.split(' ');
    if (parts.length <= 16) return hex;
    final sb = StringBuffer();
    for (int i = 0; i < parts.length; i += 16) {
      if (i > 0) sb.write('\n');
      sb.write('[${i.toString().padLeft(2, '0')}] ');
      sb.write(parts.sublist(i, (i + 16).clamp(0, parts.length)).join(' '));
    }
    return sb.toString();
  }

  String _fmtTime(DateTime t) {
    final h  = t.hour.toString().padLeft(2, '0');
    final m  = t.minute.toString().padLeft(2, '0');
    final s  = t.second.toString().padLeft(2, '0');
    final ms = (t.millisecond ~/ 10).toString().padLeft(2, '0');
    return '$h:$m:$s.$ms';
  }
}
