// lib/widgets/dashboard_cards.dart
//
// Újrahasználható kártya widgetek az ICE és EV műszerfalakhoz.

import 'package:flutter/material.dart';

const cardBg = Color(0xFF1C1C1C);
const labelClr = Color(0xFF9E9E9E);
const dimClr = Color(0xFF606060);
const trackClr = Color(0xFF3A3A3A);

/// OBD string → double.
double parseObd(String? val) {
  if (val == null || val == '--') return 0.0;
  return double.tryParse(val) ?? 0.0;
}

/// double → megjelenítési string.
String fmtVal(double v, {int decimals = 0}) {
  if (v.isNaN || v.isInfinite) return '--';
  if (decimals == 0) return v.toInt().toString();
  return v.toStringAsFixed(decimals);
}

// ── Sötét kártya wrapper ─────────────────────────────────────────────────

class DCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const DCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: padding,
      child: child,
    );
  }
}

// ── Sáv kártya: címke + érték + vízszintes sáv ──────────────────────────

class DashboardBarCard extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final Color barColor;
  final String? minLabel;
  final String? maxLabel;

  const DashboardBarCard({
    Key? key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.barColor,
    this.minLabel,
    this.maxLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final display = '${fmtVal(value)} $unit';

    return DCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: labelClr,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
              ),
              Text(display,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: trackClr,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          if (minLabel != null || maxLabel != null) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(minLabel ?? '',
                    style: const TextStyle(color: dimClr, fontSize: 8)),
                Text(maxLabel ?? '',
                    style: const TextStyle(color: dimClr, fontSize: 8)),
              ],
            ),
          ],
        ],
      ),
    );
  }

}

// ── Érték kártya: címke + nagy érték ─────────────────────────────────────

class DashboardValueCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accentColor;

  const DashboardValueCard({
    Key? key,
    required this.label,
    required this.value,
    this.unit = '',
    this.accentColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  color: labelClr,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: value,
                style: TextStyle(
                    color: accentColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.0),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: '  $unit',
                  style: const TextStyle(color: labelClr, fontSize: 11),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Szekció cím ──────────────────────────────────────────────────────────

class DashboardSectionTitle extends StatelessWidget {
  final String title;
  const DashboardSectionTitle(this.title, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(title,
          style: const TextStyle(
              color: labelClr,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5)),
    );
  }
}

// ── Állapotsor (alul) ────────────────────────────────────────────────────

class DashboardStatusBar extends StatelessWidget {
  final String leftText;
  final String rightText;

  const DashboardStatusBar({
    Key? key,
    required this.leftText,
    required this.rightText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 14),
          const SizedBox(width: 6),
          Text(leftText,
              style: const TextStyle(color: labelClr, fontSize: 10)),
          const Spacer(),
          Text(rightText,
              style: const TextStyle(color: dimClr, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Fedélzeti computer elem ──────────────────────────────────────────────

class TripItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const TripItem({
    Key? key,
    required this.label,
    required this.value,
    required this.unit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: labelClr, fontSize: 9, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        Text(unit, style: const TextStyle(color: dimClr, fontSize: 9)),
      ],
    );
  }
}
