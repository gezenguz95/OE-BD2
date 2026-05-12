// lib/widgets/ice_dashboard.dart
//
// ICE (Belső égésű motor) műszerfal layout.
// Álló, görgethető nézet műszerekkel, kártyákkal és fedélzeti computerrel.

import 'package:flutter/material.dart';
import 'dashboard_gauge.dart';
import 'dashboard_cards.dart';

class IceDashboard extends StatelessWidget {
  final Map<String, String> data;

  const IceDashboard({Key? key, required this.data}) : super(key: key);

  double _v(String pid) => parseObd(data[pid]);

  String _s(String pid) {
    final v = data[pid];
    return (v == null || v == '--') ? '--' : v;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Műszerek: RPM + Sebesség ────────────────
            Row(
              children: [
                Expanded(
                  child: OBDNeedleGauge(
                    title: 'FORDULATSZÁM',
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
                    title: 'SEBESSÉG',
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

            // ── Hőmérséklet & Üzemanyag ─────────────────
            Row(
              children: [
                Expanded(
                  child: DashboardBarCard(
                    label: 'Hűtőfolyadék',
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
                    label: 'Szívólevegő',
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
                    label: 'Üzemanyag',
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

            // ── Motor terhelés & Gázpedál ───────────────
            Row(
              children: [
                Expanded(
                  child: DashboardValueCard(
                    label: 'Motor terhelés',
                    value: _s('0104'),
                    unit: '%',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: DashboardValueCard(
                    label: 'Gázpedál',
                    value: _s('0111'),
                    unit: '%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── Akku & Manifold nyomás ──────────────────
            Row(
              children: [
                Expanded(
                  child: DashboardValueCard(
                    label: 'Akku (12V)',
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
                    label: 'Töltőnyomás',
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

            // ── MAF ─────────────────────────────────────
            DashboardBarCard(
              label: 'Levegő tömegáram (MAF)',
              value: _v('0110'),
              min: 0,
              max: 200,
              unit: 'g/s',
              barColor: const Color(0xFF7E57C2),
              minLabel: '0',
              maxLabel: '200 g/s',
            ),

            // ── Fedélzeti computer ──────────────────────
            const DashboardSectionTitle('FEDÉLZETI COMPUTER'),
            const DCard(
              child: Row(
                children: [
                  Expanded(
                      child: TripItem(
                          label: 'Átlagfogy.',
                          value: '--',
                          unit: 'L/100km')),
                  Expanded(
                      child: TripItem(
                          label: 'Pillanatfogy.',
                          value: '--',
                          unit: 'L/100km')),
                  Expanded(
                      child: TripItem(
                          label: 'Megtett táv',
                          value: '--',
                          unit: 'km')),
                  Expanded(
                      child: TripItem(
                          label: 'Hatótávolság',
                          value: '--',
                          unit: 'km')),
                ],
              ),
            ),

            // ── Állapotsor ──────────────────────────────
            const DashboardStatusBar(
              leftText: 'Nincs aktív hibakód (DTC)',
              rightText: 'PID lekérdezés: --ms',
            ),
          ],
        ),
      ),
    );
  }
}
