import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/vehicle_profile.dart';
import '../services/app_settings.dart';
import '../services/locale_notifier.dart';
import '../services/theme_notifier.dart';
import '../theme/app_theme.dart';
import 'logs_page.dart';

/// Az alkalmazás összes felhasználói beállítását kezelő oldal.
///
/// [drivetrain] — ha meg van adva (csatlakoztatott jármű esetén), csak az
/// adott motortípushoz tartozó riasztási küszöbök jelennek meg.
/// Ha null (pl. főoldalról nyitják meg), az összes szekció látható.
class SettingsPage extends StatefulWidget {
  final DrivetrainType? drivetrain;
  const SettingsPage({super.key, this.drivetrain});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _s = AppSettings();

  /// Nincs csatlakoztatott jármű → mindkét szekció látszik.
  bool get _showEvAlerts  => widget.drivetrain == null ||
      widget.drivetrain == DrivetrainType.ev   ||
      widget.drivetrain == DrivetrainType.phev;

  bool get _showIceAlerts => widget.drivetrain == null ||
      widget.drivetrain == DrivetrainType.ice    ||
      widget.drivetrain == DrivetrainType.hybrid ||
      widget.drivetrain == DrivetrainType.phev;

  late String _languageCode;
  late int    _rangeMode;
  late double _whPerKm;
  late bool   _useImperial;
  late bool   _useFahrenheit;
  late double _alertSoc;
  late double _alertTemp;
  late double _alertCell;
  late double _alertCoolant;
  late double _alertFuel;
  late bool   _autoConnect;

  @override
  void initState() {
    super.initState();
    _loadFromSettings();
  }

  void _loadFromSettings() {
    _languageCode      = _s.languageCode;
    _rangeMode         = _s.rangeMode;
    _whPerKm           = _s.whPerKmFallback.clamp(50.0, 500.0);
    _useImperial       = _s.useImperial;
    _useFahrenheit     = _s.useFahrenheit;
    _alertSoc          = _s.alertSocMin.clamp(5.0, 50.0);
    _alertTemp         = _s.alertTempMax.clamp(25.0, 60.0);
    _alertCell         = _s.alertCellSpread.clamp(10.0, 200.0);
    _alertCoolant      = _s.alertCoolantMax.clamp(80.0, 120.0);
    _alertFuel         = _s.alertFuelMin.clamp(5.0, 30.0);
    _autoConnect       = _s.autoConnectEnabled;
  }

