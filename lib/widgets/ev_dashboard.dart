import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/locale_notifier.dart';
import '../theme/app_theme.dart';
import 'dashboard_gauge.dart';
import 'dashboard_cards.dart';

/// EV menetkijelző: sebesség, SOC, hatótáv, teljesítmény és cella-összesítő.
class EvDrivingDashboard extends StatelessWidget {
  final Map<String, String> data;
  final double? externalTemp;   // kültéri hőmérséklet °C, hőmérséklet-alapú módhoz
  final int rangeMode;          // 0=auto, 1=hőmérséklet, 2=manuális
  const EvDrivingDashboard({
    super.key,
    required this.data,
    this.externalTemp,
    this.rangeMode = 0,
  });

  double _v(String id) => parseObd(data[id]);

  AppLocalizations _l(BuildContext context) =>
      context.read<LocaleNotifier>().strings;

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

  Widget _buildPortrait(BuildContext context, {double bottomPad = 0}) {
    final l       = _l(context);
    final soc      = _v('soc_display') > 0 ? _v('soc_display') : _v('soc_bms');
    final socWorse = _socWorse();
    final speed    = _v('speed');
    final power    = _power();
    final current  = _v('battery_current');
    final voltage  = _v('battery_voltage');
    final tempMax  = _v('battery_temp_max');
    final aux      = _v('aux_battery_voltage');
    final remKwh   = _v('remaining_kwh');
    final rangeKm  = _v('range_km');
    final maxRange = _v('range_km_max') > 0 ? _v('range_km_max') : 165.0;
    final hasCells = _v('cell_volt_avg') > 0;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(10, 8, 10, 10 + bottomPad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          Row(children: [
            Expanded(child: OBDPowerGauge(
                value: power, minValue: -60, maxValue: 150)),
            const SizedBox(width: 8),
            Expanded(child: _speedGauge(context, speed)),
          ]),
          const SizedBox(height: 8),

          _socBar(context, soc, remKwh),
          const SizedBox(height: 6),

          _rangeBar(context, socWorse, rangeKm, maxRange, externalTemp, rangeMode),
          const SizedBox(height: 6),

          Row(children: [
            Expanded(child: _bigCard(
              label: l.powerLabel,
              value: power.abs() > 0.01 ? fmtVal(power, decimals: 1) : '0',
              unit: 'kW',
              color: power < -0.5 ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5),
            )),
            const SizedBox(width: 6),
            Expanded(child: _bigCard(
              label: l.speedLabel,
              value: speed.abs() < 0.5 ? '0' : fmtVal(speed.abs(), decimals: 0),
              unit: 'km/h',
              color: const Color(0xFFFFA726),
              subtitle: speed < -0.5 ? l.reverseLabel : '',
            )),
          ]),
          const SizedBox(height: 6),

          Row(children: [
            Expanded(child: _bigCard(
              label: l.voltageLabel,
              value: voltage > 0 ? fmtVal(voltage, decimals: 1) : '--',
              unit: 'V',
              color: const Color(0xFF42A5F5),
            )),
            const SizedBox(width: 6),
            Expanded(child: _bigCard(
              label: l.battTempShort,
              value: fmtVal(tempMax, decimals: 0),
              unit: '°C',
              color: _tempColor(tempMax),
            )),
          ]),
          const SizedBox(height: 6),

          Row(children: [
            Expanded(child: _bigCard(
              label: l.aux12VLabel,
              value: aux > 0 ? fmtVal(aux, decimals: 1) : '--',
              unit: 'V',
              color: aux > 0 && aux < 11.5 ? Colors.orange : const Color(0xFFFDD835),
            )),
            const SizedBox(width: 6),
            Expanded(child: _bigCard(
              label: l.currentLabel,
              value: current.abs() > 0.05 ? fmtVal(current, decimals: 1) : '0',
              unit: 'A',
              color: current < -0.5 ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5),
            )),
          ]),

