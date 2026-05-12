// lib/widgets/cell_voltage_grid.dart
//
// 96 cella feszültség rács — szín alapú vizualizáció.
// Szín az átlagtól való eltérés alapján (mV):
//   < 10 mV : zöld   (egészséges)
//   10–25 mV: sárga
//   25–50 mV: narancs
//   > 50 mV : piros  (figyelmet igényel)

import 'package:flutter/material.dart';

class CellVoltageGrid extends StatelessWidget {
  final List<double> voltages;

  const CellVoltageGrid({Key? key, required this.voltages}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (voltages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('Cella adatok gyűjtése...',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      );
    }

    final avg = voltages.fold(0.0, (s, v) => s + v) / voltages.length;
    final min = voltages.reduce((a, b) => a < b ? a : b);
    final max = voltages.reduce((a, b) => a > b ? a : b);
    final spread = (max - min) * 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fejléc: stats
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('Min', '${min.toStringAsFixed(3)} V', Colors.lightBlue),
              _stat('Átl', '${avg.toStringAsFixed(3)} V', Colors.white),
              _stat('Max', '${max.toStringAsFixed(3)} V', Colors.orange),
              _stat('Δ', '${spread.toStringAsFixed(0)} mV',
                  spread > 50
                      ? Colors.red
                      : spread > 20
                          ? Colors.orange
                          : const Color(0xFF66BB6A)),
            ],
          ),
        ),
        // Rács
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              childAspectRatio: 1.15,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemCount: voltages.length,
            itemBuilder: (_, i) {
              final v = voltages[i];
              final devMv = ((v - avg) * 1000).round();
              final absDevMv = devMv.abs();
              final cellColor = absDevMv < 10
                  ? const Color(0xFF4CAF50)
                  : absDevMv < 25
                      ? const Color(0xFFFFEB3B)
                      : absDevMv < 50
                          ? const Color(0xFFFF9800)
                          : Colors.red;

              return Tooltip(
                message: 'C${i + 1}: ${v.toStringAsFixed(3)} V\n'
                    '${devMv >= 0 ? "+" : ""}$devMv mV az átlagtól',
                child: Container(
                  decoration: BoxDecoration(
                    color: cellColor.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Center(
                    child: Text(
                      '${devMv >= 0 ? "+" : ""}$devMv',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Jelmagyarázat
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(const Color(0xFF4CAF50), '<10 mV'),
              const SizedBox(width: 10),
              _legend(const Color(0xFFFFEB3B), '10–25'),
              const SizedBox(width: 10),
              _legend(const Color(0xFFFF9800), '25–50'),
              const SizedBox(width: 10),
              _legend(Colors.red, '>50 mV'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF888888), fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      );

  Widget _legend(Color color, String label) => Row(
        children: [
          Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 9)),
        ],
      );
}