  Future<void> _saveAll() async {
    await _s.setRangeMode(_rangeMode);
    await _s.setWhPerKmValue(_whPerKm);
    await _s.setUnits(imperial: _useImperial, fahrenheit: _useFahrenheit);
    await _s.setAlerts(
      socMin:     _alertSoc,
      tempMax:    _alertTemp,
      cellSpread: _alertCell,
      coolantMax: _alertCoolant,
      fuelMin:    _alertFuel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleNotifier>().strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: l10n.resetToDefault,
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [

          _SectionHeader(l10n.language,
              icon: Icons.language, color: AppTheme.accentTeal),
          _LanguageSelectorCard(
            languageCode: _languageCode,
            onChanged: (code) async {
              setState(() => _languageCode = code);
              await context.read<LocaleNotifier>().setLanguage(code);
            },
          ),
          const SizedBox(height: 20),

          _SectionHeader(l10n.appearance,
              icon: Icons.palette_outlined, color: AppTheme.accentPurple),
          const _ThemeSelectorCard(),
          const SizedBox(height: 20),

          _SectionHeader(l10n.consumptionRange,
              icon: Icons.electric_bolt, color: AppTheme.accentBlue),
          _ConsumptionCard(
            rangeMode: _rangeMode,
            whPerKm: _whPerKm,
            onModeChanged: (mode) async {
              setState(() => _rangeMode = mode);
              await _saveAll();
            },
            onValueChanged: (v) => setState(() => _whPerKm = v),
            onValueCommit: (_) => _saveAll(),
          ),

          const SizedBox(height: 20),

          _SectionHeader(l10n.units, icon: Icons.straighten, color: AppTheme.accentBlue),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  _UnitToggleRow(
                    label: l10n.speedAndDistance,
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
                  _UnitToggleRow(
                    label: l10n.temperature,
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

          _SectionHeader(l10n.alertThresholds, icon: Icons.warning_amber,
              color: Colors.orange),

          // EV / PHEV riasztási küszöbök — csak EV, PHEV vagy nincs szűrés esetén
          if (_showEvAlerts) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fejléc csak akkor, ha mindkét szekció látszik
                    if (_showIceAlerts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(l10n.evPhevSectionLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue.shade300,
                                letterSpacing: 0.8)),
                      ),
                    _ThresholdRow(
                      icon: Icons.battery_alert,
                      label: l10n.socMinimum,
                      description: l10n.socMinDescription,
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
                      label: l10n.batteryTempMax,
                      description: l10n.batteryTempMaxDescription,
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
                      label: l10n.cellBalanceMax,
                      description: l10n.cellBalanceMaxDescription,
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
            if (_showIceAlerts) const SizedBox(height: 8),
          ],

          // ICE riasztási küszöbök — csak ICE, hybrid, PHEV vagy nincs szűrés esetén
          if (_showIceAlerts)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fejléc csak akkor, ha mindkét szekció látszik
                    if (_showEvAlerts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(l10n.iceSectionLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.deepOrange.shade300,
                                letterSpacing: 0.8)),
                      ),
                    _ThresholdRow(
                      icon: Icons.thermostat,
                      label: l10n.coolantTempMaxLabel,
                      description: l10n.coolantTempMaxDesc,
                      value: _alertCoolant,
                      unit: '°C',
                      min: 80, max: 120, divisions: 40,
                      color: Colors.deepOrange,
                      onChanged: (v) => setState(() => _alertCoolant = v),
                      onChangeEnd: (_) => _saveAll(),
                    ),
                    const Divider(height: 24),
                    _ThresholdRow(
                      icon: Icons.local_gas_station,
                      label: l10n.fuelLevelMinLabel,
                      description: l10n.fuelLevelMinDesc,
                      value: _alertFuel,
                      unit: '%',
                      min: 5, max: 30, divisions: 25,
                      color: Colors.amber,
                      onChanged: (v) => setState(() => _alertFuel = v),
                      onChangeEnd: (_) => _saveAll(),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
          _SectionHeader(l10n.autoConnect,
              icon: Icons.bluetooth_connected, color: AppTheme.accentTeal),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.autoConnectTitle,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              l10n.autoConnectDescription,
                              style: const TextStyle(
                                  color: AppTheme.textSec, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _autoConnect,
                        activeThumbColor: AppTheme.accentTeal,
                        onChanged: (v) {
                          setState(() => _autoConnect = v);
                          _s.setAutoConnect(v);
                        },
                      ),
                    ],
                  ),
                  if (_s.lastDeviceName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.accentTeal.withValues(alpha: 0.24)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.bluetooth,
                            size: 16, color: AppTheme.accentTeal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _s.lastDeviceName,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                              Text(
                                _s.lastDeviceAddress,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.45),
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _s.lastConnectionType == 'ble' ? 'BLE' : 'Classic',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withValues(alpha: 0.60),
                              fontSize: 11),
                        ),
                      ]),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.noSavedDevice,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.45),
                          fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          _SectionHeader(l10n.developer,
              icon: Icons.bug_report_outlined, color: Colors.grey),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: Colors.grey),
                  title: Text(l10n.debugLog),
                  subtitle: Text(
                    l10n.debugLogDescription,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LogsPage()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.read<LocaleNotifier>().strings;
        return AlertDialog(
          title: Text(l10n.resetSettingsTitle),
          content: Text(l10n.confirmResetSettings),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel)),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.resetSettingsTitle,
                    style: const TextStyle(color: Colors.red))),
          ],
        );
      },
    );
    if (ok == true) {
      await _s.setRangeMode(0);
      await _s.setWhPerKmValue(140.0);
      await _s.setUnits(imperial: false, fahrenheit: false);
      await _s.setAlerts(socMin: 15.0, tempMax: 40.0, cellSpread: 50.0,
                         coolantMax: 105.0, fuelMin: 10.0);
      if (mounted) await context.read<ThemeNotifier>().setMode(ThemeMode.system);
      setState(_loadFromSettings);
      if (mounted) {
        final l10n = context.read<LocaleNotifier>().strings;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsReset)),
        );
      }
    }
  }
}

/// Világos / sötét / rendszer témaváltó kártya a beállítások oldalon.
class _ThemeSelectorCard extends StatelessWidget {
  const _ThemeSelectorCard();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ThemeNotifier>();
    final l10n = context.watch<LocaleNotifier>().strings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.appTheme,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_outlined, size: 16),
                  label: Text(l10n.automatic),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined, size: 16),
                  label: Text(l10n.light),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined, size: 16),
                  label: Text(l10n.dark),
                ),
              ],
              selected: {notifier.mode},
              onSelectionChanged: (s) => notifier.setMode(s.first),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hatótáv-becslési mód választója és a hozzá tartozó tartalom (auto / hőmérséklet / manuális).
class _ConsumptionCard extends StatelessWidget {
  final int rangeMode;      // 0=auto, 1=hőmérséklet, 2=manuális
  final double whPerKm;
  final ValueChanged<int>    onModeChanged;
  final ValueChanged<double> onValueChanged;
  final ValueChanged<double> onValueCommit;