          if (hasCells) ...[
            const SizedBox(height: 6),
            _cellCard(context),
          ],
        ]),
      ),
    );
  }

  Widget _buildLandscape(BuildContext context, {double bottomPad = 0}) {
    final l       = _l(context);
    final soc      = _v('soc_display') > 0 ? _v('soc_display') : _v('soc_bms');
    final socWorse = _socWorse();
    final speed    = _v('speed');
    final power    = _power();
    final voltage  = _v('battery_voltage');
    final current  = _v('battery_current');
    final tempMax  = _v('battery_temp_max');
    final aux      = _v('aux_battery_voltage');
    final remKwh   = _v('remaining_kwh');
    final rangeKm  = _v('range_km');
    final maxRange = _v('range_km_max') > 0 ? _v('range_km_max') : 165.0;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // Bal oldal: domináns sebességmérő.
        Expanded(flex: 5, child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(builder: (ctx, box) {
            final maxW = ((box.maxHeight - 80) * 1.2).clamp(80.0, box.maxWidth);
            return Center(
              child: SizedBox(width: maxW, child: _speedGauge(context, speed)),
            );
          }),
        )),

        // Jobb oldal: adatpanel
        Expanded(flex: 6, child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            _socBar(context, soc, remKwh),
            const SizedBox(height: 4),

            _rangeBar(context, socWorse, rangeKm, maxRange, externalTemp, rangeMode),
            const SizedBox(height: 4),

            // Teljesítmény kártya — kiemelten, teljes szélességben
            _bigCard(
              label: l.powerLabel,
              value: power.abs() > 0.01 ? fmtVal(power, decimals: 1) : '0',
              unit: 'kW',
              color: power < -0.5 ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5),
            ),
            const SizedBox(height: 4),

            // Alsó sor: feszültség, áram, hőmérséklet, 12V akku
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _bigCard(
                label: l.voltageLabel,
                value: voltage > 0 ? fmtVal(voltage, decimals: 1) : '--',
                unit: 'V', color: const Color(0xFF42A5F5),
              )),
              const SizedBox(width: 4),
              Expanded(child: _bigCard(
                label: l.currentLabel,
                value: current.abs() > 0.05 ? fmtVal(current, decimals: 1) : '0',
                unit: 'A',
                color: current < -0.5 ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5),
              )),
              const SizedBox(width: 4),
              Expanded(child: _bigCard(
                label: l.battTempShort,
                value: fmtVal(tempMax, decimals: 0),
                unit: '°C', color: _tempColor(tempMax),
              )),
              const SizedBox(width: 4),
              Expanded(child: _bigCard(
                label: l.aux12VLabel,
                value: aux > 0 ? fmtVal(aux, decimals: 1) : '--',
                unit: 'V',
                color: aux > 0 && aux < 11.5 ? Colors.orange : const Color(0xFFFDD835),
              )),
            ])),
          ]),
        )),
      ]),
    );
  }

  /// BMS és kijelző SOC közül a kisebbet adja vissza.
  double _socWorse() {
    final bms  = _v('soc_bms');
    final disp = _v('soc_display');
    if (bms > 0 && disp > 0) return bms < disp ? bms : disp;
    return bms > 0 ? bms : disp;
  }

  double _power() {
    final v = _v('battery_voltage');
    final i = _v('battery_current');
    if (v > 0 && i.abs() > 0.01) return v * i / 1000.0;
    return _v('battery_power');
  }

  Color _tempColor(double t) {
    if (t >= 40) return Colors.red;
    if (t >= 30) return Colors.orange;
    if (t <= 0)  return Colors.lightBlue;
    return const Color(0xFFFFA726);
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

  Widget _socBar(BuildContext context, double soc, double remKwh) {
    final l  = _l(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l.chargeBarTitle, style: TextStyle(color: tt.bodySmall?.color ?? labelClr,
            fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
        Text('${soc.toStringAsFixed(0)}%'
            '  ${remKwh > 0 ? remKwh.toStringAsFixed(1) : "--"} kWh',
            style: TextStyle(color: cs.onSurface, fontSize: 18,
                fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (soc / 100).clamp(0.0, 1.0), minHeight: 12,
          backgroundColor: AppTheme.trackColor(context),
          valueColor: AlwaysStoppedAnimation<Color>(
              soc > 20 ? const Color(0xFF4CAF50) :
              soc > 10 ? Colors.orange : Colors.red),
        ),
      ),
    ]));
  }

  Widget _rangeBar(BuildContext context, double soc, double rangeKm,
      double maxRange, [double? extTemp, int rMode = 0]) {
    final l          = _l(context);
    final cs         = Theme.of(context).colorScheme;
    final tt         = Theme.of(context).textTheme;
    final dimColor   = tt.labelSmall?.color ?? dimClr;
    final pct        = maxRange > 0 ? (rangeKm / maxRange).clamp(0.0, 1.0) : 0.0;
    final rangeColor = soc > 20 ? const Color(0xFF26C6DA) :
                       soc > 10 ? Colors.orange : Colors.red;
    return DCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l.rangeBarTitle, style: TextStyle(color: tt.bodySmall?.color ?? labelClr,
            fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
        Text(rangeKm > 0 ? '~${rangeKm.toStringAsFixed(0)} km' : '--',
            style: TextStyle(color: cs.onSurface, fontSize: 18,
                fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct, minHeight: 12,
          backgroundColor: AppTheme.trackColor(context),
          valueColor: AlwaysStoppedAnimation<Color>(rangeColor),
        ),
      ),
      const SizedBox(height: 3),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('0 km', style: TextStyle(color: dimColor, fontSize: 9)),
        if (rMode == 1 && extTemp != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.thermostat_outlined, size: 10, color: dimColor),
            Text(' ${l.tempBasedRange(extTemp.round())}',
                style: TextStyle(color: dimColor, fontSize: 9)),
          ])
        else
          const SizedBox.shrink(),
        Text('${maxRange.toStringAsFixed(0)} km',
            style: TextStyle(color: dimColor, fontSize: 9)),
      ]),
    ]));
  }

  Widget _cellCard(BuildContext context) {
    final l       = _l(context);
    final cs      = Theme.of(context).colorScheme;
    final tt      = Theme.of(context).textTheme;
    final minV    = _v('cell_volt_min');
    final maxV    = _v('cell_volt_max');
    final avg     = _v('cell_volt_avg');
    final spread  = _v('cell_volt_spread');
    final spreadColor = spread > 50 ? Colors.red :
                        spread > 20 ? Colors.orange :
                        const Color(0xFF66BB6A);
    return DCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.cellsTitle, style: TextStyle(color: tt.bodySmall?.color ?? labelClr,
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: _cellStat(context, 'Min', '${minV.toStringAsFixed(3)} V', Colors.lightBlue)),
        Expanded(child: _cellStat(context, 'Avg', '${avg.toStringAsFixed(3)} V', cs.onSurface)),
        Expanded(child: _cellStat(context, 'Max', '${maxV.toStringAsFixed(3)} V', Colors.orange)),
        Expanded(child: _cellStat(context, 'Δ', '${spread.toStringAsFixed(0)} mV', spreadColor)),
      ]),
    ]));
  }

  Widget _cellStat(BuildContext context, String label, String value, Color color) {
    final tt = Theme.of(context).textTheme;
    return Column(children: [
      Text(label, style: TextStyle(color: tt.bodySmall?.color ?? labelClr, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontSize: 13,
          fontWeight: FontWeight.bold)),
    ]);
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
          Text(value, style: TextStyle(color: color, fontSize: 26,
              fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(unit, style: TextStyle(color: labelColor, fontSize: 13)),
        ]),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
      ]);
    }));
  }

}

