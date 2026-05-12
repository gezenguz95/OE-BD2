// Egyéni grafikonok nézet — felhasználó által összeállított időfüggvény-diagramok.
//
// Működés:
//   • FAB (+ gomb) → alsó panel, ahol az összes ismert mező közül lehet választani.
//   • Minden kiválasztott mező teljes szélességű kártyán jelenik meg egy LineChart-tal.
//   • Hosszan nyomva (long press) a kártyát → fogd-és-vidd sorrendezés.
//   • Kártyán a × gomb → azonnali eltávolítás a listából.
//   • Kiválasztás sorrendje SharedPreferences-ben perzisztál ('custom_charts_fields').
//   • LineTouchData(enabled: false) → fl_chart nem fogja el a long press eseményt,
//     így az átér a ReorderableListView-hoz (default Android long-press drag).

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip_data.dart';
import '../services/locale_notifier.dart';

/// EV/ICE OBD adatok egyéni időfüggvény-grafikonja.
/// A szülő (obd_data_page) tölti fel samples-szel és mezőmetaadatokkal.
class CustomChartsView extends StatefulWidget {
  /// Az OBD polling által összegyűjtött pillanatképek (max ~600 elem ≈ 20 perc).
  final List<OBDSample> samples;

  /// Mező-azonosítók → emberi nevek (pl. 'battery_voltage' → 'Feszültség').
  final Map<String, String> fieldLabels;

  /// Mező-azonosítók → mértékegységek (pl. 'speed' → 'km/h').
  final Map<String, String> fieldUnits;

  const CustomChartsView({
    super.key,
    required this.samples,
    required this.fieldLabels,
    required this.fieldUnits,
  });

  @override
  State<CustomChartsView> createState() => _CustomChartsViewState();
}

class _CustomChartsViewState extends State<CustomChartsView> {
  static const _prefKey = 'custom_charts_fields';

  /// A jelenlegi sorrendben megjelenített mezők azonosítói.
  List<String> _selected = [];

  /// Prefs betöltés befejezéséig spinner látszik.
  bool _loaded = false;

