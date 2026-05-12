// lib/widgets/ev_dashboard.dart
//
// EV műszerfal nézetek — reszponzív layout (portrait / landscape).
// Adatok: Map<String, String> data (field ID → megjelenítési string).

import 'package:flutter/material.dart';
import 'dashboard_gauge.dart';
import 'dashboard_cards.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 1. VEZETÉS Dashboard
// ═══════════════════════════════════════════════════════════════════════════

class EvDrivingDashboard extends StatelessWidget {
  final Map<String, String> data;
  const EvDrivingDashboard({Key? key, required this.data}) : super(key: key);

  double _v(String id) => parseObd(data[id]);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      final landscape = box.maxWidth > box.maxHeight;
      return landscape ? _buildLandscape() : _buildPortrait();
    });
  }

  // ── Portrait ────────────────────────────────────────────────────────────

  Widget _buildPortrait() {
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
      color: const Color(0xFF121212),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Gauges ────────────────────────────────────────────────────
          SizedBox(height: 190, child: Row(children: [
            Expanded(child: OBDPowerGauge(
                value: power, minValue: -60, maxValue: 150)),
            const SizedBox(width: 8),
            Expanded(child: _speedGauge(speed)),
          ])),
          const SizedBox(height: 8),

          // ── SOC sáv ───────────────────────────────────────────────────
          _socBar(soc, remKwh),
          const SizedBox(height: 6),

          // ── Hatótáv sáv ───────────────────────────────────────────────
          _rangeBar(socWorse, rangeKm, maxRange),
          const SizedBox(height: 6),

          // ── Teljesítmény + Sebesség ───────────────────────────────────
          Row(children: [
            Expanded(child: _bigCard(
              label: 'Teljesítmény',
              value: power.abs() > 0.01 ? fmtVal(power, decimals: 1) : '0',
              unit: 'kW',
              color: power < -0.5 ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5),
              subtitle: power < -0.5 ? 'Rekuperáció' : power > 1 ? 'Motor' : '',
            )),
            const SizedBox(width: 6),
            Expanded(child: _bigCard(
              label: 'Sebesség',
              value: speed.abs() < 0.5 ? '0' : fmtVal(speed.abs(), decimals: 0),
              unit: 'km/h',
              color: const Color(0xFFFFA726),
              subtitle: speed < -0.5 ? 'TOLATÁS' : '',
            )),
          ]),
          const SizedBox(height: 6),

          // ── Feszültség + Akku hőm. ────────────────────────────────────
          Row(children: [
            Expanded(child: _bigCard(
              label: 'Feszültség',
              value: voltage > 0 ? fmtVal(voltage, decimals: 1) : '--',
              unit: 'V',
              color: const Color(0xFF42A5F5),
            )),
            const SizedBox(width: 6),
            Expanded(child: _bigCard(
              label: 'Akku hőm.',
              value: fmtVal(tempMax, decimals: 0),
              unit: '°C',
              color: _tempColor(tempMax),
            )),
          ]),
          const SizedBox(height: 6),

          // ── 12V + Áram ────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _bigCard(
              label: '12V akku',
              value: aux > 0 ? fmtVal(aux, decimals: 1) : '--',
              unit: 'V',
              color: aux > 0 && aux < 11.5 ? Colors.orange : const Color(0xFFFDD835),
            )),
            const SizedBox(width: 6),
            Expanded(child: _bigCard(
              label: 'Áram',
              value: current.abs() > 0.05 ? fmtVal(current, decimals: 1) : '0',
              unit: 'A',
              color: current < -0.5 ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5),
            )),
          ]),

          // ── Cella adatok ──────────────────────────────────────────────
          if (hasCells) ...[
            const SizedBox(height: 6),
            _cellCard(),
          ],
        ]),
      ),
    );
  }

  // ── Landscape ───────────────────────────────────────────────────────────

  Widget _buildLandscape() {
    final soc      = _v('soc_display') > 0 ? _v('soc_display') : _v('soc_bms');
    final socWorse = _socWorse();
    final speed    = _v('speed');
    final power    = _power();
    final voltage  = _v('battery_voltage');
    final tempMax  = _v('battery_temp_max');
    final aux      = _v('aux_battery_voltage');
    final remKwh   = _v('remaining_kwh');
    final rangeKm  = _v('range_km');
    final maxRange = _v('range_km_max') > 0 ? _v('range_km_max') : 165.0;
    final hasCells = _v('cell_volt_avg') > 0;

    return Container(
      color: const Color(0xFF121212),
      child: Row(children: [
        // Bal: gauges
        Expanded(flex: 5, child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            Expanded(child: OBDPowerGauge(
                value: power, minValue: -60, maxValue: 150)),
            const SizedBox(height: 6),
            Expanded(child: _speedGauge(speed)),
          ]),
        )),

        // Jobb: kártyák
        Expanded(flex: 6, child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _socBar(soc, remKwh),
            const SizedBox(height: 5),
            _rangeBar(socWorse, rangeKm, maxRange),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _bigCard(
                label: 'Teljesítmény',
                value: power.abs() > 0.01 ? fmtVal(power, decimals: 1) : '0',
                unit: 'kW',
                color: power < -0.5 ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5),
              )),
              const SizedBox(width: 5),
              Expanded(child: _bigCard(
                label: 'Feszültség', value: voltage > 0 ? fmtVal(voltage, decimals: 1) : '--',
                unit: 'V', color: const Color(0xFF42A5F5),
              )),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _bigCard(
                label: 'Akku hőm.', value: fmtVal(tempMax, decimals: 0),
                unit: '°C', color: _tempColor(tempMax),
              )),
              const SizedBox(width: 5),
              Expanded(child: _bigCard(
                label: '12V akku', value: aux > 0 ? fmtVal(aux, decimals: 1) : '--',
                unit: 'V', color: aux > 0 && aux < 11.5 ? Colors.orange : const Color(0xFFFDD835),
              )),
            ]),
            if (hasCells) ...[const SizedBox(height: 5), _cellCard()],
          ]),
        )),
      ]),
    );
  }

  // ── Segédwidgetek ────────────────────────────────────────────────────────

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

  Widget _speedGauge(double speed) {
    final abs = speed.abs();
    final rev = speed < -0.5;
    return Stack(alignment: Alignment.center, children: [
      OBDNeedleGauge(
        title: rev ? 'TOLATÁS' : 'SEBESSÉG',
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

  Widget _socBar(double soc, double remKwh) {
    return DCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('TÖLTÖTTSÉG', style: TextStyle(color: labelClr,
            fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
        Text('${soc.toStringAsFixed(0)}%'
            '  ${remKwh > 0 ? remKwh.toStringAsFixed(1) : "--"} kWh',
            style: const TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (soc / 100).clamp(0.0, 1.0), minHeight: 12,
          backgroundColor: trackClr,
          valueColor: AlwaysStoppedAnimation<Color>(
              soc > 20 ? const Color(0xFF4CAF50) :
              soc > 10 ? Colors.orange : Colors.red),
        ),
      ),
    ]));
  }

  Widget _rangeBar(double soc, double rangeKm, double maxRange) {
    final pct = maxRange > 0 ? (rangeKm / maxRange).clamp(0.0, 1.0) : 0.0;
    final rangeColor = soc > 20 ? const Color(0xFF26C6DA) :
                       soc > 10 ? Colors.orange : Colors.red;
    return DCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('HATÓTÁV (becslés)', style: TextStyle(color: labelClr,
            fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
        Text(rangeKm > 0 ? '~${rangeKm.toStringAsFixed(0)} km' : '--',
            style: const TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct, minHeight: 12,
          backgroundColor: trackClr,
          valueColor: AlwaysStoppedAnimation<Color>(rangeColor),
        ),
      ),
      const SizedBox(height: 3),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('0 km', style: TextStyle(color: dimClr, fontSize: 9)),
        Text('${maxRange.toStringAsFixed(0)} km',
            style: const TextStyle(color: dimClr, fontSize: 9)),
      ]),
    ]));
  }

  Widget _cellCard() {
    final minV   = _v('cell_volt_min');
    final maxV   = _v('cell_volt_max');
    final avg    = _v('cell_volt_avg');
    final spread = _v('cell_volt_spread');
    final spreadColor = spread > 50 ? Colors.red :
                        spread > 20 ? Colors.orange :
                        const Color(0xFF66BB6A);
    return DCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('CELLÁK', style: TextStyle(color: labelClr,
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: _cellStat('Min', '${minV.toStringAsFixed(3)} V', Colors.lightBlue)),
        Expanded(child: _cellStat('Átl', '${avg.toStringAsFixed(3)} V', Colors.white)),
        Expanded(child: _cellStat('Max', '${maxV.toStringAsFixed(3)} V', Colors.orange)),
        Expanded(child: _cellStat('Δ', '${spread.toStringAsFixed(0)} mV', spreadColor)),
      ]),
    ]));
  }

  Widget _cellStat(String label, String value, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(color: labelClr, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontSize: 13,
          fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _bigCard({
    required String label, required String value,
    required String unit, required Color color, String subtitle = '',
  }) {
    return DCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: labelClr,
          fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic, children: [
        Text(value, style: TextStyle(color: color, fontSize: 26,
            fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(unit, style: const TextStyle(color: labelClr, fontSize: 13)),
      ]),
      if (subtitle.isNotEmpty)
        Text(subtitle, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
    ]));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. AKKUMULÁTOR Dashboard
// ═══════════════════════════════════════════════════════════════════════════

class EvBatteryDashboard extends StatelessWidget {
  final Map<String, String> data;
  const EvBatteryDashboard({Key? key, required this.data}) : super(key: key);

  double _v(String id) => parseObd(data[id]);
  String _s(String id) => data[id]?.isNotEmpty == true && data[id] != '--' ? data[id]! : '--';

  @override
  Widget build(BuildContext context) {
    final soc      = _v('soc_display') > 0 ? _v('soc_display') : _v('soc_bms');
    final socBms   = _v('soc_bms');
    final soh      = _v('soh');
    final hasCells = _v('cell_volt_avg') > 0;
    final spread   = _v('cell_volt_spread');

    return Container(
      color: const Color(0xFF121212),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── SOC + SOH ──────────────────────────────────────────────────
          Row(children: [
            Expanded(child: DashboardBarCard(
              label: 'Töltöttség (kijelző)', value: soc,
              min: 0, max: 100, unit: '%',
              barColor: soc > 20 ? const Color(0xFF4CAF50) : Colors.orange,
              minLabel: '0%', maxLabel: '100%',
            )),
            const SizedBox(width: 6),
            Expanded(child: DashboardBarCard(
              label: 'Töltöttség (BMS)', value: socBms,
              min: 0, max: 100, unit: '%',
              barColor: socBms > 20 ? const Color(0xFF81C784) : Colors.orange,
              minLabel: '0%', maxLabel: '100%',
            )),
          ]),
          const SizedBox(height: 6),

          DashboardBarCard(
            label: 'Állapot (SOH)', value: soh, min: 70, max: 100, unit: '%',
            barColor: soh > 90 ? const Color(0xFF66BB6A) :
                      soh > 80 ? Colors.orange : Colors.red,
            minLabel: '70%', maxLabel: '100%',
          ),
          const SizedBox(height: 6),

          // ── Feszültség ─────────────────────────────────────────────────
          Row(children: [
            Expanded(child: DashboardBarCard(
              label: 'HV feszültség', value: _v('battery_voltage'),
              min: 280, max: 420, unit: 'V',
              barColor: const Color(0xFF42A5F5),
              minLabel: '280V', maxLabel: '420V',
            )),
            const SizedBox(width: 6),
            Expanded(child: DashboardBarCard(
              label: '12V akku', value: _v('aux_battery_voltage'),
              min: 10, max: 16, unit: 'V',
              barColor: const Color(0xFFFDD835),
              minLabel: '10V', maxLabel: '16V',
            )),
          ]),
          const SizedBox(height: 6),

          // ── Hőmérsékletek ──────────────────────────────────────────────
          Row(children: [
            Expanded(child: DashboardBarCard(
              label: 'Akku max hőm.', value: _v('battery_temp_max'),
              min: -20, max: 55, unit: '°C',
              barColor: const Color(0xFFFFA726),
              minLabel: '-20°C', maxLabel: '55°C',
            )),
            const SizedBox(width: 6),
            Expanded(child: DashboardBarCard(
              label: 'Akku min hőm.', value: _v('battery_temp_min'),
              min: -20, max: 55, unit: '°C',
              barColor: const Color(0xFFEF5350),
              minLabel: '-20°C', maxLabel: '55°C',
            )),
          ]),
          const SizedBox(height: 6),

          // ── Cellák ─────────────────────────────────────────────────────
          if (hasCells) ...[
            const DashboardSectionTitle('CELLA ADATOK'),
            DCard(child: Column(children: [
              Row(children: [
                Expanded(child: DashboardValueCard(
                  label: 'Min cella', unit: 'V',
                  value: _v('cell_volt_min').toStringAsFixed(3),
                  accentColor: Colors.lightBlue,
                )),
                const SizedBox(width: 6),
                Expanded(child: DashboardValueCard(
                  label: 'Max cella', unit: 'V',
                  value: _v('cell_volt_max').toStringAsFixed(3),
                  accentColor: Colors.orange,
                )),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: DashboardValueCard(
                  label: 'Átlag cella', unit: 'V',
                  value: _v('cell_volt_avg').toStringAsFixed(3),
                  accentColor: Colors.white,
                )),
                const SizedBox(width: 6),
                Expanded(child: DashboardValueCard(
                  label: 'Különbség (Δ)', unit: 'mV',
                  value: _v('cell_volt_spread').toStringAsFixed(0),
                  accentColor: spread > 50 ? Colors.red :
                               spread > 20 ? Colors.orange :
                               const Color(0xFF66BB6A),
                )),
              ]),
            ])),
            const SizedBox(height: 6),
          ],

          // ── Statisztika ────────────────────────────────────────────────
          const DashboardSectionTitle('ÉLETTARTAM STATISZTIKA'),
          DCard(child: Row(children: [
            Expanded(child: TripItem(label: 'Töltve',   value: _s('cec'),     unit: 'kWh')),
            Expanded(child: TripItem(label: 'Merítve',  value: _s('ced'),     unit: 'kWh')),
            Expanded(child: TripItem(label: 'Üzemóra', value: _s('op_time'), unit: 'h')),
          ])),

          const DashboardStatusBar(
            leftText: 'Akkumulátor részletek',
            rightText: 'Mode 21 | BMS',
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Visszafelé kompatibilitás
// ═══════════════════════════════════════════════════════════════════════════

class EvDashboard extends StatelessWidget {
  final Map<String, String> data;
  const EvDashboard({Key? key, required this.data}) : super(key: key);
  @override
  Widget build(BuildContext context) => EvDrivingDashboard(data: data);
}
