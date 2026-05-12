// lib/widgets/ev_chart_view.dart
//
// Valósidős EV grafikon — fl_chart LineChart.
// Megjeleníti az utolsó ~2 percet: Teljesítmény / Sebesség / SOC.

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/trip_data.dart';
import 'dashboard_cards.dart';

enum _Metric { power, speed, soc }

class EvChartView extends StatefulWidget {
  final List<EvDataPoint> points;

  const EvChartView({Key? key, required this.points}) : super(key: key);

  @override
  State<EvChartView> createState() => _EvChartViewState();
}

class _EvChartViewState extends State<EvChartView> {
  _Metric _metric = _Metric.power;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212),
      child: Column(children: [
        // ── Metrika váltó ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: SegmentedButton<_Metric>(
            segments: const [
              ButtonSegment(
                value: _Metric.power,
                label: Text('Teljesítmény'),
                icon: Icon(Icons.electric_bolt, size: 14),
              ),
              ButtonSegment(
                value: _Metric.speed,
                label: Text('Sebesség'),
                icon: Icon(Icons.speed, size: 14),
              ),
              ButtonSegment(
                value: _Metric.soc,
                label: Text('SOC'),
                icon: Icon(Icons.battery_full, size: 14),
              ),
            ],
            selected: {_metric},
            onSelectionChanged: (v) => setState(() => _metric = v.first),
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),

        // ── Grafikon ───────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
            child: widget.points.length < 3
                ? const Center(
                    child: Text('Adatgyűjtés folyamatban...',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                  )
                : _buildChart(),
          ),
        ),

        // ── Jelenlegi érték ────────────────────────────────────────────────
        if (widget.points.isNotEmpty) _buildCurrentCard(),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildChart() {
    final pts = widget.points;
    final cfg = _config();
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
            tooltipBgColor: const Color(0xFF2A2A2A),
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} ${cfg.unit}',
                      const TextStyle(color: Colors.white, fontSize: 12),
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
                // Csak főbb értékeket jelenítünk meg
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
              FlLine(color: const Color(0xFF2A2A2A), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Teljesítmény grafikon: nulla vonal
          if (_metric == _Metric.power)
            LineChartBarData(
              spots: [FlSpot(0, 0), FlSpot(maxX, 0)],
              color: const Color(0xFF444444),
              barWidth: 1,
              dotData: FlDotData(show: false),
              dashArray: [4, 4],
            ),
          // Fő adatsor
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: cfg.lineColor,
            barWidth: 2,
            dotData: FlDotData(show: false),
            isStrokeCapRound: true,
            // Motor terület (pozitív teljesítmény / sebesség / SOC)
            belowBarData: BarAreaData(
              show: true,
              color: cfg.fillColor,
              cutOffY: 0,
              applyCutOffY: _metric == _Metric.power,
            ),
            // Rekuperáció terület (negatív teljesítmény)
            aboveBarData: _metric == _Metric.power
                ? BarAreaData(
                    show: true,
                    color: const Color(0xFF66BB6A).withOpacity(0.18),
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
    final last = widget.points.last;
    final cfg = _config();
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

  _ChartCfg _config() {
    switch (_metric) {
      case _Metric.power:
        return const _ChartCfg(
          label: 'Teljesítmény',
          unit: 'kW',
          minY: -65,
          maxY: 155,
          lineColor: Color(0xFF42A5F5),
          fillColor: Color(0x2642A5F5),
        );
      case _Metric.speed:
        return const _ChartCfg(
          label: 'Sebesség',
          unit: 'km/h',
          minY: 0,
          maxY: 160,
          lineColor: Color(0xFFFFA726),
          fillColor: Color(0x26FFA726),
        );
      case _Metric.soc:
        return const _ChartCfg(
          label: 'Töltöttség',
          unit: '%',
          minY: 0,
          maxY: 100,
          lineColor: Color(0xFF4CAF50),
          fillColor: Color(0x264CAF50),
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
