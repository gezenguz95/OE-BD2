import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/locale_notifier.dart';
import '../theme/app_theme.dart';

/// A műszer ívének egy kiemelő zónája — értéktartomány és szín.
class GaugeZone {
  final double from;
  final double to;
  final Color color;
  final double strokeWidth;
  const GaugeZone({
    required this.from,
    required this.to,
    required this.color,
    this.strokeWidth = 10.0,
  });
}

/// Általános analóg tűs műszer — RPM, sebesség és egyéb OBD értékekhez.
class OBDNeedleGauge extends StatelessWidget {
  final String title;
  final double value;
  final double minValue;
  final double maxValue;
  final String unit;
  final List<GaugeZone> zones;
  final List<double> tickValues;

  const OBDNeedleGauge({
    super.key,
    required this.title,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.unit,
    this.zones = const [],
    this.tickValues = const [],
  });

  String _fmt(double v) {
    if (v.isNaN || v.isInfinite) return '--';
    if (v >= 1000) {
      final s = v.toInt().toString();
      if (s.length > 3) {
        return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
      }
    }
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF9E9E9E),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          AspectRatio(
            aspectRatio: 1.2,
            child: CustomPaint(
              painter: _NeedleGaugePainter(
                value: value,
                minValue: minValue,
                maxValue: maxValue,
                zones: zones,
                tickValues: tickValues,
                trackColor: AppTheme.trackColor(context),
              ),
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: _fmt(value),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                TextSpan(
                  text: '  $unit',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color
                        ?? const Color(0xFF9E9E9E),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _NeedleGaugePainter extends CustomPainter {
  final double value;
  final double minValue;
  final double maxValue;
  final List<GaugeZone> zones;
  final List<double> tickValues;
  final Color trackColor;

  // 270°-os ív: 135°-nál (7:30 pozíció) kezdődik, óramutató járásával megegyező irányban
  static const _startDeg = 135.0;
  static const _sweepDeg = 270.0;
  static const _startRad = _startDeg * math.pi / 180.0;
  static const _sweepRad = _sweepDeg * math.pi / 180.0;

  const _NeedleGaugePainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.zones,
    required this.tickValues,
    required this.trackColor,
  });

  double _toRad(double v) {
    final pct = ((v - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
    return _startRad + _sweepRad * pct;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.60;
    final center = Offset(cx, cy);
    final radius = math.min(size.width * 0.37, size.height * 0.46);

    // 1. Háttér ív (témafüggő szín)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startRad, _sweepRad, false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.butt,
    );

    // 2. Opcionális színzónák (pl. piros veszélyzóna)
    for (final z in zones) {
      final zStart = _toRad(z.from);
      final zSweep = _toRad(z.to) - zStart;
      if (zSweep <= 0) continue;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        zStart, zSweep, false,
        Paint()
          ..color = z.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = z.strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
    }

    // 3. Osztásjelek és értékfeliratok
    final tickPaint = Paint()
      ..color = const Color(0xFF606060)
      ..strokeWidth = 1.5;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (final tv in tickValues) {
      final angle = _toRad(tv);
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      canvas.drawLine(
        Offset(center.dx + (radius - 2) * cosA, center.dy + (radius - 2) * sinA),
        Offset(center.dx + (radius - 11) * cosA, center.dy + (radius - 11) * sinA),
        tickPaint,
      );

      final lr = radius - 22;
      tp.text = TextSpan(
        text: tv >= 1000 ? (tv ~/ 1000).toString() : tv.toInt().toString(),
        style: const TextStyle(color: Color(0xFF808080), fontSize: 8.5),
      );
      tp.layout();
      tp.paint(canvas, Offset(
        center.dx + lr * cosA - tp.width / 2,
        center.dy + lr * sinA - tp.height / 2,
      ));
    }

    // 4. Mutató tű és középső kör
    final pct = ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
    final needleAngle = _startRad + _sweepRad * pct;
    final nl = radius - 13;
    final tipX = center.dx + nl * math.cos(needleAngle);
    final tipY = center.dy + nl * math.sin(needleAngle);

    canvas.drawLine(
      center, Offset(tipX, tipY),
      Paint()..color = Colors.white..strokeWidth = 1.8..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(tipX, tipY), 3.5, Paint()..color = Colors.white);
    canvas.drawCircle(center, 6.0, Paint()..color = const Color(0xFF555555));
    canvas.drawCircle(center, 2.8, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_NeedleGaugePainter old) =>
      old.value != value || old.minValue != minValue ||
      old.maxValue != maxValue || old.trackColor != trackColor;
}

/// EV teljesítmény műszer — negatív értékek REGEN (zöld), pozitívak MOTOR (kék) zónát jelölnek.
class OBDPowerGauge extends StatelessWidget {
  final double value; // kW, negatív = rekuperáció
  final double minValue; // pl. -60
  final double maxValue; // pl. 150

  const OBDPowerGauge({
    super.key,
    required this.value,
    this.minValue = -60,
    this.maxValue = 150,
  });

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final tt        = Theme.of(context).textTheme;
    final sign       = value > 0 ? '+' : '';
    final valueColor = value < 0
        ? const Color(0xFF66BB6A)
        : cs.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.watch<LocaleNotifier>().strings.powerLabel.toUpperCase(),
            style: TextStyle(
              color: tt.bodySmall?.color ?? const Color(0xFF9E9E9E),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          AspectRatio(
            aspectRatio: 1.2,
            child: CustomPaint(
              painter: _PowerGaugePainter(
                value: value,
                minValue: minValue,
                maxValue: maxValue,
                regenBgColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1B3A1B)
                    : Colors.green.withValues(alpha: 0.12),
                motorBgColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF0D1F3A)
                    : Colors.blue.withValues(alpha: 0.10),
              ),
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$sign${value.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                TextSpan(
                  text: '  kW',
                  style: TextStyle(
                      color: tt.bodySmall?.color ?? const Color(0xFF9E9E9E),
                      fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _PowerGaugePainter extends CustomPainter {
  final double value;
  final double minValue;
  final double maxValue;
  final Color regenBgColor;
  final Color motorBgColor;

  // 210° kezdet, 210° ív → a 0 kW pont pontosan a tetőn (270° = 12 óra) van
  static const _startRad = 210.0 * math.pi / 180.0;
  static const _sweepRad = 210.0 * math.pi / 180.0;

  const _PowerGaugePainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.regenBgColor,
    required this.motorBgColor,
  });

  double _toRad(double v) {
    final pct = ((v - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
    return _startRad + _sweepRad * pct;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // Középpontot lejjebb toljuk, hogy a '0' felirat (270° = 12 óra) a canvas-on belül
    // maradjon és ne csússzon rá a widget-cím szövegre.
    final cy = size.height * 0.60;
    final center = Offset(cx, cy);
    final radius = math.min(size.width * 0.37, size.height * 0.46);

    final zeroAngle = _toRad(0.0);
    final regenSweep = zeroAngle - _startRad;
    final motorSweep = _sweepRad - regenSweep;

    // 1. Rekuperáció (REGEN) zóna háttere — témafüggő
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startRad, regenSweep, false,
      Paint()
        ..color = regenBgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.butt,
    );

    // 2. Motoros (MOTOR) zóna háttere — témafüggő
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      zeroAngle, motorSweep, false,
      Paint()
        ..color = motorBgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.butt,
    );

    // 3. Aktív kiemelés: az aktuális értékig megvilágítja a megfelelő zónát
    if (value < 0) {
      final valAngle = _toRad(value);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        valAngle, zeroAngle - valAngle, false,
        Paint()
          ..color = const Color(0xFF4CAF50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.butt,
      );
    } else if (value > 0) {
      final valAngle = _toRad(value);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        zeroAngle, valAngle - zeroAngle, false,
        Paint()
          ..color = const Color(0xFF2196F3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.butt,
      );
    }

    // 4. Zóna feliratok a műszer ívén kívül (REGEN, 0, MOTOR)
    final tp = TextPainter(textDirection: TextDirection.ltr);

    void drawLabel(String text, double angle, Color color) {
      final lr = radius + 14;
      tp.text = TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ));
      tp.layout();
      tp.paint(canvas, Offset(
        center.dx + lr * math.cos(angle) - tp.width / 2,
        center.dy + lr * math.sin(angle) - tp.height / 2,
      ));
    }

    drawLabel('REGEN', _startRad + regenSweep * 0.15, const Color(0xFF66BB6A));
    drawLabel('0', zeroAngle, const Color(0xFF9E9E9E));
    drawLabel('MOTOR', _startRad + _sweepRad * 0.85, const Color(0xFF64B5F6));

    // 5. Nullapont osztásjel az ívön
    canvas.drawLine(
      Offset(center.dx + (radius - 2) * math.cos(zeroAngle),
          center.dy + (radius - 2) * math.sin(zeroAngle)),
      Offset(center.dx + (radius - 12) * math.cos(zeroAngle),
          center.dy + (radius - 12) * math.sin(zeroAngle)),
      Paint()..color = Colors.white70..strokeWidth = 2,
    );

    // 6. Mutató tű és középső kör
    final pct = ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
    final needleAngle = _startRad + _sweepRad * pct;
    final nl = radius - 13;
    final tipX = center.dx + nl * math.cos(needleAngle);
    final tipY = center.dy + nl * math.sin(needleAngle);

    canvas.drawLine(
      center, Offset(tipX, tipY),
      Paint()..color = Colors.white..strokeWidth = 1.8..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(tipX, tipY), 3.5, Paint()..color = Colors.white);
    canvas.drawCircle(center, 6.0, Paint()..color = const Color(0xFF555555));
    canvas.drawCircle(center, 2.8, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PowerGaugePainter old) =>
      old.value != value ||
      old.regenBgColor != regenBgColor ||
      old.motorBgColor != motorBgColor;
}
