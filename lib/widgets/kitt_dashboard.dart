import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/locale_notifier.dart';

/// A KITT retro műszerfal belépési pontja: kezeli az animáció életciklusát
/// és átadja az adatokat az ICE vagy EV elrendezés widgetnek.
class KittDashboard extends StatefulWidget {
  final Map<String, String> data;
  final bool isEv;

  const KittDashboard({super.key, required this.data, required this.isEv});

  @override
  State<KittDashboard> createState() => _KittDashboardState();
}

class _KittDashboardState extends State<KittDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanner;

  @override
  void initState() {
    super.initState();
    _scanner = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanner.dispose();
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

  // Értéket normalizál [0.0, 1.0] tartományba a sávgrafikonokhoz.
  double _norm(double v, double min, double max) =>
      max == min ? 0 : ((v - min) / (max - min)).clamp(0.0, 1.0);

  String _rpmFmt() {
    final v = _d('010C');
    return v <= 0 ? '--' : v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final landscape = orientation == Orientation.landscape;
        return widget.isEv
            ? _EvLayout(
                data: widget.data,
                d: _d,
                s: _s,
                norm: _norm,
                scanner: _scanner,
                landscape: landscape,
              )
            : _IceLayout(
                data: widget.data,
                d: _d,
                s: _s,
                rpmFmt: _rpmFmt,
                norm: _norm,
                scanner: _scanner,
                landscape: landscape,
              );
      },
    );
  }
}

/// ICE adatokhoz optimalizált KITT elrendezés: sebesség, fordulat, motor státusz.
class _IceLayout extends StatelessWidget {
  final Map<String, String> data;
  final double Function(String) d;
  final String Function(String, [String]) s;
  final String Function() rpmFmt;
  final double Function(double, double, double) norm;
  final Animation<double> scanner;
  final bool landscape;

  const _IceLayout({
    required this.data,
    required this.d,
    required this.s,
    required this.rpmFmt,
    required this.norm,
    required this.scanner,
    required this.landscape,
  });

  static const _red = Color(0xFFFF1100);
  static const _orange = Color(0xFFFF6600);
  static const _green = Color(0xFF00FF44);
  static const _blue = Color(0xFF00AAFF);
  static const _yellow = Color(0xFFFFDD00);

  @override
  Widget build(BuildContext context) {
    final l = context.read<LocaleNotifier>().strings;
    final bars = [
      _BarDef(l.kittCoolantBar,    norm(d('0105'), 60, 120), _orange),
      _BarDef(l.kittFuelBar,       norm(d('012F'), 0, 100),  _green),
      _BarDef(l.kittEngineLoadBar, norm(d('0104'), 0, 100),  _red),
      _BarDef(l.kittIntakeBar,     norm(d('010F'), -40, 80), _blue),
    ];
    final cards = [
      _CardDef(l.kittThrottleCard, s('0111'), '%', _orange),
      _CardDef(l.kittAux12VCard,   s('0142'), 'V', _yellow),
      _CardDef(l.kittIntakeCard,   s('010F'), '°C', _blue),
    ];

    final speedLbl = l.speedGaugeLabel;
    final rpmLbl   = l.rpmGaugeLabel;
    return _KittFrame(
      child: landscape
          ? _iceLandscape(bars, cards, speedLbl, rpmLbl)
          : _icePortrait(bars, cards, speedLbl, rpmLbl),
    );
  }

