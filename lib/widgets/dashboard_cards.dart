import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const cardBg   = Color(0xFF1C1C1C);
const labelClr = Color(0xFF9E9E9E);
const dimClr   = Color(0xFF606060);
const trackClr = Color(0xFF3A3A3A);

double parseObd(String? val) {
  if (val == null || val == '--') return 0.0;
  return double.tryParse(val) ?? 0.0;
}

String fmtVal(double v, {int decimals = 0}) {
  if (v.isNaN || v.isInfinite) return '--';
  if (decimals == 0) return v.toInt().toString();
  return v.toStringAsFixed(decimals);
}

class DCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const DCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(10),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline, width: 1),
      ),
      padding: padding,
      child: child,
    );
  }
}

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
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.barColor,
    this.minLabel,
    this.maxLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final tt    = Theme.of(context).textTheme;
    final pct   = ((value - min) / (max - min)).clamp(0.0, 1.0);
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
                    style: TextStyle(
                        color: tt.bodySmall?.color ?? labelClr,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6)),
              ),
              Text(display,
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: AppTheme.trackColor(context),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          if (minLabel != null || maxLabel != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(minLabel ?? '',
                    style: TextStyle(color: tt.labelSmall?.color ?? dimClr, fontSize: 10)),
                Text(maxLabel ?? '',
                    style: TextStyle(color: tt.labelSmall?.color ?? dimClr, fontSize: 10)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class DashboardValueCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accentColor;

  const DashboardValueCard({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.accentColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return DCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(builder: (ctx) {
            final tt = Theme.of(ctx).textTheme;
            return Text(label,
                style: TextStyle(
                    color: tt.bodySmall?.color ?? labelClr,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6));
          }),
          const SizedBox(height: 6),
          Builder(builder: (ctx) {
            final tt = Theme.of(ctx).textTheme;
            return RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.0),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: '  $unit',
                    style: TextStyle(color: tt.bodySmall?.color ?? labelClr, fontSize: 12),
                  ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

class DashboardSectionTitle extends StatelessWidget {
  final String title;
  const DashboardSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(title,
          style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color ?? labelClr,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5)),
    );
  }
}

class DashboardStatusBar extends StatelessWidget {
  final String leftText;
  final String rightText;

  const DashboardStatusBar({
    super.key,
    required this.leftText,
    required this.rightText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 14),
          const SizedBox(width: 6),
          Text(leftText,
              style: TextStyle(color: tt.bodySmall?.color ?? labelClr, fontSize: 11)),
          const Spacer(),
          Text(rightText,
              style: TextStyle(color: tt.labelSmall?.color ?? dimClr, fontSize: 11)),
        ],
      ),
    );
  }
}

class TripItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const TripItem({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: tt.bodySmall?.color ?? labelClr,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(unit, style: TextStyle(color: tt.labelSmall?.color ?? dimClr, fontSize: 10)),
      ],
    );
  }
}
