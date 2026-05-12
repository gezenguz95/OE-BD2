// lib/widgets/ev_sensors_view.dart
//
// Összes szenzor adat — görgetős, csoportosított lista.
// Minden mért és számított érték egy helyen.

import 'package:flutter/material.dart';
import 'cell_voltage_grid.dart';
import 'dashboard_cards.dart';

class EvSensorsView extends StatelessWidget {
  final Map<String, String> data;
  final Map<String, String> hexDumps;
  final List<double> cellVoltages;

  const EvSensorsView({
    Key? key,
    required this.data,
    required this.hexDumps,
    this.cellVoltages = const [],
  }) : super(key: key);

  double _v(String id) => parseObd(data[id]);
  String _s(String id, {String unit = '', int dec = 1}) {
    final raw = data[id];
    if (raw == null || raw == '--' || raw.isEmpty) return '--';
    final d = double.tryParse(raw);
    if (d == null) return '$raw $unit'.trim();
    final str = dec == 0 ? d.toInt().toString() : d.toStringAsFixed(dec);
    return unit.isEmpty ? str : '$str $unit';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        _section('MENET', Icons.speed, Colors.blue, [
          _row('Sebesség',         _s('speed',        unit: 'km/h', dec: 0)),
          _row('Teljesítmény',     _s('battery_power', unit: 'kW',  dec: 1),
              color: _powerColor(_v('battery_power'))),
          _row('Hatótáv (becslés)',_s('range_km',      unit: 'km',  dec: 0)),
        ]),

        _section('TÖLTÖTTSÉG', Icons.battery_full, Colors.green, [
          _row('SOC (kijelző)',    _s('soc_display',   unit: '%',   dec: 1),
              color: _socColor(_v('soc_display'))),
          _row('SOC (BMS)',        _s('soc_bms',       unit: '%',   dec: 1),
              color: _socColor(_v('soc_bms'))),
          _row('Maradék energia',  _s('remaining_kwh', unit: 'kWh', dec: 1)),
          _row('Max hatótáv',      _s('range_km_max',  unit: 'km',  dec: 0)),
        ]),

        _section('FESZÜLTSÉG & ÁRAM', Icons.electric_bolt, Colors.amber, [
          _row('HV feszültség',    _s('battery_voltage', unit: 'V', dec: 1)),
          _row('HV áram',          _s('battery_current', unit: 'A', dec: 1),
              color: _currentColor(_v('battery_current'))),
          _row('Teljesítmény',     _s('battery_power',   unit: 'kW', dec: 1),
              color: _powerColor(_v('battery_power'))),
          _row('12V akku',         _s('aux_battery_voltage', unit: 'V', dec: 1),
              color: _auxColor(_v('aux_battery_voltage'))),
          _row('Max töltési telj.', _s('ccl', unit: 'kW', dec: 0)),
          _row('Max kisütési telj.',_s('dcl', unit: 'kW', dec: 0)),
        ]),

        _section('CELLÁK', Icons.view_module, const Color(0xFF26C6DA), [
          if (cellVoltages.isNotEmpty)
            CellVoltageGrid(voltages: cellVoltages)
          else
            _row('Min / Átl / Max / Δ',
                '${_s('cell_volt_min', unit: 'V', dec: 3)}  '
                '${_s('cell_volt_avg', unit: 'V', dec: 3)}  '
                '${_s('cell_volt_spread', unit: 'mV', dec: 0)}'),
        ]),

        _section('HŐMÉRSÉKLETEK', Icons.thermostat, Colors.orange, [
          _row('Akku max hőm.',   _s('battery_temp_max', unit: '°C', dec: 0),
              color: _tempColor(_v('battery_temp_max'))),
          _row('Akku min hőm.',   _s('battery_temp_min', unit: '°C', dec: 0),
              color: _tempColor(_v('battery_temp_min'))),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          _row('Modul 1',  _s('mod_temp_1', unit: '°C', dec: 0)),
          _row('Modul 2',  _s('mod_temp_2', unit: '°C', dec: 0)),
          _row('Modul 3',  _s('mod_temp_3', unit: '°C', dec: 0)),
          _row('Modul 4',  _s('mod_temp_4', unit: '°C', dec: 0)),
          _row('Modul 5',  _s('mod_temp_5', unit: '°C', dec: 0)),
          _row('Modul 6',  _s('mod_temp_6', unit: '°C', dec: 0)),
          _row('Modul 7',  _s('mod_temp_7', unit: '°C', dec: 0)),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          _row('Hűtő be',  _s('coolant_in',  unit: '°C', dec: 0)),
          _row('Hűtő ki',  _s('coolant_out', unit: '°C', dec: 0)),
        ]),

        _section('AKKUMULÁTOR EGÉSZSÉG', Icons.health_and_safety, Colors.purple, [
          _row('SOH',             _s('soh', unit: '%', dec: 1),
              color: _sohColor(_v('soh'))),
          _row('Összesen töltve', _s('cec', unit: 'kWh', dec: 0)),
          _row('Összesen merítve',_s('ced', unit: 'kWh', dec: 0)),
          _row('Üzemóra',         _s('op_time', unit: 'h', dec: 0)),
        ]),

        if (hexDumps.isNotEmpty)
          _section('RAW BYTE DUMP', Icons.code, Colors.grey, [
            ...hexDumps.entries.map((e) => _hexBlock(e.key, e.value)),
          ]),
      ],
    );
  }

  // ── Szekció ────────────────────────────────────────────────────────────

  Widget _section(String title, IconData icon, Color color, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
          child: Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(
                color: color, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ]),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            for (int i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i < rows.length - 1 && rows[i] is! Divider)
                const Divider(color: Color(0xFF2A2A2A), height: 1,
                    indent: 16, endIndent: 16),
            ],
          ]),
        ),
      ]),
    );
  }

  // ── Sor ───────────────────────────────────────────────────────────────

  Widget _row(String label, String value, {Color? color}) {
    final missing = value == '--';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 14))),
        Text(
          missing ? '--' : value,
          style: TextStyle(
            color: missing ? const Color(0xFF555555)
                : (color ?? Colors.white),
            fontSize: 15,
            fontWeight: missing ? FontWeight.normal : FontWeight.bold,
          ),
        ),
      ]),
    );
  }

  // ── Hex blokk ─────────────────────────────────────────────────────────

  Widget _hexBlock(String name, String hex) {
    final bytes = hex.split(' ');
    final lines = [
      for (int i = 0; i < bytes.length; i += 16)
        '[${i.toString().padLeft(2, '0')}] '
        '${bytes.sublist(i, (i + 16).clamp(0, bytes.length)).join(' ')}',
    ].join('\n');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name,
            style: const TextStyle(color: Color(0xFF9E9E9E),
                fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Text(lines,
            style: const TextStyle(fontFamily: 'monospace',
                fontSize: 10, color: Color(0xFF77BB77))),
      ]),
    );
  }

  // ── Szín segédek ──────────────────────────────────────────────────────

  Color _socColor(double v) {
    if (v <= 0)  return Colors.white;
    if (v < 10)  return Colors.red;
    if (v < 20)  return Colors.orange;
    return const Color(0xFF66BB6A);
  }

  Color _tempColor(double v) {
    if (v >= 45) return Colors.red;
    if (v >= 35) return Colors.orange;
    if (v <= 0)  return Colors.lightBlue;
    return Colors.white;
  }

  Color _powerColor(double v) {
    if (v < -1) return const Color(0xFF66BB6A);   // rekuperáció
    if (v > 1)  return const Color(0xFF42A5F5);   // fogyasztás
    return Colors.white;
  }

  Color _currentColor(double v) {
    if (v < -1) return const Color(0xFF66BB6A);
    if (v > 1)  return const Color(0xFF42A5F5);
    return Colors.white;
  }

  Color _auxColor(double v) {
    if (v <= 0)    return Colors.white;
    if (v < 11.5)  return Colors.red;
    if (v < 12.0)  return Colors.orange;
    return const Color(0xFFFDD835);
  }

  Color _spreadColor(double v) {
    if (v <= 0)  return Colors.white;
    if (v > 50)  return Colors.red;
    if (v > 20)  return Colors.orange;
    return const Color(0xFF66BB6A);
  }

  Color _sohColor(double v) {
    if (v <= 0)  return Colors.white;
    if (v < 80)  return Colors.red;
    if (v < 90)  return Colors.orange;
    return const Color(0xFF66BB6A);
  }
}