  const _ConsumptionCard({
    required this.rangeMode,
    required this.whPerKm,
    required this.onModeChanged,
    required this.onValueChanged,
    required this.onValueCommit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleNotifier>().strings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              l10n.rangeEstimationMode,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              segments: [
                ButtonSegment<int>(
                  value: 0,
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  label: Text(l10n.rangeAutomatic),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: const Icon(Icons.thermostat, size: 15),
                  label: Text(l10n.rangeTemperature),
                ),
                ButtonSegment<int>(
                  value: 2,
                  icon: const Icon(Icons.tune, size: 15),
                  label: Text(l10n.rangeManual),
                ),
              ],
              selected: {rangeMode},
              onSelectionChanged: (s) => onModeChanged(s.first),
            ),
            const SizedBox(height: 14),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(rangeMode),
                child: _modeContent(l10n),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeContent(AppLocalizations l10n) {
    switch (rangeMode) {
      case 1:
        return _TempModeCard(whPerKm: whPerKm);
      case 2:
        return _ManualSlider(
          whPerKm: whPerKm,
          onValueChanged: onValueChanged,
          onValueCommit: onValueCommit,
          hint: l10n.consumptionHint(whPerKm),
        );
      default:
        return const _AutoModeCard();
    }
  }
}

/// Tájékoztató kártya: elmagyarázza, hogyan működik a valós fogyasztás-integrálás.
class _AutoModeCard extends StatelessWidget {
  const _AutoModeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppTheme.accentBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.watch<LocaleNotifier>().strings.autoModeDescription,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSec),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kültéri hőmérséklet alapján korrigált hatótáv-becslés leírása és hatékonysági táblázata.
class _TempModeCard extends StatelessWidget {
  final double whPerKm;
  const _TempModeCard({required this.whPerKm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.thermostat, size: 18, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.watch<LocaleNotifier>().strings.tempModeDescription,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.read<LocaleNotifier>().strings.expectedConsumptionChange,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: AppTheme.textSec),
          ),
          const SizedBox(height: 4),
          _effRow('-10°C', 0.68, whPerKm),
          _effRow('  0°C', 0.81, whPerKm),
          _effRow(' 10°C', 0.91, whPerKm),
          _effRow(' 20°C', 1.00, whPerKm),
          _effRow(' 30°C', 0.97, whPerKm),
        ],
      ),
    );
  }

  Widget _effRow(String label, double eff, double baseWh) {
    final adjWh = baseWh / eff;
    final change = ((eff - 1.0) * 100).round();
    final changeStr = change >= 0 ? '+$change%' : '$change%';
    final color = eff >= 1.0
        ? Colors.green
        : eff >= 0.85
            ? Colors.orange
            : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(label,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12)),
          ),
          Text('${adjWh.round()} Wh/km',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(changeStr,
              style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

/// Rögzített Wh/km érték beállítása csúszkával, kontextuális tippel.
class _ManualSlider extends StatelessWidget {
  final double whPerKm;
  final String hint;
  final ValueChanged<double> onValueChanged;
  final ValueChanged<double> onValueCommit;

  const _ManualSlider({
    required this.whPerKm,
    required this.hint,
    required this.onValueChanged,
    required this.onValueCommit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.watch<LocaleNotifier>().strings.fixedConsumptionNorm,
                style: const TextStyle(fontSize: 13)),
            Text(
              '${whPerKm.round()} Wh/km',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.accentBlue,
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
          hint,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textDim,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

/// Kétállású mértékegység-választó sor (pl. km ↔ mi, °C ↔ °F).
class _UnitToggleRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String leftLabel;
  final String rightLabel;
  final bool rightSelected;      // false = bal (metrikus), true = jobb (imperial/fahrenheit)
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
            Icon(icon, size: 18, color: AppTheme.textSec),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14,
                    color: AppTheme.textPrimary)),
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

/// Csúszkával állítható riasztási küszöbérték-sor ikonnal, leírással és aktuális értékkel.
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
        // Fejléc: ikon, felirat és az aktuális érték
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
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textDim)),
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
        // Csúszka min/max határfeliratokkal
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

/// Nyelv-választó kártya (Magyar / English).
class _LanguageSelectorCard extends StatelessWidget {
  final String languageCode;
  final ValueChanged<String> onChanged;

  const _LanguageSelectorCard({
    required this.languageCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleNotifier>().strings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.language,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(
                  value: 'hu',
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: Text(l10n.hungarian),
                ),
                ButtonSegment(
                  value: 'en',
                  icon: const Icon(Icons.language, size: 16),
                  label: Text(l10n.english),
                ),
              ],
              selected: {languageCode},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ],
        ),
      ),
    );
  }
}

/// Beállítási szekció vizuális elválasztója ikonnal és felirattal.
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader(this.title,
      {required this.icon, required this.color});

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
