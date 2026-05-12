// lib/widgets/dashboard_panel.dart
//
// MODULE: Dashboard Layout Container
// PURPOSE:
// Provides a landscape layout combining the Speedometer and informational cards.
// Supports Dynamic switching between ICE (Gas) and EV data sets.

import 'package:flutter/material.dart';
import 'dashboard_gauge.dart';

class DashboardPanel extends StatelessWidget {
  final Map<String, String> data;
  final bool isEvMode;

  const DashboardPanel({
    Key? key,
    required this.data,
    this.isEvMode = false,
  }) : super(key: key);

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
    // Landscape Layout
    return Container(
      color: Colors.black, // Dark tech look
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // LEFT: Speedometer (Big)
          Expanded(
            flex: 6,
            child: Center(
              child: OBDNeedleGauge(
                title: 'SPEED',
                value: _parseValue('010D'),
                minValue: 0,
                maxValue: 240,
                unit: 'km/h',
                tickValues: [0, 30, 60, 90, 120, 150, 180, 210, 240],
              ),
            ),
          ),
          
          // RIGHT: Info Stack
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: isEvMode 
                ? _buildEvWidgets() 
                : _buildIceWidgets(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildIceWidgets() {
    return [
      _buildInfoCard(
        title: 'RPM',
        value: _getText('010C'),
        icon: Icons.speed,
        color: Colors.amber,
      ),
      _buildInfoCard(
        title: 'ÜZEMANYAG',
        value: _getText('012F', '%'),
        icon: Icons.local_gas_station,
        color: Colors.blueAccent,
      ),
      _buildInfoCard(
        title: 'HŐMÉRSÉKLET',
        value: _getText('0105', '°C'),
        icon: Icons.thermostat,
        color: Colors.redAccent,
      ),
    ];
  }

  List<Widget> _buildEvWidgets() {
    return [
      _buildInfoCard(
        title: 'AKKU',
        value: _getText('015B', '%'), 
        icon: Icons.battery_charging_full,
        color: Colors.greenAccent,
      ),
      _buildInfoCard(
        title: 'FESZÜLTSÉG',
        value: _getText('0142', 'V'),
        icon: Icons.electric_bolt,
        color: Colors.yellowAccent,
      ),
      _buildInfoCard(
        title: 'KÜL. HŐMÉR.',
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
        border: Border.all(color: color.withOpacity(0.5)),
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
