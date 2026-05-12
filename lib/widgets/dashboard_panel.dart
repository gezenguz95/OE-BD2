// Fekvő elrendezésű, egyszerűsített műszerfal: nagy sebességmérő + 3 infókártya.
// ICE és EV adatkészletet is támogat az isEvMode kapcsolóval.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/locale_notifier.dart';
import 'dashboard_gauge.dart';

/// Fekvő elrendezésű műszerfal panel: bal oldalt a sebességmérő, jobb oldalt mód-specifikus infókártyák.
class DashboardPanel extends StatelessWidget {
  final Map<String, String> data;
  final bool isEvMode;

  const DashboardPanel({
    super.key,
    required this.data,
    this.isEvMode = false,
  });

  double _parseValue(String pid) {
    if (!data.containsKey(pid)) return 0.0;
    final val = data[pid]!;
    if (val == '--') return 0.0;
    return double.tryParse(val) ?? 0.0;
  }
  
  String _getText(String pid, [String unit = '']) {
     final val = data[pid] ?? '--';
     if (val == '--') return '--';
     return '$val $unit';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Bal oldal: nagy sebességmérő
          Expanded(
            flex: 6,
            child: Center(
              child: OBDNeedleGauge(
                title: context.read<LocaleNotifier>().strings.speedGaugeLabel,
                value: _parseValue('010D'),
                minValue: 0,
                maxValue: 240,
                unit: 'km/h',
                tickValues: [0, 30, 60, 90, 120, 150, 180, 210, 240],
              ),
            ),
          ),

          // Jobb oldal: mód-specifikus infókártyák
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: isEvMode
                ? _buildEvWidgets(context)
                : _buildIceWidgets(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildIceWidgets(BuildContext context) {
    final l = context.read<LocaleNotifier>().strings;
    return [
      _buildInfoCard(
        title: l.rpmGaugeLabel,
        value: _getText('010C'),
        icon: Icons.speed,
        color: Colors.amber,
      ),
      _buildInfoCard(
        title: l.dashFuelLabel,
        value: _getText('012F', '%'),
        icon: Icons.local_gas_station,
        color: Colors.blueAccent,
      ),
      _buildInfoCard(
        title: l.dashTempLabel,
        value: _getText('0105', '°C'),
        icon: Icons.thermostat,
        color: Colors.redAccent,
      ),
    ];
  }

  List<Widget> _buildEvWidgets(BuildContext context) {
    final l = context.read<LocaleNotifier>().strings;
    return [
      _buildInfoCard(
        title: l.dashBattLabel,
        value: _getText('015B', '%'),
        icon: Icons.battery_charging_full,
        color: Colors.greenAccent,
      ),
      _buildInfoCard(
        title: l.dashVoltageLabel,
        value: _getText('0142', 'V'),
        icon: Icons.electric_bolt,
        color: Colors.yellowAccent,
      ),
      _buildInfoCard(
        title: l.dashExtTempLabel,
        value: _getText('0146', '°C'),
        icon: Icons.ac_unit,
        color: Colors.cyanAccent,
      ),
    ];
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