  // Szín paletta — index mod 8 alapján rotál
  static const _palette = [
    Color(0xFF42A5F5), // kék
    Color(0xFF66BB6A), // zöld
    Color(0xFFFFA726), // narancssárga
    Color(0xFFEF5350), // piros
    Color(0xFFAB47BC), // lila
    Color(0xFF26C6DA), // cián
    Color(0xFFFFEE58), // sárga
    Color(0xFFFF7043), // mély narancs
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey) ?? '';
    final ids = saved.isEmpty
        ? <String>[]
        : saved.split(',').where((s) => s.isNotEmpty).toList();
    // Csak azokat tartjuk meg, amelyek a jelenlegi mezők között is megvannak
    final valid = ids.where((id) => widget.fieldLabels.containsKey(id)).toList();
    if (mounted) setState(() { _selected = valid; _loaded = true; });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _selected.join(','));
  }

  void _add(String id) {
    if (_selected.contains(id)) return;
    setState(() => _selected.add(id));
    _savePrefs();
  }

  void _remove(String id) {
    setState(() => _selected.remove(id));
    _savePrefs();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      // newIndex a eltávolítás előtti pozíciót tükrözi — Flutter konvenció
      if (newIndex > oldIndex) newIndex--;
      final item = _selected.removeAt(oldIndex);
      _selected.insert(newIndex, item);
    });
    _savePrefs();
  }

  Color _colorFor(int index) => _palette[index % _palette.length];

  void _showPicker() {
    final l10n = context.read<LocaleNotifier>().strings;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.90,
        builder: (_, sc) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
              child: Row(
                children: [
                  const Icon(Icons.add_chart, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.addChartTitle,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: sc,
                children: widget.fieldLabels.entries.map((e) {
                  final added = _selected.contains(e.key);
                  return ListTile(
                    dense: true,
                    title: Text(e.value),
                    subtitle: Text(
                      widget.fieldUnits[e.key] ?? '',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                    trailing: added
                        ? Icon(Icons.check_circle,
                            color: Colors.green.shade400, size: 22)
                        : const Icon(Icons.add_circle_outline, size: 22),
                    enabled: !added,
                    onTap: added
                        ? null
                        : () {
                            _add(e.key);
                            Navigator.pop(ctx);
                          },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final l10n = context.read<LocaleNotifier>().strings;

    return Stack(
      children: [
        _selected.isEmpty
            ? _buildEmptyState(l10n)
            : ReorderableListView.builder(
                padding: const EdgeInsets.only(
                    left: 8, right: 8, top: 8, bottom: 80),
                itemCount: _selected.length,
                onReorder: _reorder,
                // Android alapértelmezés: long press az egész kártyán indítja
                // a húzást. A LineTouchData(enabled: false) gondoskodik arról,
                // hogy a fl_chart ne fogja el a long press eseményt.
                buildDefaultDragHandles: true,
                itemBuilder: (ctx, i) {
                  final id = _selected[i];
                  return _ChartCard(
                    key: ValueKey(id),
                    fieldId: id,
                    label: widget.fieldLabels[id] ?? id,
                    unit: widget.fieldUnits[id] ?? '',
                    samples: widget.samples,
                    color: _colorFor(i),
                    onRemove: () => _remove(id),
                  );
                },
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Builder(builder: (ctx) {
            final tip = ctx.read<LocaleNotifier>().strings.addChartTitle;
            return FloatingActionButton(
              heroTag: 'custom_charts_fab',
              onPressed: _showPicker,
              tooltip: tip,
              child: const Icon(Icons.add_chart),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEmptyState(dynamic l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 56, color: Colors.grey[700]),
            const SizedBox(height: 18),
            Text(
              l10n.noChartSelected,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500]),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.addChartHint,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 64),
          ],
        ),
      ),
    );
  }
}

/// Egyetlen mező időfüggvény-grafikonja teljes szélességű kártyán.
/// Long press a kártyán → húzás (a szülő ReorderableListView kezeli).
class _ChartCard extends StatelessWidget {
  final String fieldId;
  final String label;
  final String unit;
  final List<OBDSample> samples;
  final Color color;
  final VoidCallback onRemove;

  const _ChartCard({
    required super.key,
    required this.fieldId,
    required this.label,
    required this.unit,
    required this.samples,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Kiszámítjuk a mező időponthoz kötött értékeit (csak ahol van adat)
    final spots = <FlSpot>[];
    if (samples.isNotEmpty) {
      final t0 = samples.first.time.millisecondsSinceEpoch.toDouble();
      for (final s in samples) {
        final v = s.values[fieldId];
        if (v == null) continue;
        final tSec = (s.time.millisecondsSinceEpoch - t0) / 1000.0;
        spots.add(FlSpot(tSec, v));
      }
    }

    final hasData = spots.length >= 2;

    // Aktuális (utolsó ismert) érték a fejléc számkijelzőhöz
    final lastVal = samples.isNotEmpty
        ? samples.lastWhere(
            (s) => s.values.containsKey(fieldId),
            orElse: () => samples.last,
          ).values[fieldId]
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Szín jelző pont
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                // Mező neve
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Jelenlegi érték
                if (lastVal != null) ...[
                  Text(
                    '${_fmtVal(lastVal)} $unit',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color),
                  ),
                  const SizedBox(width: 8),
                ],
                // Eltávolítás (tap = eltávolít, nem indít húzást)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close,
                        color: Colors.grey[500], size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: hasData
                  ? _buildChart(context, spots)
                  : Builder(builder: (ctx) {
                      final msg = ctx.read<LocaleNotifier>().strings.chartDataCollecting;
                      return Center(
                        child: Text(msg,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      );
                    }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<FlSpot> spots) {
    // Y tengely határok (10%-os margóval)
    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    if (range < 1e-6) {
      // Konstans érték → adjunk szimmetrikus 1 egységnyi margót
      minY -= 1;
      maxY += 1;
    } else {
      minY -= range * 0.10;
      maxY += range * 0.10;
    }

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        // Érintés letiltva: a fl_chart ne fogja el a long press eseményt —
        // így a ReorderableListView alapértelmezett long-press drag-je működik.
        lineTouchData: const LineTouchData(enabled: false),
        clipData: FlClipData.all(),
        titlesData: FlTitlesData(
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          // X tengely: nem kell feliratozni (időbélyeg helyett sorrend látszik)
          bottomTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) {
                // A tengelyhatárokon nincs felirat (ne csússzon ki a széleken)
                if (v == meta.min || v == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _fmtY(v),
                  style: const TextStyle(
                      color: Color(0xFF666666), fontSize: 9),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Theme.of(context).colorScheme.outlineVariant, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: color,
            barWidth: 2,
            dotData: FlDotData(show: false),
            isStrokeCapRound: true,
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
      duration: Duration.zero,
    );
  }

  /// Y tengely feliratok: kompakt formátum, ezres tagolással.
  String _fmtY(double v) {
    if (v.abs() >= 10000) return '${(v / 1000).toStringAsFixed(0)}k';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v.abs() >= 10) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  /// Fejléc értékkijelző: 1 tizedesjegy 10 alatti, egész fölötte.
  String _fmtVal(double v) =>
      v.abs() < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0);
}
