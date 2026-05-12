// Töltési görbe widget — SOC (%) az X tengely, kW vagy °C az Y tengely.
// SegmentedButton váltja a "Teljesítmény" és "Hőmérséklet" nézetet.
// Ha kevesebb mint 2 pont áll rendelkezésre, helyőrző szöveg jelenik meg.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../models/charge_data.dart';
import '../services/locale_notifier.dart';

enum _ChargeMetric { power, temp }

/// Töltési görbe — SOC függvényében mutatja a töltési teljesítményt vagy a hőmérsékletet.
class ChargeChartView extends StatefulWidget {
  final List<ChargeDataPoint> points;

  const ChargeChartView({super.key, required this.points});

  @override
  State<ChargeChartView> createState() => _ChargeChartViewState();
}

class _ChargeChartViewState extends State<ChargeChartView> {
  _ChargeMetric _metric = _ChargeMetric.power;

  @override
  Widget build(BuildContext context) {
    final hasData = widget.points.length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.show_chart,
              size: 16,
              color: _metric == _ChargeMetric.power
                  ? const Color(0xFF66BB6A)
                  : const Color(0xFFFFA726),
            ),
            const SizedBox(width: 6),
            Text(
              context.read<LocaleNotifier>().strings.chargeChartTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            // Nézet váltó: Teljesítmény ↔ Hőmérséklet
            SegmentedButton<_ChargeMetric>(
              segments: const [
                ButtonSegment(
                  value: _ChargeMetric.power,
                  label: Text('kW'),
                  icon: Icon(Icons.electric_bolt, size: 13),
                ),
                ButtonSegment(
                  value: _ChargeMetric.temp,
                  label: Text('°C'),
                  icon: Icon(Icons.thermostat, size: 13),
                ),
              ],
              selected: {_metric},
              onSelectionChanged: (v) => setState(() => _metric = v.first),
              style: ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                backgroundColor: WidgetStateProperty.resolveWith<Color>((s) {
                  if (s.contains(WidgetState.selected)) {
                    return _metric == _ChargeMetric.power
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE65100);
                  }
                  return Theme.of(context).colorScheme.surface;
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color>((s) {
                  if (s.contains(WidgetState.selected)) return Colors.white;
                  return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);
                }),
                iconColor: WidgetStateProperty.resolveWith<Color>((s) {
                  if (s.contains(WidgetState.selected)) return Colors.white;
                  return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
                }),
                side: WidgetStateProperty.all(
                  BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        SizedBox(
          height: 210,
          child: hasData
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 12, 4),
                  child: _buildChart(),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_top,
                          size: 28, color: Colors.grey[700]),
                      const SizedBox(height: 8),
                      Text(
                        context.read<LocaleNotifier>().strings.chargeDataCollecting,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    final pts = widget.points;

    // Rendezés SOC szerint (növekvő) → a görbe bal→jobb irányban halad
    final sorted = [...pts]..sort((a, b) => a.soc.compareTo(b.soc));
    final spots = sorted.map((p) => FlSpot(p.soc, _yValue(p))).toList();

    final cfg = _chartCfg(sorted);

    // X tengely határok: a tényleges SOC tartomány ±2%-os margóval
    final minX = (sorted.first.soc - 2).clamp(0.0, 98.0);
    final maxX = (sorted.last.soc + 2).clamp(2.0, 100.0);
    final xRange = maxX - minX;
    // X felirat intervallum: sűrűbb ha kis tartomány, ritkább ha nagy
    final xInterval = xRange > 40 ? 10.0 : xRange > 20 ? 5.0 : 2.0;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: cfg.minY,
        maxY: cfg.maxY,
        clipData: FlClipData.all(),

        // Tooltip: SOC % → érték
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
            tooltipBorder: BorderSide(color: Theme.of(context).colorScheme.outline),
            getTooltipItems: (spots) => spots.map((s) {
              final unit = _metric == _ChargeMetric.power ? 'kW' : '°C';
              return LineTooltipItem(
                '${s.x.toStringAsFixed(0)}%  •  ${s.y.toStringAsFixed(1)} $unit',
                TextStyle(
                  color: cfg.lineColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),

        titlesData: FlTitlesData(
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            // "SOC (%)" tengelynév a diagram alatt
            axisNameWidget: Text(
              'SOC (%)',
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
            axisNameSize: 18,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: xInterval,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}%',
                style: const TextStyle(
                    color: Color(0xFF666666), fontSize: 9),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) {
                // A tengelyhatárokon nincs felirat (szorítja a layoutot)
                if (v == meta.min || v == meta.max) {
                  return const SizedBox.shrink();
                }
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
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: cfg.lineColor,
            barWidth: 2.5,
            dotData: FlDotData(show: false),
            isStrokeCapRound: true,
            belowBarData: BarAreaData(
              show: true,
              color: cfg.fillColor,
            ),
          ),
        ],
      ),
      duration: Duration.zero,
    );
  }

  double _yValue(ChargeDataPoint p) =>
      _metric == _ChargeMetric.power ? p.powerKw : p.tempC;

  _ChartCfg _chartCfg(List<ChargeDataPoint> pts) {
    if (_metric == _ChargeMetric.power) {
      // Felső határ: csúcsteljesítmény fölé 5 kW, 10-esre kerekítve
      double maxY = 20;
      if (pts.isNotEmpty) {
        final dMax = pts.map((p) => p.powerKw).reduce(math.max);
        maxY = (((dMax + 5) / 10).ceil() * 10.0).clamp(10.0, 250.0);
      }
      return _ChartCfg(
        minY: 0,
        maxY: maxY,
        lineColor: const Color(0xFF66BB6A),
        fillColor: const Color(0x2066BB6A),
      );
    } else {
      // Hőmérséklet: 5-ösre kerekített tengely a min-max tartomány körül
      double minY = 0, maxY = 45;
      if (pts.isNotEmpty) {
        final dMin = pts.map((p) => p.tempC).reduce(math.min);
        final dMax = pts.map((p) => p.tempC).reduce(math.max);
        minY = (((dMin - 3) / 5).floor() * 5.0).clamp(-10.0, 30.0);
        maxY = (((dMax + 5) / 5).ceil() * 5.0).clamp(20.0, 65.0);
      }
      return _ChartCfg(
        minY: minY,
        maxY: maxY,
        lineColor: const Color(0xFFFFA726),
        fillColor: const Color(0x20FFA726),
      );
    }
  }
}

class _ChartCfg {
  final double minY, maxY;
  final Color lineColor, fillColor;

  const _ChartCfg({
    required this.minY,
    required this.maxY,
    required this.lineColor,
    required this.fillColor,
  });
}