  Widget _iceLandscape(List<_BarDef> bars, List<_CardDef> cards,
      String speedLabel, String rpmLabel) {
    return Column(children: [
      _LarsonScanner(animation: scanner, color: _red),
      const SizedBox(height: 5),
      Expanded(
        child: Row(children: [
          // Bal: fő LED-kijelzők (sebesség + fordulat)
          Expanded(
            flex: 5,
            child: Row(children: [
              Expanded(
                child: _LedDisplay(
                  label: speedLabel,
                  value: s('010D'),
                  unit: 'KM/H',
                  digits: 3,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _LedDisplay(
                  label: rpmLabel,
                  value: rpmFmt(),
                  unit: 'RPM',
                  digits: 4,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 5),
          // Közép: LED sávgrafikonok (hőmérséklet, üzemanyag, stb.)
          Expanded(
            flex: 4,
            child: _KittPanel(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: bars.map((b) => _LedBar(b)).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          // Jobb: kisebb státuszkártyák (gázpedál, akku, stb.)
          Expanded(
            flex: 3,
            child: _KittPanel(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ...cards.map((c) => _StatusCard(c)),
                    const _KittBadge('◆ K.I.T.T. OBD-II ◆'),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _icePortrait(List<_BarDef> bars, List<_CardDef> cards,
      String speedLabel, String rpmLabel) {
    return Column(children: [
      _LarsonScanner(animation: scanner, color: _red),
      const SizedBox(height: 5),
      // Fő LED-kijelzők: sebesség és fordulat
      Expanded(
        flex: 3,
        child: Row(children: [
          Expanded(
            child: _LedDisplay(label: speedLabel, value: s('010D'), unit: 'KM/H', digits: 3),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _LedDisplay(label: rpmLabel, value: rpmFmt(), unit: 'RPM', digits: 4),
          ),
        ]),
      ),
      const SizedBox(height: 5),
      // LED sávgrafikonok
      Expanded(
        flex: 2,
        child: _KittPanel(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: bars.map((b) => _LedBar(b)).toList(),
            ),
          ),
        ),
      ),
      const SizedBox(height: 5),
      // Státuszkártyák
      Expanded(
        flex: 1,
        child: Row(
          children: cards
              .expand((c) => [Expanded(child: _StatusCard(c)), const SizedBox(width: 4)])
              .toList()
            ..removeLast(),
        ),
      ),
      const SizedBox(height: 4),
      const _KittBadge('◆ K.I.T.T. OBD-II SYSTEM ◆'),
    ]);
  }
}

/// EV adatokhoz optimalizált KITT elrendezés: sebesség, teljesítmény (regen/motor), SOC.
class _EvLayout extends StatelessWidget {
  final Map<String, String> data;
  final double Function(String) d;
  final String Function(String, [String]) s;
  final double Function(double, double, double) norm;
  final Animation<double> scanner;
  final bool landscape;

  const _EvLayout({
    required this.data,
    required this.d,
    required this.s,
    required this.norm,
    required this.scanner,
    required this.landscape,
  });

  static const _blue = Color(0xFF00AAFF);
  static const _green = Color(0xFF00FF44);
  static const _orange = Color(0xFFFF6600);
  static const _yellow = Color(0xFFFFDD00);

  @override
  Widget build(BuildContext context) {
    final l = context.read<LocaleNotifier>().strings;
    final power = d('battery_power');
    final isRegen = power < 0;
    final powerColor = isRegen ? _green : _blue;
    final powerLabel = isRegen ? 'REGEN ↓' : 'MOTOR ↑';
    final powerVal = power.abs().toStringAsFixed(1);

    final bars = [
      _BarDef('SOC %', norm(d('soc_display'), 0, 100), _green),
      _BarDef('${l.powerLabel.toUpperCase()} kW', norm(power.abs(), 0, 120), powerColor),
      _BarDef('BATT °C', norm(d('battery_temp_max'), -10, 50), _orange),
      _BarDef('SOH %', norm(d('soh'), 70, 100), _blue),
    ];
    final cards = [
      _CardDef('SOC', s('soc_display'), '%', _green),
      _CardDef(l.voltageLabel, s('battery_voltage'), 'V', _blue),
      _CardDef(l.currentLabel, s('battery_current'), 'A', _yellow),
      _CardDef(l.kittAux12VCard, s('aux_battery_voltage'), 'V', _yellow),
    ];

    final speedLbl = l.speedGaugeLabel;
    return _KittFrame(
      child: landscape
          ? _evLandscape(bars, cards, powerLabel, powerVal, powerColor, speedLbl)
          : _evPortrait(bars, cards, powerLabel, powerVal, powerColor, speedLbl),
    );
  }

  Widget _evLandscape(List<_BarDef> bars, List<_CardDef> cards,
      String powerLabel, String powerVal, Color powerColor, String speedLabel) {
    return Column(children: [
      _LarsonScanner(animation: scanner, color: _blue),
      const SizedBox(height: 5),
      Expanded(
        child: Row(children: [
          Expanded(
            flex: 5,
            child: Row(children: [
              Expanded(
                child: _LedDisplay(
                  label: speedLabel,
                  value: s('speed'),
                  unit: 'KM/H',
                  digits: 3,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _LedDisplay(
                  label: powerLabel,
                  value: powerVal,
                  unit: 'KW',
                  digits: 4,
                  accentColor: powerColor,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 5),
          Expanded(
            flex: 4,
            child: _KittPanel(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: bars.map((b) => _LedBar(b)).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            flex: 3,
            child: _KittPanel(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ...cards.map((c) => _StatusCard(c)),
                    const _KittBadge('◆ K.I.T.T. EV ◆'),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _evPortrait(List<_BarDef> bars, List<_CardDef> cards,
      String powerLabel, String powerVal, Color powerColor, String speedLabel) {
    return Column(children: [
      _LarsonScanner(animation: scanner, color: _blue),
      const SizedBox(height: 5),
      Expanded(
        flex: 3,
        child: Row(children: [
          Expanded(
            child: _LedDisplay(
              label: speedLabel,
              value: s('speed'),
              unit: 'KM/H',
              digits: 3,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _LedDisplay(
              label: powerLabel,
              value: powerVal,
              unit: 'KW',
              digits: 4,
              accentColor: powerColor,
            ),
          ),
        ]),
      ),
      const SizedBox(height: 5),
      Expanded(
        flex: 2,
        child: _KittPanel(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: bars.map((b) => _LedBar(b)).toList(),
            ),
          ),
        ),
      ),
      const SizedBox(height: 5),
      Expanded(
        flex: 1,
        child: Row(
          children: cards
              .sublist(0, 3)
              .expand((c) => [Expanded(child: _StatusCard(c)), const SizedBox(width: 4)])
              .toList()
            ..removeLast(),
        ),
      ),
      const SizedBox(height: 4),
      const _KittBadge('◆ K.I.T.T. EV SYSTEM ◆'),
    ]);
  }
}

class _BarDef {
  final String label;
  final double value; // normalizált érték 0.0–1.0 között
  final Color color;
  const _BarDef(this.label, this.value, this.color);
}

class _CardDef {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _CardDef(this.label, this.value, this.unit, this.color);
}

/// Animált pásztázó fénycsík, Knight Rider stílusban. CustomPainter-rel rajzolt.
class _LarsonScanner extends StatelessWidget {
  final Animation<double> animation;
  final Color color;

  const _LarsonScanner({required this.animation, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) => CustomPaint(
          painter: _ScannerPainter(pos: animation.value, color: color),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double pos;
  final Color color;

  const _ScannerPainter({required this.pos, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const n = 30;
    const gap = 2.0;
    final sw = (size.width - gap * (n - 1)) / n;
    final activeIdx = pos * (n - 1);

    for (int i = 0; i < n; i++) {
      final x = i * (sw + gap);
      final dist = (i - activeIdx).abs();
      final glow = math.max(0.0, 1.0 - dist / 4.5);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 1, sw, size.height - 2),
        const Radius.circular(2),
      );

      // Halvány alapsáv — a nem aktív szegmensek is láthatóak maradnak
      canvas.drawRRect(
        rect,
        Paint()..color = color.withValues(alpha: 0.06),
      );

      if (glow > 0.02) {
        // Aktív szegmens belső fénye, intenzitás a pozíciótól függ
        canvas.drawRRect(
          rect,
          Paint()..color = color.withValues(alpha: 0.12 + glow * 0.88),
        );
        // Blur alapú külső glow csak a legfényesebb szegmenseken
        if (glow > 0.4) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 1, 0, sw + 2, size.height),
              const Radius.circular(3),
            ),
            Paint()
              ..color = color.withValues(alpha: 0.18 * glow)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ScannerPainter o) => o.pos != pos || o.color != color;
}

/// Nagy, LED-stílusú számkijelző felirattal és mértékegységgel.
class _LedDisplay extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final int digits;
  final Color accentColor;

  const _LedDisplay({
    required this.label,
    required this.value,
    required this.unit,
    this.digits = 3,
    this.accentColor = const Color(0xFFFF1100),
  });

  @override
  Widget build(BuildContext context) {
    final display = value == '--'
        ? '--'
        : value.contains('.')
            ? value
            : value.padLeft(digits, ' ');

    return _KittPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: accentColor.withValues(alpha: 0.45),
                fontSize: 8,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  display,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    shadows: [
                      Shadow(color: accentColor.withValues(alpha: 0.7), blurRadius: 14),
                      Shadow(color: accentColor.withValues(alpha: 0.35), blurRadius: 28),
                    ],
                  ),
                ),
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                color: accentColor.withValues(alpha: 0.45),
                fontSize: 9,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 20 szegmenses LED-sávgrafikon; a felső 10% pirosba, a 75-90% tartomány
/// narancsba vált a veszélyzóna vizuális jelzéséhez.
class _LedBar extends StatelessWidget {
  final _BarDef def;
  const _LedBar(this.def);

  @override
  Widget build(BuildContext context) {
    const n = 20;
    final active = (def.value * n).round().clamp(0, n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                def.label,
                style: TextStyle(
                  color: def.color.withValues(alpha: 0.55),
                  fontSize: 8,
                  letterSpacing: 1.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${(def.value * 100).round()}%',
              style: TextStyle(
                color: def.color.withValues(alpha: 0.7),
                fontSize: 8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: List.generate(n, (i) {
            final lit = i < active;
            Color col;
            if (!lit) {
              col = def.color.withValues(alpha: 0.07);
            } else if (i >= n * 0.9) {
              col = const Color(0xFFFF1100);
            } else if (i >= n * 0.75) {
              col = Color.lerp(
                def.color,
                const Color(0xFFFF6600),
                ((i / n - 0.75) / 0.15).clamp(0, 1),
              )!;
            } else {
              col = def.color;
            }

            return Expanded(
              child: Container(
                height: 11,
                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                decoration: BoxDecoration(
                  color: col,
                  borderRadius: BorderRadius.circular(1.5),
                  boxShadow: lit
                      ? [BoxShadow(color: col.withValues(alpha: 0.45), blurRadius: 3)]
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Kompakt adatkártya felirattal, értékkel és mértékegységgel, LED-glow hatással.
class _StatusCard extends StatelessWidget {
  final _CardDef def;
  const _StatusCard(this.def);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        border: Border.all(color: def.color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            def.label,
            style: TextStyle(
              color: def.color.withValues(alpha: 0.45),
              fontSize: 7.5,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  def.value,
                  style: TextStyle(
                    color: def.color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(color: def.color.withValues(alpha: 0.45), blurRadius: 8),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                def.unit,
                style: TextStyle(
                  color: def.color.withValues(alpha: 0.45),
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A teljes KITT műszerfal külső kerete: fekete háttér, alsó safe area padding.
class _KittFrame extends StatelessWidget {
  final Widget child;
  const _KittFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      color: const Color(0xFF050505),
      padding: EdgeInsets.fromLTRB(6, 6, 6, 6 + bottom),
      child: child,
    );
  }
}

/// Sötét hátterű, vékony keretes panel — az egyes KITT szekciók keretezéséhez.
class _KittPanel extends StatelessWidget {
  final Widget child;
  const _KittPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border.all(color: const Color(0xFF1C1C1C)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }
}

class _KittBadge extends StatelessWidget {
  final String text;
  const _KittBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF2A1010),
          fontSize: 8,
          letterSpacing: 3,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
