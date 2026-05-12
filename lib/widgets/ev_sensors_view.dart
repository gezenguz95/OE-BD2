// EV szenzor lista — összes mért és számított érték csoportosítva, görgetős nézetben.
// Szekciók: Menet, Töltöttség, Feszültség/Áram, Cellák, Hőmérsékletek, Akkumulátor egészség.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/locale_notifier.dart';
import 'cell_voltage_grid.dart';
import 'dashboard_cards.dart';

/// Görgetős szenzornézet: az összes OBD értéket tematikus szekcióban jeleníti meg.
class EvSensorsView extends StatelessWidget {
  final Map<String, String> data;
  final Map<String, String> hexDumps;
  final List<double> cellVoltages;

  const EvSensorsView({
    super.key,
    required this.data,
    required this.hexDumps,
    this.cellVoltages = const [],
  });

  double _v(String id) => parseObd(data[id]);
  String _s(String id, {String unit = '', int dec = 1}) {
    final raw = data[id];
    if (raw == null || raw == '--' || raw.isEmpty) return '--';
    final d = double.tryParse(raw);
    if (d == null) return '$raw $unit'.trim();
    final str = dec == 0 ? d.toInt().toString() : d.toStringAsFixed(dec);
    return unit.isEmpty ? str : '$str $unit';
  }

  /// True ha a jármű tartalmaz ICE adatokat (PHEV megkülönböztetés)
  bool get _hasIce => data.containsKey('fuel_level');

