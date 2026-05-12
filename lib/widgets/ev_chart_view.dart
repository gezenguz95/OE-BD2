import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/trip_data.dart';
import '../services/locale_notifier.dart';
import 'dashboard_cards.dart';

enum _Metric { power, speed, soc }

/// Valósidős EV vonaldiagram: teljesítmény, sebesség vagy SOC metrika váltható.
class EvChartView extends StatefulWidget {
  final List<EvDataPoint> points;

  const EvChartView({super.key, required this.points});

  @override
  State<EvChartView> createState() => _EvChartViewState();
}

class _EvChartViewState extends State<EvChartView> {
  _Metric _metric = _Metric.power;

  AppLocalizations get _l => context.read<LocaleNotifier>().strings;

  @override
  Widget build(BuildContext context) {
    final l = _l;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: SegmentedButton<_Metric>(
            segments: [
              ButtonSegment(
                value: _Metric.power,
                label: Text(l.powerLabel),
                icon: const Icon(Icons.electric_bolt, size: 14),
              ),
              ButtonSegment(
                value: _Metric.speed,
                label: Text(l.speedLabel),
                icon: const Icon(Icons.speed, size: 14),
              ),
              const ButtonSegment(
                value: _Metric.soc,
                label: Text('SOC'),
                icon: Icon(Icons.battery_full, size: 14),
              ),
            ],
            selected: {_metric},
            onSelectionChanged: (v) => setState(() => _metric = v.first),
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith<Color>((s) {
                if (s.contains(WidgetState.selected)) return const Color(0xFF42A5F5);
                return Theme.of(context).colorScheme.surface;
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color>((s) {
                if (s.contains(WidgetState.selected)) return Colors.black;
                return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);
              }),
              iconColor: WidgetStateProperty.resolveWith<Color>((s) {
                if (s.contains(WidgetState.selected)) return Colors.black;
                return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
              }),
              side: WidgetStateProperty.all(
                BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          ),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
            child: widget.points.length < 3
                ? Center(
                    child: Text(l.dataCollectionInProgress,
                        style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  )
                : _buildChart(),
          ),
        ),

        if (widget.points.isNotEmpty) _buildCurrentCard(),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildChart() {
    final l   = _l;
    final pts = widget.points;
    final cfg = _config(l);
    final t0 = pts.first.time.millisecondsSinceEpoch / 1000.0;

    final spots = pts.map((p) {
      final x = p.time.millisecondsSinceEpoch / 1000.0 - t0;
      final y = _value(p);
      return FlSpot(x, y);
    }).toList();

    final maxX = spots.last.x.clamp(60.0, double.infinity);
    final interval = maxX > 90 ? 30.0 : 15.0;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: cfg.minY,
        maxY: cfg.maxY,
        clipData: FlClipData.all(),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Theme.of(context).colorScheme.surface,
            tooltipBorder: BorderSide(color: Theme.of(context).colorScheme.outline),
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} ${cfg.unit}',
                      TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12),
                    ))
                .toList(),
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: interval,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}s',
                style: const TextStyle(
                    color: Color(0xFF666666), fontSize: 10),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) {
                // A tengelyhatárokra nem írunk feliratot — szélükön nincs hely
                if (v == meta.min || v == meta.max) return const SizedBox.shrink();
                return Text(
                  v.toStringAsFixed(0),
                  style: const TextStyle(
                      color: Color(0xFF666666), fontSize: 10),
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
          // Teljesítmény nézetben szaggatott nullavonal jelzi a REGEN / MOTOR határát
          if (_metric == _Metric.power)
            LineChartBarData(
              spots: [FlSpot(0, 0), FlSpot(maxX, 0)],
              color: const Color(0xFF444444),
              barWidth: 1,
              dotData: FlDotData(show: false),
              dashArray: [4, 4],
            ),
          // Fő adatsor (teljesítmény / sebesség / SOC)
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: cfg.lineColor,
            barWidth: 2,
            dotData: FlDotData(show: false),
            isStrokeCapRound: true,
            // Kitöltés a vonal alatt (pozitív teljesítmény, sebesség, SOC)
            belowBarData: BarAreaData(
              show: true,
              color: cfg.fillColor,
              cutOffY: 0,
              applyCutOffY: _metric == _Metric.power,
            ),
            // Kitöltés a vonal felett: csak teljesítmény nézetben, negatív (REGEN) értékekhez
            aboveBarData: _metric == _Metric.power
                ? BarAreaData(
                    show: true,
                    color: const Color(0xFF66BB6A).withValues(alpha: 0.18),
                    cutOffY: 0,
                    applyCutOffY: true,
                  )
                : BarAreaData(show: false),
          ),
        ],
      ),
      duration: Duration.zero,
    );
  }

  Widget _buildCurrentCard() {
    final l   = _l;
    final last = widget.points.last;
    final cfg = _config(l);
    final val = _value(last);
    final isRegen = _metric == _Metric.power && val < -0.5;
    final valueColor = isRegen ? const Color(0xFF66BB6A) : cfg.lineColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: DCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(cfg.label,
                style: const TextStyle(
                    color: Color(0xFF999999), fontSize: 13)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  val.abs() < 0.05 ? '0' : val.toStringAsFixed(1),
                  style: TextStyle(
                      color: valueColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Text(cfg.unit,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 13)),
                if (isRegen) ...[
                  const SizedBox(width: 8),
                  const Text('REGEN',
                      style: TextStyle(
                          color: Color(0xFF66BB6A),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _value(EvDataPoint p) {
    switch (_metric) {
      case _Metric.power:
        return p.power;
      case _Metric.speed:
        return p.speed;
      case _Metric.soc:
        return p.soc;
    }
  }

  _ChartCfg _config(AppLocalizations l) {
    final pts = widget.points;
    switch (_metric) {
      case _Metric.power:
        double minY = -20, maxY = 20;
        if (pts.isNotEmpty) {
          final dMin = pts.map((p) => p.power).reduce(math.min);
          final dMax = pts.map((p) => p.power).reduce(math.max);
            // 5 kW puffer + 10 kW-ra kerekítés, hogy a grafikon ne legyen szoros
          minY = ((((dMin - 5) / 10).floor()) * 10.0).clamp(-70.0, -5.0);
          maxY = ((((dMax + 5) / 10).ceil()) * 10.0).clamp(10.0, 155.0);
        }
        return _ChartCfg(
          label: l.powerLabel, unit: 'kW',
          minY: minY, maxY: maxY,
          lineColor: const Color(0xFF42A5F5),
          fillColor: const Color(0x2642A5F5),
        );
      case _Metric.speed:
        double maxY = 40;
        if (pts.isNotEmpty) {
          final dMax = pts.map((p) => p.speed).reduce(math.max);
          // 10 km/h puffer + 20-asra kerekítés felfelé, minimum 40 km/h
          maxY = (((dMax + 10) / 20).ceil() * 20.0).clamp(40.0, 160.0);
        }
        return _ChartCfg(
          label: l.speedLabel, unit: 'km/h',
          minY: 0, maxY: maxY,
          lineColor: const Color(0xFFFFA726),
          fillColor: const Color(0x26FFA726),
        );
      case _Metric.soc:
        return _ChartCfg(
          label: 'SOC', unit: '%',
          minY: 0, maxY: 100,
          lineColor: const Color(0xFF4CAF50),
          fillColor: const Color(0x264CAF50),
        );
    }
  }
}

class _ChartCfg {
  final String label, unit;
  final double minY, maxY;
  final Color lineColor, fillColor;

  const _ChartCfg({
    required this.label,
    required this.unit,
    required this.minY,
    required this.maxY,
    required this.lineColor,
    required this.fillColor,
  });
}
