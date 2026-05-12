// PHEV ICE nézet — benzinmotor adatait megjelenítő widget Ford Kuga PHEV-hez.
// PHEV-specifikus mező azonosítókat használ ('rpm', 'fuel_level', 'coolant_temp',
// 'engine_load', 'speed') — nem az ICE-dashboard OBD kód alapú kulcsait.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/locale_notifier.dart';
import 'dashboard_gauge.dart';
import 'dashboard_cards.dart';

/// PHEV benzinmotor adatai: RPM és sebesség műszer, üzemanyag, hűtőfolyadék,
/// motor terhelés. Csak PHEV járműveknél jelenik meg.
class PhevIceView extends StatelessWidget {
  final Map<String, String> data;

  const PhevIceView({super.key, required this.data});

  double _v(String id) => parseObd(data[id]);

  @override
  Widget build(BuildContext context) {
    final l       = context.read<LocaleNotifier>().strings;
    final rpm     = _v('rpm');
    final speed   = _v('speed');
    final fuel    = _v('fuel_level');
    final coolant = _v('coolant_temp');
    final load    = _v('engine_load');
    final running = rpm > 50;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // Motor státusz banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: running
                  ? Colors.deepOrange.withValues(alpha: 0.12)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: running
                    ? Colors.deepOrange
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Row(children: [
              Icon(
                running ? Icons.local_gas_station : Icons.electric_bolt,
                color: running ? Colors.deepOrange : const Color(0xFF66BB6A),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                running ? l.iceEngineActiveLabel : l.electricModeEngineOff,
                style: TextStyle(
                  color: running ? Colors.deepOrange : const Color(0xFF66BB6A),
                  fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                ),
              ),
              if (running) ...[
                const Spacer(),
                Text('${rpm.toStringAsFixed(0)} RPM',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ]),
          ),

          // RPM + sebesség tárcsás műszerek
          Row(children: [
            Expanded(child: OBDNeedleGauge(
              title: l.rpmGaugeLabel,
              value: rpm,
              minValue: 0, maxValue: 6000, unit: 'rpm',
              zones: const [
                GaugeZone(from: 0,    to: 4500, color: Color(0xFF4A4A4A)),
                GaugeZone(from: 4500, to: 5500, color: Color(0xFFFFA726)),
                GaugeZone(from: 5500, to: 6000, color: Color(0xFFEF5350)),
              ],
              tickValues: const [0, 1000, 2000, 3000, 4000, 5000, 6000],
            )),
            const SizedBox(width: 8),
            Expanded(child: OBDNeedleGauge(
              title: l.speedGaugeLabel,
              value: speed.abs(),
              minValue: 0, maxValue: 200, unit: 'km/h',
              tickValues: const [0, 40, 80, 120, 160, 200],
            )),
          ]),
          const SizedBox(height: 8),

          // Üzemanyag sáv
          DashboardBarCard(
            label: l.fuelLabel,
            value: fuel,
            min: 0, max: 100, unit: '%',
            barColor: fuel < 10 ? Colors.red :
                      fuel < 20 ? Colors.orange :
                      const Color(0xFF66BB6A),
            minLabel: l.fuelEmptyLabel,
            maxLabel: l.fuelFullLabel,
          ),
          const SizedBox(height: 6),

          // Hűtőfolyadék hőmérséklet sáv
          DashboardBarCard(
            label: l.coolantTempLabel,
            value: coolant,
            min: 0, max: 120, unit: '°C',
            barColor: coolant >= 110 ? Colors.red :
                      coolant >= 100 ? Colors.orange :
                      coolant < 60   ? Colors.lightBlue :
                      const Color(0xFFFFA726),
            minLabel: '0°C',
            maxLabel: '120°C',
          ),
          const SizedBox(height: 6),

          // Motor terhelés sáv
          DashboardBarCard(
            label: l.engineLoadLabel,
            value: load,
            min: 0, max: 100, unit: '%',
            barColor: load >= 90 ? Colors.red :
                      load >= 70 ? Colors.orange :
                      const Color(0xFF42A5F5),
            minLabel: '0%',
            maxLabel: '100%',
          ),
          const SizedBox(height: 6),

          // Értékkártyák: terhelés + hűtő
          Row(children: [
            Expanded(child: Builder(builder: (ctx) => DashboardValueCard(
              label: l.engineLoadLabel,
              value: load > 0 ? load.toStringAsFixed(0) : '--',
              unit: '%',
              accentColor: load >= 90 ? Colors.red :
                           load >= 70 ? Colors.orange :
                           Theme.of(ctx).colorScheme.onSurface,
            ))),
            const SizedBox(width: 6),
            Expanded(child: Builder(builder: (ctx) => DashboardValueCard(
              label: l.coolantTempLabel,
              value: coolant > 0 ? coolant.toStringAsFixed(0) : '--',
              unit: '°C',
              accentColor: coolant >= 110 ? Colors.red :
                           coolant >= 100 ? Colors.orange :
                           coolant < 60   ? Colors.lightBlue :
                           Theme.of(ctx).colorScheme.onSurface,
            ))),
          ]),
          const SizedBox(height: 6),

          DashboardStatusBar(
            leftText: l.iceDataSourceLabel,
            rightText: 'Mode 01 | OBD-II',
          ),
        ]),
      ),
    );
  }
}
