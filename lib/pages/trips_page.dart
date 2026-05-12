// lib/pages/trips_page.dart
//
// Menetnapló oldal — rögzített EV menetek listája.

import 'package:flutter/material.dart';

import '../models/trip_data.dart';
import '../services/trip_storage.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  List<TripRecord> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final trips = await TripStorage.loadAll();
    if (mounted) setState(() { _trips = trips; _loading = false; });
  }

  Future<void> _deleteTrip(String id) async {
    await TripStorage.delete(id);
    _load();
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Összes törlése'),
        content: const Text('Biztosan törlöd az összes rögzített menetet?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Mégsem')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Törlés',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await TripStorage.deleteAll();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menetnapló'),
        actions: [
          if (_trips.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Összes törlése',
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(children: [
                    _buildSummaryBar(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _trips.length,
                        itemBuilder: (_, i) => _TripCard(
                          trip: _trips[i],
                          onDelete: () => _deleteTrip(_trips[i].id),
                        ),
                      ),
                    ),
                  ]),
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_outlined, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Text('Nincs még rögzített menet.',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          SizedBox(height: 8),
          Text('A menetek OBD kapcsolódás után automatikusan\nkerülnek rögzítésre.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final completed = _trips.where((t) => !t.isActive).toList();
    final totalEnergy =
        completed.fold(0.0, (s, t) => s + t.energyKwh);
    final totalDur =
        completed.fold(Duration.zero, (s, t) => s + t.duration);
    final h = totalDur.inHours;
    final m = totalDur.inMinutes.remainder(60);

    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _sumItem(Icons.route, '${_trips.length}', 'menet'),
          _sumItem(Icons.timer_outlined, '${h}h ${m}m', 'összesen'),
          _sumItem(Icons.electric_bolt, '${totalEnergy.toStringAsFixed(1)} kWh', 'fogyasztás'),
        ],
      ),
    );
  }

  Widget _sumItem(IconData icon, String value, String label) => Column(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}

// ── Trip kártya ─────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final TripRecord trip;
  final VoidCallback onDelete;

  const _TripCard({required this.trip, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dur = trip.duration;
    final durStr = dur.inHours > 0
        ? '${dur.inHours}h ${dur.inMinutes.remainder(60)}m'
        : dur.inMinutes > 0
            ? '${dur.inMinutes}m ${dur.inSeconds.remainder(60)}s'
            : '${dur.inSeconds}s';

    final dt = trip.startedAt;
    final dateStr =
        '${dt.year}.${_p2(dt.month)}.${_p2(dt.day)}  ${_p2(dt.hour)}:${_p2(dt.minute)}';

    final socDrop = trip.socUsed;
    final socColor = socDrop > 20
        ? Colors.orange
        : socDrop > 5
            ? Colors.green
            : Colors.grey;

    return Dismissible(
      key: Key(trip.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: const Text('Törli ezt a menetet?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Mégsem')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Törlés',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Fejléc: dátum + időtartam ─────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateStr,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Row(children: [
                    if (trip.isActive)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('ÉLŐ',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(durStr,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 10),

              // ── SOC változás ──────────────────────────────────────────
              Row(children: [
                Icon(Icons.battery_charging_full,
                    size: 16, color: socColor),
                const SizedBox(width: 5),
                Text(
                  '${trip.startSoc.toStringAsFixed(0)}%'
                  ' → ${trip.endSoc.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 14),
                ),
                if (socDrop > 0.5) ...[
                  const SizedBox(width: 6),
                  Text('(−${socDrop.toStringAsFixed(0)}%)',
                      style: TextStyle(
                          fontSize: 12, color: socColor)),
                ],
                if (trip.energyKwh > 0.05) ...[
                  const SizedBox(width: 14),
                  const Icon(Icons.electric_bolt,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text('${trip.energyKwh.toStringAsFixed(2)} kWh',
                      style: const TextStyle(fontSize: 14)),
                ],
              ]),

              // ── Sebesség + távolság ───────────────────────────────────
              if (trip.maxSpeedKmh > 1) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.speed, size: 16, color: Colors.blue),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Max: ${trip.maxSpeedKmh.toStringAsFixed(0)} km/h'
                      '  •  Átlag: ${trip.avgSpeedKmh.toStringAsFixed(0)} km/h'
                      '${trip.distanceKm > 0.5 ? '  •  ${trip.distanceKm.toStringAsFixed(1)} km' : ''}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ]),
              ],

              // ── Mért fogyasztás ───────────────────────────────────────
              if (trip.whPerKm > 50) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.electric_meter, size: 16,
                      color: Colors.deepPurple),
                  const SizedBox(width: 5),
                  Text(
                    'Fogyasztás: ${trip.whPerKm.toStringAsFixed(0)} Wh/km'
                    '${trip.distanceKm > 0.5 ? '  •  ${(trip.whPerKm * trip.distanceKm / 100).toStringAsFixed(2)} kWh/100km' : ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ]),
              ],

              // ── Jármű ────────────────────────────────────────────────
              const SizedBox(height: 6),
              Text(trip.vehicleName,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  String _p2(int v) => v.toString().padLeft(2, '0');
}
