// ICE műszerfal — belső égésű motoros járművek OBD adatait megjelenítő nézet.
// Tartalom: RPM és sebességmérő, hőmérséklet/üzemanyag sávok, motor státusz és fedélzeti computer.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/locale_notifier.dart';
import 'dashboard_gauge.dart';
import 'dashboard_cards.dart';

/// Belső égésű motoros járműhöz tartozó műszerfal widget.
class IceDashboard extends StatelessWidget {
  final Map<String, String> data;

  const IceDashboard({super.key, required this.data});

  double _v(String pid) => parseObd(data[pid]);

  String _s(String pid) {
    final v = data[pid];
    return (v == null || v == '--') ? '--' : v;
  }

  AppLocalizations _l(BuildContext context) =>
      context.read<LocaleNotifier>().strings;

  @override
  Widget build(BuildContext context) {
    final l = _l(context);
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OBDNeedleGauge(
                    title: l.rpmGaugeLabel,
                    value: _v('010C'),
                    minValue: 0,
                    maxValue: 8000,
                    unit: 'rpm',
                    zones: const [
                      GaugeZone(
                          from: 0,
                          to: 6000,
                          color: Color(0xFF4A4A4A)),
                      GaugeZone(
                          from: 6000,
                          to: 7000,
                          color: Color(0xFFFFA726)),
                      GaugeZone(
                          from: 7000,
                          to: 8000,
                          color: Color(0xFFEF5350)),
                    ],
                    tickValues: const [
                      0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OBDNeedleGauge(
                    title: l.speedGaugeLabel,
                    value: _v('010D'),
                    minValue: 0,
                    maxValue: 240,
                    unit: 'km/h',
                    tickValues: const [
                      0, 30, 60, 90, 120, 150, 180, 210, 240
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: DashboardBarCard(
                    label: l.coolantLabel,
                    value: _v('0105'),
                    min: 60,
                    max: 120,
                    unit: '°C',
                    barColor: const Color(0xFFFFA726),
                    minLabel: '60',
                    maxLabel: '120°C',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: DashboardBarCard(
                    label: l.intakeAirLabel,
                    value: _v('010F'),
                    min: -40,
                    max: 80,
                    unit: '°C',
                    barColor: const Color(0xFF66BB6A),
                    minLabel: '-40',
                    maxLabel: '80°C',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: DashboardBarCard(
                    label: l.fuelLabel,
                    value: _v('012F'),
                    min: 0,
                    max: 100,
                    unit: '%',
                    barColor: const Color(0xFF42A5F5),
                    minLabel: 'E',
                    maxLabel: 'F',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: DashboardValueCard(
                    label: l.engineLoadLabel,
                    value: _s('0104'),
                    unit: '%',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: DashboardValueCard(
                    label: l.throttleLabel,
                    value: _s('0111'),
                    unit: '%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: DashboardValueCard(
                    label: l.aux12VShort,
                    value: _v('0142') > 0
                        ? fmtVal(_v('0142'), decimals: 1)
                        : '--',
                    unit: 'V',
                    accentColor: const Color(0xFFFDD835),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: DashboardBarCard(
                    label: l.boostPressureLabel,
                    value: _v('010B'),
                    min: 0,
                    max: 255,
                    unit: 'kPa',
                    barColor: const Color(0xFFAB47BC),
                    minLabel: '0',
                    maxLabel: '255',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            DashboardBarCard(
              label: l.airMassFlowLabel,
              value: _v('0110'),
              min: 0,
              max: 200,
              unit: 'g/s',
              barColor: const Color(0xFF7E57C2),
              minLabel: '0',
              maxLabel: '200 g/s',
            ),

            DashboardSectionTitle(l.obcLabel),
            DCard(
              child: Row(
                children: [
                  Expanded(child: TripItem(label: l.avgConsumptionLabel,     value: '--', unit: 'L/100km')),
                  Expanded(child: TripItem(label: l.instantConsumptionLabel, value: '--', unit: 'L/100km')),
                  Expanded(child: TripItem(label: l.distanceTravelledLabel,  value: '--', unit: 'km')),
                  Expanded(child: TripItem(label: l.rangeLabel,              value: '--', unit: 'km')),
                ],
              ),
            ),

            DashboardStatusBar(
              leftText: l.noDtcLabel,
              rightText: 'PID lekérdezés: --ms',
            ),
          ],
        ),
      ),
    );
  }
}