/// EV akkumulátor részletei: SOC, SOH, feszültség, hőmérsékletek, cellák és statisztikák.
class EvBatteryDashboard extends StatelessWidget {
  final Map<String, String> data;
  const EvBatteryDashboard({super.key, required this.data});

  double _v(String id) => parseObd(data[id]);
  String _s(String id) => data[id]?.isNotEmpty == true && data[id] != '--' ? data[id]! : '--';

  AppLocalizations _l(BuildContext context) =>
      context.read<LocaleNotifier>().strings;

  @override
  Widget build(BuildContext context) {
    final l       = _l(context);
    final soc      = _v('soc_display') > 0 ? _v('soc_display') : _v('soc_bms');
    final socBms   = _v('soc_bms');
    final soh      = _v('soh');
    final hasCells = _v('cell_volt_avg') > 0;
    final spread   = _v('cell_volt_spread');

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          Row(children: [
            Expanded(child: DashboardBarCard(
              label: l.socDisplayLabel, value: soc,
              min: 0, max: 100, unit: '%',
              barColor: soc > 20 ? const Color(0xFF4CAF50) : Colors.orange,
              minLabel: '0%', maxLabel: '100%',
            )),
            const SizedBox(width: 6),
            Expanded(child: DashboardBarCard(
              label: l.socBmsLabel, value: socBms,
              min: 0, max: 100, unit: '%',
              barColor: socBms > 20 ? const Color(0xFF81C784) : Colors.orange,
              minLabel: '0%', maxLabel: '100%',
            )),
          ]),
          const SizedBox(height: 6),

          DashboardBarCard(
            label: l.sohLabel, value: soh, min: 70, max: 100, unit: '%',
            barColor: soh > 90 ? const Color(0xFF66BB6A) :
                      soh > 80 ? Colors.orange : Colors.red,
            minLabel: '70%', maxLabel: '100%',
          ),
          const SizedBox(height: 6),

          Row(children: [
            Expanded(child: DashboardBarCard(
              label: l.hvVoltage, value: _v('battery_voltage'),
              min: 280, max: 420, unit: 'V',
              barColor: const Color(0xFF42A5F5),
              minLabel: '280V', maxLabel: '420V',
            )),
            const SizedBox(width: 6),
            Expanded(child: DashboardBarCard(
              label: l.aux12VLabel, value: _v('aux_battery_voltage'),
              min: 10, max: 16, unit: 'V',
              barColor: const Color(0xFFFDD835),
              minLabel: '10V', maxLabel: '16V',
            )),
          ]),
          const SizedBox(height: 6),

          Row(children: [
            Expanded(child: DashboardBarCard(
              label: l.batteryMaxTempLabel, value: _v('battery_temp_max'),
              min: -20, max: 55, unit: '°C',
              barColor: const Color(0xFFFFA726),
              minLabel: '-20°C', maxLabel: '55°C',
            )),
            const SizedBox(width: 6),
            Expanded(child: DashboardBarCard(
              label: l.batteryMinTempLabel, value: _v('battery_temp_min'),
              min: -20, max: 55, unit: '°C',
              barColor: const Color(0xFFEF5350),
              minLabel: '-20°C', maxLabel: '55°C',
            )),
          ]),
          const SizedBox(height: 6),

          if (hasCells) ...[
            DashboardSectionTitle(l.cellsTitle),
            DCard(child: Column(children: [
              Row(children: [
                Expanded(child: DashboardValueCard(
                  label: l.minCellLabel, unit: 'V',
                  value: _v('cell_volt_min').toStringAsFixed(3),
                  accentColor: Colors.lightBlue,
                )),
                const SizedBox(width: 6),
                Expanded(child: DashboardValueCard(
                  label: l.maxCellLabel, unit: 'V',
                  value: _v('cell_volt_max').toStringAsFixed(3),
                  accentColor: Colors.orange,
                )),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Builder(builder: (ctx) => DashboardValueCard(
                  label: l.avgCellLabel, unit: 'V',
                  value: _v('cell_volt_avg').toStringAsFixed(3),
                  accentColor: Theme.of(ctx).colorScheme.onSurface,
                ))),
                const SizedBox(width: 6),
                Expanded(child: DashboardValueCard(
                  label: l.cellDiffLabel, unit: 'mV',
                  value: _v('cell_volt_spread').toStringAsFixed(0),
                  accentColor: spread > 50 ? Colors.red :
                               spread > 20 ? Colors.orange :
                               const Color(0xFF66BB6A),
                )),
              ]),
            ])),
            const SizedBox(height: 6),
          ],

          DashboardSectionTitle(l.lifeStatsTitle),
          DCard(child: Row(children: [
            Expanded(child: TripItem(label: l.chargedKwhLabel,    value: _s('cec'),     unit: 'kWh')),
            Expanded(child: TripItem(label: l.dischargedKwhLabel, value: _s('ced'),     unit: 'kWh')),
            Expanded(child: TripItem(label: l.operatingHoursLabel, value: _s('op_time'), unit: 'h')),
          ])),

          DashboardStatusBar(
            leftText: l.batteryDetailsLabel,
            rightText: 'Mode 21 | BMS',
          ),
        ]),
      ),
    );
  }
}

/// Régi nevű belépési pont, amely az EvDrivingDashboard-ra delegál.
class EvDashboard extends StatelessWidget {
  final Map<String, String> data;
  const EvDashboard({super.key, required this.data});
  @override
  Widget build(BuildContext context) => EvDrivingDashboard(data: data);
}
