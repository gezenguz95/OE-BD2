// PHEV Plugin kombinált kijelző — EV és ICE adatok egy nézetben.
// Sebesség kiemelten, EV töltöttség + hatótáv sávok,
// ICE üzemanyag sáv + RPM + hűtőfolyadék, akku hőmérséklet.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/locale_notifier.dart';
import '../theme/app_theme.dart';
import 'dashboard_gauge.dart';
import 'dashboard_cards.dart';

/// Plugin kombinált műszerfal Ford Kuga PHEV-hez.
/// EV és ICE legfontosabb adatai egyszerre láthatók.
class PhevDashboard extends StatelessWidget {
  final Map<String, String> data;
  final double? externalTemp;
  final int rangeMode;

  const PhevDashboard({
    super.key,
    required this.data,
    this.externalTemp,
    this.rangeMode = 0,
  });

  double _v(String id) => parseObd(data[id]);

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return LayoutBuilder(builder: (ctx, box) {
      final landscape = box.maxWidth > box.maxHeight;
      return landscape
          ? _buildLandscape(ctx, bottomPad: bottomPad)
          : _buildPortrait(ctx, bottomPad: bottomPad);
    });
  }

  AppLocalizations _l(BuildContext context) =>
      context.read<LocaleNotifier>().strings;

  Widget _buildPortrait(BuildContext context, {double bottomPad = 0}) {
    final l      = _l(context);
    final speed   = _v('speed');
    final soc     = _v('soc_display') > 0 ? _v('soc_display') : _v('soc_bms');
    final remKwh  = _v('remaining_kwh');
    final rangeKm = _v('range_km');
    final maxRange = _v('range_km_max') > 0 ? _v('range_km_max') : 50.0;
    final power   = _power();
    final fuel    = _v('fuel_level');
    final rpm     = _v('rpm');
    final coolant = _v('coolant_temp');
    final battTemp = _v('battery_temp_max');
    final running = rpm > 50;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(10, 8, 10, 10 + bottomPad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // Sebesség + ICE státusz egymás mellé
          Row(children: [
            Expanded(flex: 3, child: _speedGauge(context, speed)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _iceStatusCard(context, running, rpm)),
          ]),
          const SizedBox(height: 8),

          // EV: töltöttség sáv
          _socBar(context, soc, remKwh),
          const SizedBox(height: 6),

          // EV: elektromos hatótáv sáv
          _evRangeBar(context, soc, rangeKm, maxRange),
          const SizedBox(height: 6),

          // ICE: üzemanyag sáv
          _fuelBar(context, fuel),
          const SizedBox(height: 6),

          // Kártyák: EV teljesítmény | ICE hűtőfolyadék
          Row(children: [
            Expanded(child: _bigCard(
              label: l.evPower,
              value: power.abs() > 0.01 ? fmtVal(power, decimals: 1) : '0',
              unit: 'kW',
              color: power < -0.5 ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5),
            )),
            const SizedBox(width: 6),
            Expanded(child: _bigCard(
              label: l.coolantIce,
              value: coolant > 0 ? fmtVal(coolant, decimals: 0) : '--',
              unit: '°C',
              color: _coolantColor(coolant),
            )),
          ]),
          const SizedBox(height: 6),

          // Kártyák: akku hőm. | HV feszültség
          Row(children: [
            Expanded(child: _bigCard(
              label: l.battTempShort,
              value: fmtVal(battTemp, decimals: 0),
              unit: '°C',
              color: _battTempColor(battTemp),
            )),
            const SizedBox(width: 6),
            Expanded(child: _bigCard(
              label: l.hvVoltage,
              value: _v('battery_voltage') > 0
                  ? fmtVal(_v('battery_voltage'), decimals: 1)
                  : '--',
              unit: 'V',
              color: const Color(0xFF42A5F5),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _buildLandscape(BuildContext context, {double bottomPad = 0}) {
    final l        = _l(context);
    final speed    = _v('speed');
    final soc      = _v('soc_display') > 0 ? _v('soc_display') : _v('soc_bms');
    final remKwh   = _v('remaining_kwh');
    final rangeKm  = _v('range_km');
    final maxRange = _v('range_km_max') > 0 ? _v('range_km_max') : 50.0;
    final power    = _power();
    final fuel     = _v('fuel_level');
    final rpm      = _v('rpm');
    final coolant  = _v('coolant_temp');
    final battTemp = _v('battery_temp_max');
    final running  = rpm > 50;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // Bal: sebességmérő
        Expanded(flex: 4, child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(builder: (ctx, box) {
            final maxW = ((box.maxHeight - 80) * 1.2).clamp(80.0, box.maxWidth);
            return Center(child: SizedBox(width: maxW, child: _speedGauge(context, speed)));
          }),
        )),

        // Jobb: adatpanel
        Expanded(flex: 6, child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // EV SOC + hatótáv
            _socBar(context, soc, remKwh),
            const SizedBox(height: 4),
            _evRangeBar(context, soc, rangeKm, maxRange),
            const SizedBox(height: 4),

            // ICE üzemanyag
            _fuelBar(context, fuel),
            const SizedBox(height: 4),

            // Kártyák sor: EV telj. | Akku hőm. | RPM/EV mód | Hűtő
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _bigCard(
                label: l.evPowerShort,
                value: power.abs() > 0.01 ? fmtVal(power, decimals: 1) : '0',
                unit: 'kW',
                color: power < -0.5 ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5),
              )),
              const SizedBox(width: 4),
              Expanded(child: _bigCard(
                label: l.battTempShort,
                value: fmtVal(battTemp, decimals: 0),
                unit: '°C',
                color: _battTempColor(battTemp),
              )),
              const SizedBox(width: 4),
              Expanded(child: _bigCard(
                label: running ? 'RPM' : l.evModeShort,
                value: running ? rpm.toStringAsFixed(0) : '—',
                unit: '',
                color: running ? Colors.deepOrange : const Color(0xFF66BB6A),
                subtitle: running ? l.engineActiveShort : l.electricShort,
              )),
              const SizedBox(width: 4),
              Expanded(child: _bigCard(
                label: l.coolantIce,
                value: coolant > 0 ? fmtVal(coolant, decimals: 0) : '--',
                unit: '°C',
                color: _coolantColor(coolant),
              )),
            ])),
          ]),
        )),
      ]),
    );
  }

  double _power() {
    final v = _v('battery_voltage');
    final i = _v('battery_current');
    if (v > 0 && i.abs() > 0.01) return v * i / 1000.0;
    return _v('battery_power');
  }

  Widget _speedGauge(BuildContext context, double speed) {
    final l   = _l(context);
    final abs = speed.abs();
    final rev = speed < -0.5;
    return Stack(alignment: Alignment.center, children: [
      OBDNeedleGauge(
        title: rev ? l.reverseLabel : l.speedGaugeLabel,
        value: abs, minValue: 0, maxValue: 160, unit: 'km/h',
        tickValues: const [0, 20, 40, 60, 80, 100, 120, 140, 160],
      ),
      if (rev) Positioned(
        bottom: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.orange, borderRadius: BorderRadius.circular(4)),
          child: const Text('R', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ),
    ]);
  }

  /// ICE állapotpanel — jobb oldalon a sebességmérő mellé (portrait).
  Widget _iceStatusCard(BuildContext context, bool running, double rpm) {
    final l = _l(context);
    return DCard(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          running ? Icons.local_gas_station : Icons.electric_bolt,
          color: running ? Colors.deepOrange : const Color(0xFF66BB6A),
          size: 22,
        ),
        const SizedBox(height: 6),
        Text(
          running ? l.engineOnCard : l.evModeCard,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: running ? Colors.deepOrange : const Color(0xFF66BB6A),
            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5,
          ),
        ),
        if (running) ...[
          const SizedBox(height: 8),
          Text(
            rpm.toStringAsFixed(0),
            style: const TextStyle(color: Colors.white,
                fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const Text('RPM', style: TextStyle(
              color: Color(0xFF9E9E9E), fontSize: 11)),
        ] else ...[
          const SizedBox(height: 8),
          Text(l.engineOffMultiline, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
        ],
      ],
    ));
  }

  Widget _socBar(BuildContext context, double soc, double remKwh) {
    final l  = _l(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l.evChargeBarLabel, style: TextStyle(
            color: tt.bodySmall?.color ?? labelClr,
            fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
        Text(
          '${soc.toStringAsFixed(0)}%'
          '  ${remKwh > 0 ? remKwh.toStringAsFixed(1) : "--"} kWh',
          style: TextStyle(color: cs.onSurface, fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
      ]),
      const SizedBox(height: 5),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (soc / 100).clamp(0.0, 1.0), minHeight: 10,
          backgroundColor: AppTheme.trackColor(context),
          valueColor: AlwaysStoppedAnimation<Color>(
              soc > 20 ? const Color(0xFF4CAF50) :
              soc > 10 ? Colors.orange : Colors.red),
        ),
      ),
    ]));
  }

  Widget _evRangeBar(BuildContext context, double soc, double rangeKm, double maxRange) {
    final l   = _l(context);
    final cs  = Theme.of(context).colorScheme;
    final tt  = Theme.of(context).textTheme;
    final pct = maxRange > 0 ? (rangeKm / maxRange).clamp(0.0, 1.0) : 0.0;
    final color = soc > 20 ? const Color(0xFF26C6DA) :
                  soc > 10 ? Colors.orange : Colors.red;
    return DCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l.electricRangeBarLabel, style: TextStyle(
            color: tt.bodySmall?.color ?? labelClr,
            fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
        Text(
          rangeKm > 0 ? '~${rangeKm.toStringAsFixed(0)} km' : '--',
          style: TextStyle(color: cs.onSurface, fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
      ]),
      const SizedBox(height: 5),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct, minHeight: 10,
          backgroundColor: AppTheme.trackColor(context),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]));
  }

  Widget _fuelBar(BuildContext context, double fuel) {
    final l         = _l(context);
    final tt        = Theme.of(context).textTheme;
    final labelColor = tt.bodySmall?.color ?? labelClr;
    final fuelColor = fuel < 10 ? Colors.red :
                      fuel < 20 ? Colors.orange :
                      const Color(0xFF66BB6A);
    return DCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Icon(Icons.local_gas_station, size: 13, color: labelColor),
          const SizedBox(width: 5),
          Text(l.fuelIceBarLabel, style: TextStyle(color: labelColor,
              fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
        ]),
        Text(
          fuel > 0 ? '${fuel.toStringAsFixed(0)}%' : '--',
          style: TextStyle(color: fuelColor, fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
      ]),
      const SizedBox(height: 5),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (fuel / 100).clamp(0.0, 1.0), minHeight: 10,
          backgroundColor: AppTheme.trackColor(context),
          valueColor: AlwaysStoppedAnimation<Color>(fuelColor),
        ),
      ),
    ]));
  }

  Widget _bigCard({
    required String label, required String value,
    required String unit, required Color color, String subtitle = '',
  }) {
    return DCard(child: Builder(builder: (ctx) {
      final tt = Theme.of(ctx).textTheme;
      final labelColor = tt.bodySmall?.color ?? labelClr;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: labelColor,
            fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic, children: [
          Text(value, style: TextStyle(color: color, fontSize: 22,
              fontWeight: FontWeight.bold)),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(unit, style: TextStyle(color: labelColor, fontSize: 12)),
          ],
        ]),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: TextStyle(
              color: color.withValues(alpha: 0.7), fontSize: 10)),
      ]);
    }));
  }

  Color _battTempColor(double t) {
    if (t >= 45) return Colors.red;
    if (t >= 35) return Colors.orange;
    if (t <= 0)  return Colors.lightBlue;
    return const Color(0xFFFFA726);
  }

  Color _coolantColor(double v) {
    if (v <= 0)   return Colors.white;
    if (v >= 110) return Colors.red;
    if (v >= 100) return Colors.orange;
    if (v < 60)   return Colors.lightBlue;
    return Colors.white;
  }
}
