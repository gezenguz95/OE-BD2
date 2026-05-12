// lib/widgets/charging_monitor_view.dart
//
// Töltési monitor nézet – automatikusan megjelenik, ha töltési áram detektálható.
// Mutatja: töltési teljesítmény, SOC progress, hozzáadott kWh,
//          idő-100%-ig becslés, hőmérséklet, feszültség/áram.

import 'package:flutter/material.dart';

class ChargingMonitorView extends StatelessWidget {
  /// Ugyanaz a _currentValues map, amit az OBD polling frissít.
  final Map<String, String> data;

  /// Mennyit töltöttünk ebben a session-ben (kWh) – obd_data_page számolja.
  final double chargedKwh;

  /// Mikor kezdődött a töltés.
  final DateTime? chargeStartTime;

  const ChargingMonitorView({
    Key? key,
    required this.data,
    required this.chargedKwh,
    this.chargeStartTime,
  }) : super(key: key);

  double _d(String key) {
    final s = data[key];
    if (s == null || s == '--') return 0;
    return double.tryParse(s) ?? 0;
  }

  String _s(String key, [String fallback = '--']) {
    final v = data[key];
    return (v == null || v == '--') ? fallback : v;
  }

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '<1m';
  }

  @override
  Widget build(BuildContext context) {
    final soc      = _d('soc_display');
    final socBms   = _d('soc_bms');
    final voltage  = _d('battery_voltage');
    final current  = _d('battery_current'); // negatív = tölt
    final tempMax  = _d('battery_temp_max');
    final tempMin  = _d('battery_temp_min');
    final auxBatt  = _d('aux_battery_voltage');

    // Töltési teljesítmény (W → kW)
    final chargePower = voltage > 0 && current < 0
        ? (voltage * current.abs() / 1000.0)
        : 0.0;

    // SOC-alapú hatékonyság: kb 28 kWh kapacitás, 95% hatásfok
    final remainingKwh = _d('remaining_kwh');
    final capacity = remainingKwh > 0 && soc > 0
        ? (remainingKwh / soc * 100)
        : 28.0;
    final toFullKwh = capacity - remainingKwh;

    // Idő 100%-ig becslés
    String timeToFull = '--';
    if (chargePower > 0.5 && toFullKwh > 0) {
      final hours = toFullKwh / chargePower;
      timeToFull = _fmtDuration(Duration(minutes: (hours * 60).round()));
    }

    // Eltelt töltési idő
    final elapsed = chargeStartTime != null
        ? DateTime.now().difference(chargeStartTime!)
        : Duration.zero;

    final green = Colors.green.shade400;
    final teal  = Colors.teal.shade300;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Fejléc ────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.electric_bolt, color: green, size: 22),
              const SizedBox(width: 8),
              Text(
                'Töltés folyamatban',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: green,
                ),
              ),
              const Spacer(),
              if (chargeStartTime != null)
                Text(
                  'Eltelt: ${_fmtDuration(elapsed)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── SOC sáv ───────────────────────────────────────────────────
          _SocBar(soc: soc, socBms: socBms, color: green),
          const SizedBox(height: 20),

          // ── Fő kártyák 2×2 ───────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _BigCard(
                icon: Icons.flash_on,
                label: 'Töltési teljesítmény',
                value: chargePower > 0
                    ? chargePower.toStringAsFixed(1)
                    : '--',
                unit: 'kW',
                color: green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BigCard(
                icon: Icons.battery_charging_full,
                label: 'Hozzáadott energia',
                value: chargedKwh.toStringAsFixed(2),
                unit: 'kWh',
                color: teal,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _BigCard(
                icon: Icons.schedule,
                label: 'Idő 100%-ig',
                value: timeToFull,
                unit: '',
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BigCard(
                icon: Icons.speed,
                label: 'Töltési sebesség',
                value: chargePower > 0 && capacity > 0
                    ? (chargePower / capacity * 100).toStringAsFixed(1)
                    : '--',
                unit: '% / h',
                color: Colors.orange.shade300,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // ── Szenzor sor ───────────────────────────────────────────────
          const Text('Töltési részletek',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          _DetailRow(label: 'Feszültség',         value: '${_s('battery_voltage')} V'),
          _DetailRow(label: 'Áram',               value: '${_s('battery_current')} A'),
          _DetailRow(label: 'Akku max hőm.',      value: '${tempMax > 0 ? tempMax.toStringAsFixed(1) : '--'} °C'),
          _DetailRow(label: 'Akku min hőm.',      value: '${tempMin > 0 ? tempMin.toStringAsFixed(1) : '--'} °C'),
          if (auxBatt > 0)
            _DetailRow(label: '12V akku',         value: '${auxBatt.toStringAsFixed(1)} V'),
          if (remainingKwh > 0)
            _DetailRow(label: 'Maradék energia',  value: '${remainingKwh.toStringAsFixed(1)} kWh'),
          if (toFullKwh > 0)
            _DetailRow(label: '100%-ig szükséges', value: '${toFullKwh.toStringAsFixed(1)} kWh'),

          // ── Hőmérséklet státusz ──────────────────────────────────────
          if (tempMax > 35)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: tempMax > 40
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
                  border: Border.all(
                    color: tempMax > 40 ? Colors.red : Colors.orange,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: tempMax > 40 ? Colors.red : Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tempMax > 40
                            ? 'Magas akkumulátor hőmérséklet: ${tempMax.toStringAsFixed(0)}°C'
                            : 'Megemelkedett hőmérséklet: ${tempMax.toStringAsFixed(0)}°C',
                        style: TextStyle(
                          color: tempMax > 40 ? Colors.red : Colors.orange,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SOC PROGRESS SÁV
// ═══════════════════════════════════════════════════════════════════════════

class _SocBar extends StatelessWidget {
  final double soc;
  final double socBms;
  final Color color;

  const _SocBar({
    required this.soc,
    required this.socBms,
    required this.color,
  });

  Color _socColor(double v) {
    if (v >= 80) return Colors.green.shade500;
    if (v >= 50) return Colors.teal.shade400;
    if (v >= 20) return Colors.orange.shade400;
    return Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final pct = (soc / 100).clamp(0.0, 1.0);
    final barColor = _socColor(soc);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Töltöttség (SOC)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(
              '${soc > 0 ? soc.toStringAsFixed(1) : '--'}%',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 20,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        if (socBms > 0 && (socBms - soc).abs() > 0.5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'BMS: ${socBms.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BIG CARD
// ═══════════════════════════════════════════════════════════════════════════

class _BigCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _BigCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DETAIL ROW
// ═══════════════════════════════════════════════════════════════════════════

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
