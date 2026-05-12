// lib/pages/settings_page.dart

import 'package:flutter/material.dart';
import '../services/app_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _s = AppSettings();

  late bool   _whOverrideEnabled;
  late double _whPerKm;
  late bool   _useImperial;
  late bool   _useFahrenheit;
  late double _alertSoc;
  late double _alertTemp;
  late double _alertCell;

  @override
  void initState() {
    super.initState();
    _loadFromSettings();
  }

  void _loadFromSettings() {
    _whOverrideEnabled = _s.whPerKmOverrideEnabled;
    _whPerKm           = _s.whPerKmFallback.clamp(50.0, 500.0);
    _useImperial       = _s.useImperial;
    _useFahrenheit     = _s.useFahrenheit;
    _alertSoc          = _s.alertSocMin.clamp(5.0, 50.0);
    _alertTemp         = _s.alertTempMax.clamp(25.0, 60.0);
    _alertCell         = _s.alertCellSpread.clamp(10.0, 200.0);
  }

  Future<void> _saveAll() async {
    await _s.setWhPerKm(_whOverrideEnabled, _whPerKm);
    await _s.setUnits(imperial: _useImperial, fahrenheit: _useFahrenheit);
    await _s.setAlerts(
      socMin:     _alertSoc,
      tempMax:    _alertTemp,
      cellSpread: _alertCell,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beállítások'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Visszaállítás alapértelmezettre',
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [

          // ══ 1. FOGYASZTÁS ═══════════════════════════════════════════════
          _SectionHeader('Fogyasztás / hatótáv-becslés',
              icon: Icons.electric_bolt, color: cs.primary),
          _ConsumptionCard(
            enabled: _whOverrideEnabled,
            whPerKm: _whPerKm,
            onModeChanged: (manual) async {
              setState(() => _whOverrideEnabled = manual);
              await _saveAll();
            },
            onValueChanged: (v) => setState(() => _whPerKm = v),
            onValueCommit: (_) => _saveAll(),
          ),

          const SizedBox(height: 20),

          // ══ 2. MÉRTÉKEGYSÉGEK ════════════════════════════════════════════
          _SectionHeader('Mértékegységek', icon: Icons.straighten, color: cs.primary),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  // ── Sebesség / távolság ─────────────────────────────────
                  _UnitToggleRow(
                    label: 'Sebesség és távolság',
                    icon: Icons.speed,
                    leftLabel: 'km / km/h',
                    rightLabel: 'mi / mph',
                    rightSelected: _useImperial,
                    onChanged: (imperial) async {
                      setState(() => _useImperial = imperial);
                      await _saveAll();
                    },
                  ),
                  const Divider(height: 28),
                  // ── Hőmérséklet ─────────────────────────────────────────
                  _UnitToggleRow(
                    label: 'Hőmérséklet',
                    icon: Icons.thermostat,
                    leftLabel: '°C',
                    rightLabel: '°F',
                    rightSelected: _useFahrenheit,
                    onChanged: (fahrenheit) async {
                      setState(() => _useFahrenheit = fahrenheit);
                      await _saveAll();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ══ 3. RIASZTÁSI KÜSZÖBÖK ════════════════════════════════════════
          _SectionHeader('Riasztási küszöbök', icon: Icons.warning_amber,
              color: Colors.orange),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  _ThresholdRow(
                    icon: Icons.battery_alert,
                    label: 'SOC minimum',
                    description: 'Ha a töltöttség erre az értékre esik, riasztás.',
                    value: _alertSoc,
                    unit: '%',
                    min: 5, max: 50, divisions: 45,
                    color: Colors.red,
                    onChanged: (v) => setState(() => _alertSoc = v),
                    onChangeEnd: (_) => _saveAll(),
                  ),
                  const Divider(height: 24),
                  _ThresholdRow(
                    icon: Icons.thermostat,
                    label: 'Akku hőmérséklet maximum',
                    description: 'Ennél magasabb akkumulátor-hőfoknál riasztás.',
                    value: _alertTemp,
                    unit: '°C',
                    min: 25, max: 60, divisions: 35,
                    color: Colors.orange,
                    onChanged: (v) => setState(() => _alertTemp = v),
                    onChangeEnd: (_) => _saveAll(),
                  ),
                  const Divider(height: 24),
                  _ThresholdRow(
                    icon: Icons.bar_chart,
                    label: 'Cellaegyensúly maximum',
                    description: 'Ennél nagyobb max-min cellaeltérésnél riasztás.',
                    value: _alertCell,
                    unit: 'mV',
                    min: 10, max: 200, divisions: 38,
                    color: Colors.purple,
                    onChanged: (v) => setState(() => _alertCell = v),
                    onChangeEnd: (_) => _saveAll(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),
          Center(
            child: Text(
              'OBD2 Monitor – Flutter',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Visszaállítás'),
        content: const Text(
            'Biztosan visszaállítod az összes beállítást az alapértékre?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Mégse')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Visszaállítás',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _s.setWhPerKm(false, 170.0);
      await _s.setUnits(imperial: false, fahrenheit: false);
      await _s.setAlerts(socMin: 15.0, tempMax: 40.0, cellSpread: 50.0);
      setState(_loadFromSettings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Beállítások visszaállítva.')),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FOGYASZTÁS KÁRTYA — kétállású mód-választó + csúszka
// ═══════════════════════════════════════════════════════════════════════════

class _ConsumptionCard extends StatelessWidget {
  final bool enabled;          // true = manuális, false = automatikus
  final double whPerKm;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<double> onValueChanged;
  final ValueChanged<double> onValueCommit;

  const _ConsumptionCard({
    required this.enabled,
    required this.whPerKm,
    required this.onModeChanged,
    required this.onValueChanged,
    required this.onValueCommit,
  });

  String _hint(double v) {
    if (v < 100) return 'Rendkívül hatékony (pl. könnyű városi EV)';
    if (v < 140) return 'Hatékony (pl. Ioniq, Model 3)';
    if (v < 180) return 'Átlagos EV fogyasztás';
    if (v < 250) return 'Nagyobb SUV / téli körülmény';
    return 'Nagy fogyasztás (pl. Audi e-tron, Rivian)';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Mód-választó: Automatikus / Manuális ─────────────────
            const Text(
              'Hatótáv-becslés módja',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.comfortable,
              ),
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.auto_awesome, size: 16),
                  label: Text('Automatikus'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.tune, size: 16),
                  label: Text('Manuális'),
                ),
              ],
              selected: {enabled},
              onSelectionChanged: (s) => onModeChanged(s.first),
            ),
            const SizedBox(height: 12),

            // ── Leírás a választott módhoz ────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: enabled
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,

              // ── Automatikus mód leírása ───────────────────────────
              firstChild: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18,
                        color: cs.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Az alkalmazás menet közben méri a tényleges '
                        'fogyasztást (sebesség × teljesítmény integrálás), '
                        'és azt használja a hatótáv kiszámításához.\n'
                        'Amíg nincs elegendő adat (< 500 m), '
                        'az alapértelmezett 170 Wh/km értéket alkalmazza.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Manuális csúszka ──────────────────────────────────
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Rögzített fogyasztás-norma',
                          style: TextStyle(fontSize: 13)),
                      Text(
                        '${whPerKm.round()} Wh/km',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('50',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Expanded(
                        child: Slider(
                          value: whPerKm,
                          min: 50,
                          max: 500,
                          divisions: 90,
                          label: '${whPerKm.round()} Wh/km',
                          onChanged: onValueChanged,
                          onChangeEnd: onValueCommit,
                        ),
                      ),
                      const Text('500',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  Text(
                    _hint(whPerKm),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MÉRTÉKEGYSÉG KAPCSOLÓ SOR — bal/jobb felirattal, SegmentedButton-nal
// ═══════════════════════════════════════════════════════════════════════════

class _UnitToggleRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String leftLabel;
  final String rightLabel;
  final bool rightSelected;      // false = bal (alapértelmezett), true = jobb
  final ValueChanged<bool> onChanged;

  const _UnitToggleRow({
    required this.label,
    required this.icon,
    required this.leftLabel,
    required this.rightLabel,
    required this.rightSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.comfortable,
          ),
          segments: [
            ButtonSegment<bool>(
              value: false,
              label: Text(leftLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            ButtonSegment<bool>(
              value: true,
              label: Text(rightLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
          selected: {rightSelected},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RIASZTÁSI KÜSZÖB SOR
// ═══════════════════════════════════════════════════════════════════════════

class _ThresholdRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final double value;
  final String unit;
  final double min, max;
  final int divisions;
  final Color color;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _ThresholdRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Fejléc: ikon + felirat + aktuális érték ─────────────────
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(description,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${value.round()} $unit',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // ── Csúszka min/max felirattal ───────────────────────────────
        Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '${min.round()}$unit',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                activeColor: color,
                label: '${value.round()} $unit',
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${max.round()}$unit',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SZEKCIÓ FEJLÉC
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader(this.title, {required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2, left: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
