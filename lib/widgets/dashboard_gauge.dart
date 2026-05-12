// lib/widgets/dashboard_gauge.dart
//
// Analóg tűs műszerek OBD-II adatokhoz.
// OBDNeedleGauge – általános (RPM, sebesség)
// OBDPowerGauge  – EV teljesítmény (REGEN / MOTOR zónákkal)

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Színzóna definíció ─────────────────────────────────────────────────────

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

// ── Általános analóg tűs műszer ────────────────────────────────────────────

class OBDNeedleGauge extends StatelessWidget {
  final String title;
  final double value;
  final double minValue;
  final double maxValue;
  final String unit;
  final List<GaugeZone> zones;
  final List<double> tickValues;

  const OBDNeedleGauge({
    Key? key,
    required this.title,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.unit,
    this.zones = const [],
    this.tickValues = const [],
  }) : super(key: key);

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
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
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
              ),
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: _fmt(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                TextSpan(
                  text: '  $unit',
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
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

  // 270° ív: 135°-tól (7:30) indul, 270° CW sweepel
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
  });

  double _toRad(double v) {
    final pct = ((v - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
    return _startRad + _sweepRad * pct;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.50;
    final center = Offset(cx, cy);
    final radius = math.min(size.width * 0.41, size.height * 0.55);

    // 1. Háttér ív
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startRad, _sweepRad, false,
      Paint()
        ..color = const Color(0xFF3A3A3A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.butt,
    );

    // 2. Színzónák
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

    // 3. Jelölők és feliratok
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

    // 4. Mutató tű
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
      old.value != value || old.minValue != minValue || old.maxValue != maxValue;
}

// ── EV Teljesítmény műszer (REGEN / MOTOR) ─────────────────────────────────

class OBDPowerGauge extends StatelessWidget {
  final double value; // kW, negatív = rekuperáció
  final double minValue; // pl. -60
  final double maxValue; // pl. 150

  const OBDPowerGauge({
    Key? key,
    required this.value,
    this.minValue = -60,
    this.maxValue = 150,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sign = value > 0 ? '+' : '';
    final valueColor = value < 0
        ? const Color(0xFF66BB6A)
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'TELJESÍTMÉNY',
            style: TextStyle(
              color: Color(0xFF9E9E9E),
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
                const TextSpan(
                  text: '  kW',
                  style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
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

  // startAngle=210°, sweepAngle=210° → 0kW pontosan a tetőn (270°=12 óra)
  static const _startRad = 210.0 * math.pi / 180.0;
  static const _sweepRad = 210.0 * math.pi / 180.0;

  const _PowerGaugePainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
  });

  double _toRad(double v) {
    final pct = ((v - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
    return _startRad + _sweepRad * pct;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.50;
    final center = Offset(cx, cy);
    final radius = math.min(size.width * 0.41, size.height * 0.55);

    final zeroAngle = _toRad(0.0);
    final regenSweep = zeroAngle - _startRad;
    final motorSweep = _sweepRad - regenSweep;

    // 1. REGEN háttér (sötétzöld)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startRad, regenSweep, false,
      Paint()
        ..color = const Color(0xFF1B3A1B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.butt,
    );

    // 2. MOTOR háttér (sötétkék)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      zeroAngle, motorSweep, false,
      Paint()
        ..color = const Color(0xFF0D1F3A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.butt,
    );

    // 3. Aktív kiemelés az aktuális értékig
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

    // 4. Feliratok (REGEN, 0, MOTOR)
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

    // 5. 0-jelölő tick
    canvas.drawLine(
      Offset(center.dx + (radius - 2) * math.cos(zeroAngle),
          center.dy + (radius - 2) * math.sin(zeroAngle)),
      Offset(center.dx + (radius - 12) * math.cos(zeroAngle),
          center.dy + (radius - 12) * math.sin(zeroAngle)),
      Paint()..color = Colors.white70..strokeWidth = 2,
    );

    // 6. Mutató tű
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
  bool shouldRepaint(_PowerGaugePainter old) => old.value != value;
}