  @override
  Widget build(BuildContext context) {
    final l       = context.read<LocaleNotifier>().strings;
    final divider = Divider(
        color: Theme.of(context).dividerColor, height: 1);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        _section(context, l.sectionDriving, Icons.speed, Colors.blue, [
          _row(context, l.speedLabel,       _s('speed',        unit: 'km/h', dec: 0)),
          _row(context, l.powerLabel,       _s('battery_power', unit: 'kW',  dec: 1),
              color: _powerColor(_v('battery_power'))),
          _row(context, l.rangeEstShort,    _s('range_km',      unit: 'km',  dec: 0)),
        ]),

        _section(context, l.sectionSoc, Icons.battery_full, Colors.green, [
          _row(context, l.socDisplayLabel,  _s('soc_display',   unit: '%',   dec: 1),
              color: _socColor(_v('soc_display'))),
          _row(context, l.socBmsLabel,      _s('soc_bms',       unit: '%',   dec: 1),
              color: _socColor(_v('soc_bms'))),
          _row(context, l.remainingEnergyLabel, _s('remaining_kwh', unit: 'kWh', dec: 1)),
          _row(context, l.maxRangeLabel,    _s('range_km_max',  unit: 'km',  dec: 0)),
        ]),

        _section(context, l.sectionVoltCurr, Icons.electric_bolt, Colors.amber, [
          _row(context, l.hvVoltage,        _s('battery_voltage', unit: 'V', dec: 1)),
          _row(context, l.hvCurrLabel,      _s('battery_current', unit: 'A', dec: 1),
              color: _currentColor(_v('battery_current'))),
          _row(context, l.powerLabel,       _s('battery_power',   unit: 'kW', dec: 1),
              color: _powerColor(_v('battery_power'))),
          _row(context, l.aux12VLabel,      _s('aux_battery_voltage', unit: 'V', dec: 1),
              color: _auxColor(_v('aux_battery_voltage'))),
          _row(context, l.maxChargePowerLabel,    _s('ccl', unit: 'kW', dec: 0)),
          _row(context, l.maxDischargePowerLabel, _s('dcl', unit: 'kW', dec: 0)),
        ]),

        _section(context, l.sectionCells, Icons.view_module, const Color(0xFF26C6DA), [
          if (cellVoltages.isNotEmpty)
            CellVoltageGrid(voltages: cellVoltages)
          else
            _row(context, l.cellMinAvgMaxDelta,
                '${_s('cell_volt_min', unit: 'V', dec: 3)}  '
                '${_s('cell_volt_avg', unit: 'V', dec: 3)}  '
                '${_s('cell_volt_spread', unit: 'mV', dec: 0)}'),
        ]),

        _section(context, l.sectionTemps, Icons.thermostat, Colors.orange, [
          _row(context, l.batteryMaxTempLabel, _s('battery_temp_max', unit: '°C', dec: 0),
              color: _tempColor(_v('battery_temp_max'))),
          _row(context, l.batteryMinTempLabel, _s('battery_temp_min', unit: '°C', dec: 0),
              color: _tempColor(_v('battery_temp_min'))),
          divider,
          _row(context, l.moduleTempLabel(1), _s('mod_temp_1', unit: '°C', dec: 0)),
          _row(context, l.moduleTempLabel(2), _s('mod_temp_2', unit: '°C', dec: 0)),
          _row(context, l.moduleTempLabel(3), _s('mod_temp_3', unit: '°C', dec: 0)),
          _row(context, l.moduleTempLabel(4), _s('mod_temp_4', unit: '°C', dec: 0)),
          _row(context, l.moduleTempLabel(5), _s('mod_temp_5', unit: '°C', dec: 0)),
          _row(context, l.moduleTempLabel(6), _s('mod_temp_6', unit: '°C', dec: 0)),
          _row(context, l.moduleTempLabel(7), _s('mod_temp_7', unit: '°C', dec: 0)),
          divider,
          _row(context, l.coolantInLabel,  _s('coolant_in',  unit: '°C', dec: 0)),
          _row(context, l.coolantOutLabel, _s('coolant_out', unit: '°C', dec: 0)),
        ]),

        _section(context, l.sectionBattHealth, Icons.health_and_safety, Colors.purple, [
          _row(context, l.sohLabel,              _s('soh', unit: '%', dec: 1),
              color: _sohColor(_v('soh'))),
          _row(context, l.totalChargedLabel,    _s('cec', unit: 'kWh', dec: 0)),
          _row(context, l.totalDischargedLabel, _s('ced', unit: 'kWh', dec: 0)),
          _row(context, l.operatingHoursLabel,  _s('op_time', unit: 'h', dec: 0)),
        ]),

        // ── Benzinmotor adatok — csak PHEV esetén jelenik meg ──────────────
        if (_hasIce)
          _section(context, l.sectionGasEngine, Icons.local_gas_station, Colors.deepOrange, [
            _row(context, l.engineRpmSensLabel,
                _v('rpm') > 0 ? _s('rpm', unit: 'RPM', dec: 0) : '0 RPM',
                color: _v('rpm') > 0
                    ? Colors.deepOrange
                    : Theme.of(context).colorScheme.onSurface),
            _row(context, l.engineLoadLabel, _s('engine_load', unit: '%', dec: 0),
                color: _engineLoadColor(_v('engine_load'))),
            divider,
            _row(context, l.fuelLevelSensLabel,     _s('fuel_level', unit: '%', dec: 0),
                color: _fuelColor(_v('fuel_level'))),
            _row(context, l.coolantTempShortLabel,  _s('coolant_temp', unit: '°C', dec: 0),
                color: _coolantColor(_v('coolant_temp'))),
          ]),

        if (hexDumps.isNotEmpty)
          _section(context, 'RAW BYTE DUMP', Icons.code, Colors.grey, [
            ...hexDumps.entries.map((e) => _hexBlock(context, e.key, e.value)),
          ]),
      ],
    );
  }

  /// Ikonal és fejléccel ellátott szekciót épít a megadott sorokból.
  Widget _section(BuildContext context, String title, IconData icon,
      Color color, List<Widget> rows) {
    final cs = Theme.of(context).colorScheme;
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
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outline, width: 1),
          ),
          child: Column(children: [
            for (int i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i < rows.length - 1 && rows[i] is! Divider)
                Divider(color: Theme.of(context).dividerColor, height: 1,
                    indent: 16, endIndent: 16),
            ],
          ]),
        ),
      ]),
    );
  }

  /// Felirat–érték pár; ha az érték '--', halvány stílussal jelzi a hiányzó adatot.
  Widget _row(BuildContext context, String label, String value, {Color? color}) {
    final cs      = Theme.of(context).colorScheme;
    final tt      = Theme.of(context).textTheme;
    final missing = value == '--';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        Expanded(child: Text(label,
            style: TextStyle(
                color: tt.bodySmall?.color ?? const Color(0xFFB0B0B0),
                fontSize: 14))),
        Text(
          missing ? '--' : value,
          style: TextStyle(
            color: missing
                ? (tt.labelSmall?.color ?? const Color(0xFF555555))
                : (color ?? cs.onSurface),
            fontSize: 15,
            fontWeight: missing ? FontWeight.normal : FontWeight.bold,
          ),
        ),
      ]),
    );
  }

  /// Nyers OBD bájtokat 16 bájtos sorokba tördeli monospace szövegként.
  Widget _hexBlock(BuildContext context, String name, String hex) {
    final tt    = Theme.of(context).textTheme;
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
            style: TextStyle(color: tt.bodySmall?.color ?? const Color(0xFF9E9E9E),
                fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Text(lines,
            style: const TextStyle(fontFamily: 'monospace',
                fontSize: 10, color: Color(0xFF77BB77))),
      ]),
    );
  }

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
    if (v < -1) return const Color(0xFF66BB6A);   // zöld: rekuperáció
    if (v > 1)  return const Color(0xFF42A5F5);   // kék: fogyasztás
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

  Color _sohColor(double v) {
    if (v <= 0)  return Colors.white;
    if (v < 80)  return Colors.red;
    if (v < 90)  return Colors.orange;
    return const Color(0xFF66BB6A);
  }

  Color _fuelColor(double v) {
    if (v <= 0)  return Colors.white;
    if (v < 10)  return Colors.red;
    if (v < 20)  return Colors.orange;
    return const Color(0xFF66BB6A);
  }

  Color _coolantColor(double v) {
    if (v <= 0)   return Colors.white;
    if (v >= 110) return Colors.red;
    if (v >= 100) return Colors.orange;
    if (v < 60)   return Colors.lightBlue;
    return Colors.white;
  }

  Color _engineLoadColor(double v) {
    if (v <= 0)  return Colors.white;
    if (v >= 90) return Colors.red;
    if (v >= 70) return Colors.orange;
    return Colors.white;
  }
}
