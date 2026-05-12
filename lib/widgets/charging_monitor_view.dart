// Töltési monitor nézet — töltési áram detektálásakor automatikusan megjelenik.
// Adatok: töltési teljesítmény, SOC sáv, session-ben hozzáadott energia,
//         100%-ig becsült idő, hőmérséklet, feszültség/áram részletek,
//         és SOC-alapú töltési görbe (kW és hőmérséklet nézettel).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/charge_data.dart';
import '../services/locale_notifier.dart';
import 'charge_chart_view.dart';

/// EV töltési folyamatot megjelenítő widget — a töltési session adatait mutatja.
class ChargingMonitorView extends StatefulWidget {
  /// Az OBD polling által folyamatosan frissített szenzorértékek.
  final Map<String, String> data;

  /// A session során hozzáadott energia kWh-ban; az obd_data_page számolja.
  final double chargedKwh;

  /// A töltés kezdetének időpontja, az eltelt idő megjelenítéséhez.
  final DateTime? chargeStartTime;

  /// Az aktuális session töltési görbéjének adatpontjai (SOC, kW, °C).
  /// Üres lista = töltési adatok még gyűjtés alatt.
  final List<ChargeDataPoint> chargePoints;

  /// A jármű névleges akkumulátor kapacitása (kWh) — fallback, ha a
  /// SOC-alapú számítás nem működik (alacsony SOC, hiányzó remaining_kwh).
  /// 0 vagy negatív → 28 kWh-ra esik vissza (régi BEV alapérték).
  final double nominalCapacityKwh;

  const ChargingMonitorView({
    super.key,
    required this.data,
    required this.chargedKwh,
    this.chargeStartTime,
    this.chargePoints = const [],
    this.nominalCapacityKwh = 0,
  });

  @override
  State<ChargingMonitorView> createState() => _ChargingMonitorViewState();
}

class _ChargingMonitorViewState extends State<ChargingMonitorView> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 30 másodpercenként kényszerítjük az újraépítést az "Eltelt idő" mező
    // frissítéséhez — a szülő setState-jére nem hagyatkozhatunk.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  double _d(String key) {
    final s = widget.data[key];
    if (s == null || s == '--') return 0;
    return double.tryParse(s) ?? 0;
  }

  String _s(String key, [String fallback = '--']) {
    final v = widget.data[key];
    return (v == null || v == '--') ? fallback : v;
  }

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '<1m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n    = context.read<LocaleNotifier>().strings;
    final soc      = _d('soc_display');
    final socBms   = _d('soc_bms');
    final voltage  = _d('battery_voltage');
    final current  = _d('battery_current'); // negatív érték = töltési állapot
    final tempMax  = _d('battery_temp_max');
    final tempMin  = _d('battery_temp_min');
    final auxBatt  = _d('aux_battery_voltage');

    // Töltési teljesítmény: feszültség × |áram| / 1000, ha mindkettő érvényes.
    final chargePower = voltage > 0 && current < 0
        ? (voltage * current.abs() / 1000.0)
        : 0.0;

    // SOC-alapú kapacitásbecslés: SOC < 5% körül a remaining_kwh/SOC arány
    // zajos (cellabalancing, feszültség-offset) → fallback a járműprofil
    // névleges akku-kapacitására (Kuga PHEV: ~14.4 kWh, Ioniq EV: ~28 kWh).
    final remainingKwh = _d('remaining_kwh');
    final fallbackCap = widget.nominalCapacityKwh > 0
        ? widget.nominalCapacityKwh
        : 28.0;
    final capacity = (remainingKwh > 0 && soc > 5)
        ? (remainingKwh / soc * 100)
        : fallbackCap;
    final toFullKwh = capacity - remainingKwh;

    // 100%-ig szükséges idő becslése a jelenlegi töltési teljesítmény alapján.
    String timeToFull = '--';
    if (chargePower > 0.5 && toFullKwh > 0) {
      final hours = toFullKwh / chargePower;
      timeToFull = _fmtDuration(Duration(minutes: (hours * 60).round()));
    }

    // Eltelt idő; a Timer.periodic 30 másodpercenként gondoskodik a frissítésről.
    final elapsed = widget.chargeStartTime != null
        ? DateTime.now().difference(widget.chargeStartTime!)
        : Duration.zero;

    final green = Colors.green.shade400;
    final teal  = Colors.teal.shade300;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.electric_bolt, color: green, size: 22),
              const SizedBox(width: 8),
              Text(
                l10n.chargingInProgress,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: green,
                ),
              ),
              const Spacer(),
              if (widget.chargeStartTime != null)
                Text(
                  '${l10n.elapsedPrefix}: ${_fmtDuration(elapsed)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
            ],
          ),
          const SizedBox(height: 16),

          _SocBar(soc: soc, socBms: socBms, color: green, label: l10n.socBarTitle),
          const SizedBox(height: 20),

          Row(children: [
            Expanded(
              child: _BigCard(
                icon: Icons.flash_on,
                label: l10n.chargingPowerLabel,
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
                label: l10n.energyAddedLabel,
                value: widget.chargedKwh.toStringAsFixed(2),
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
                label: l10n.timeToFullLabel,
                value: timeToFull,
                unit: '',
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BigCard(
                icon: Icons.speed,
                label: l10n.chargingSpeedLabel,
                value: chargePower > 0 && capacity > 0
                    ? (chargePower / capacity * 100).toStringAsFixed(1)
                    : '--',
                unit: '% / h',
                color: Colors.orange.shade300,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          Text(l10n.chargingDetailsLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          _DetailRow(label: l10n.voltageLabel,        value: '${_s('battery_voltage')} V'),
          _DetailRow(label: l10n.currentLabel,        value: '${_s('battery_current')} A'),
          // A -50 sentinel értéknél nincs érvényes szenzor adat (téli állás esetén
          // is lehet 0°C alatti az akkumulátor, ezért nem elég a <= 0 ellenőrzés).
          _DetailRow(label: l10n.batteryMaxTempLabel, value: '${tempMax > -50 ? tempMax.toStringAsFixed(1) : '--'} °C'),
          _DetailRow(label: l10n.batteryMinTempLabel, value: '${tempMin > -50 ? tempMin.toStringAsFixed(1) : '--'} °C'),
          if (auxBatt > 0)
            _DetailRow(label: l10n.aux12VLabel,       value: '${auxBatt.toStringAsFixed(1)} V'),
          if (remainingKwh > 0)
            _DetailRow(label: l10n.remainingEnergyLabel, value: '${remainingKwh.toStringAsFixed(1)} kWh'),
          if (toFullKwh > 0)
            _DetailRow(label: l10n.energyNeededToFullLabel, value: '${toFullKwh.toStringAsFixed(1)} kWh'),

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
                            ? l10n.highBattTempWarning(tempMax)
                            : l10n.elevatedTempWarning(tempMax),
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

          // Elválasztó vonal a részletek és a diagram között
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          // A ChargeChartView a kapott pontokból rajzolja a SOC–kW és
          // SOC–°C görbéket. Ha még nincs elég adat, helyőrző szöveget mutat.
          ChargeChartView(points: widget.chargePoints),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Töltöttségi sáv százalékos értékkel és opcionális BMS eltérés jelzéssel.
class _SocBar extends StatelessWidget {
  final double soc;
  final double socBms;
  final Color color;
  final String label;

  const _SocBar({
    required this.soc,
    required this.socBms,
    required this.color,
    required this.label,
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
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

/// Kiemelt értékkártya ikonnal, felirattal és mértékegységgel — a fő töltési mutatókhoz.
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

/// Egyszerű felirat–érték pár a töltési részletek listájához.
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
