import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/trip_data.dart';
import '../services/locale_notifier.dart';
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
    if (!mounted) return;
    setState(() => _loading = true);
    final trips = await TripStorage.loadAll();
    if (!mounted) return;
    setState(() { _trips = trips; _loading = false; });
  }

  Future<void> _deleteTrip(String id) async {
    await TripStorage.delete(id);
    await _load();
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl = ctx.read<LocaleNotifier>().strings;
        return AlertDialog(
          title: Text(dl.deleteAll),
          content: Text(dl.confirmDeleteAll),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dl.cancel)),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(dl.delete,
                    style: const TextStyle(color: Colors.red))),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      await TripStorage.deleteAll();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LocaleNotifier>().strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tripLog),
        actions: [
          if (_trips.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: l10n.deleteAll,
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
    final l10n = context.read<LocaleNotifier>().strings;
    final cs   = Theme.of(context).colorScheme;
    final tt   = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_outlined, size: 72, color: cs.outline),
          const SizedBox(height: 16),
          Text(l10n.noTripsYet,
              style: TextStyle(color: tt.bodySmall?.color, fontSize: 16)),
          const SizedBox(height: 8),
          Text(l10n.tripsAutoRecorded,
              textAlign: TextAlign.center,
              style: TextStyle(color: tt.labelSmall?.color, fontSize: 13)),
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
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _sumItem(Icons.route, '${_trips.length}', context.read<LocaleNotifier>().strings.tripCountLabel),
          _sumItem(Icons.timer_outlined, '${h}h ${m}m', context.read<LocaleNotifier>().strings.totalLabel),
          _sumItem(Icons.electric_bolt, '${totalEnergy.toStringAsFixed(1)} kWh', context.read<LocaleNotifier>().strings.consumptionLabel),
        ],
      ),
    );
  }

  Widget _sumItem(IconData icon, String value, String label) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF42A5F5)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                color: cs.onSurface)),
        Text(label,
            style: TextStyle(fontSize: 11, color: tt.bodySmall?.color)),
      ],
    );
  }
}

// ── Meneten kártyawidget ──────────────────────────────────────────────────────

class _TripCard extends StatefulWidget {
  final TripRecord trip;
  final VoidCallback onDelete;

  const _TripCard({required this.trip, required this.onDelete});

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _expanded = false;

  TripRecord get trip => widget.trip;

  /// Akkor igaz, ha a meneten van legalább 2 GPS pont — térkép megjelenítéséhez kell.
  bool get _hasRoute => trip.route.length >= 2;

  @override
  Widget build(BuildContext context) {
    final dur = trip.duration;
    final durStr = trip.isActive
        ? '–'
        : (dur.inHours > 0
            ? '${dur.inHours}h ${dur.inMinutes.remainder(60)}m'
            : dur.inMinutes > 0
                ? '${dur.inMinutes}m ${dur.inSeconds.remainder(60)}s'
                : '${dur.inSeconds}s');

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
          builder: (ctx) {
            final dl = ctx.read<LocaleNotifier>().strings;
            return AlertDialog(
              content: Text(dl.confirmDeleteTrip),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(dl.cancel)),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(dl.delete,
                        style: const TextStyle(color: Colors.red))),
              ],
            );
          },
        );
      },
      onDismissed: (_) => widget.onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Kártya tartalom (tappintható, ha van útvonal) ──────────────
            InkWell(
              onTap: _hasRoute
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fejléc: dátum + jelvények + időtartam + chevron
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
                                color: const Color(0xFFE65100),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                  context.read<LocaleNotifier>().strings.interrupted,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          Builder(builder: (ctx) {
                            final cs = Theme.of(ctx).colorScheme;
                            final tt = Theme.of(ctx).textTheme;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cs.outline),
                              ),
                              child: Text(durStr,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: tt.bodySmall?.color)),
                            );
                          }),
                          // Útvonal ikon + chevron ha van GPS adat
                          if (_hasRoute) ...[
                            const SizedBox(width: 8),
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(Icons.expand_more,
                                  size: 20, color: Color(0xFF42A5F5)),
                            ),
                          ],
                        ]),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // SOC + energia sor
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
                            style: TextStyle(fontSize: 12, color: socColor)),
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

                    // Sebesség + távolság sor
                    if (trip.maxSpeedKmh > 1) ...[
                      const SizedBox(height: 6),
                      Builder(builder: (ctx) {
                        final dl = ctx.read<LocaleNotifier>().strings;
                        return Row(children: [
                          const Icon(Icons.speed, size: 16, color: Colors.blue),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${dl.maxLabel} ${trip.maxSpeedKmh.toStringAsFixed(0)} km/h'
                              '  •  ${dl.avgLabel} ${trip.avgSpeedKmh.toStringAsFixed(0)} km/h'
                              '${trip.distanceKm > 0.5 ? '  •  ${trip.distanceKm.toStringAsFixed(1)} km' : ''}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ]);
                      }),
                    ],

                    // Fogyasztás sor
                    if (trip.whPerKm > 50) ...[
                      const SizedBox(height: 6),
                      Builder(builder: (ctx) {
                        final dl = ctx.read<LocaleNotifier>().strings;
                        return Row(children: [
                          const Icon(Icons.electric_meter, size: 16,
                              color: Colors.deepPurple),
                          const SizedBox(width: 5),
                          Text(
                            '${dl.tripConsumptionPrefix} ${trip.whPerKm.toStringAsFixed(0)} Wh/km'
                            '${trip.distanceKm > 0.5 ? '  •  ${(trip.whPerKm * trip.distanceKm / 100).toStringAsFixed(2)} kWh/100km' : ''}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ]);
                      }),
                    ],

                    // GPS pontok száma (ha van útvonal)
                    if (_hasRoute) ...[
                      const SizedBox(height: 6),
                      Builder(builder: (ctx) {
                        final dl = ctx.read<LocaleNotifier>().strings;
                        return Row(children: [
                          const Icon(Icons.route, size: 15,
                              color: Color(0xFF42A5F5)),
                          const SizedBox(width: 5),
                          Text(
                            '${dl.gpsPointsRecorded(trip.route.length)}'
                            '  •  ${dl.tapForMap}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF42A5F5)),
                          ),
                        ]);
                      }),
                    ],

                    const SizedBox(height: 6),
                    Text(trip.vehicleName,
                        style: TextStyle(
                            color: Theme.of(context).textTheme.labelSmall?.color,
                            fontSize: 12)),
                  ],
                ),
              ),
            ),

            // ── Kinyíló térkép ─────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: _expanded && _hasRoute
                  ? _buildRouteMap(trip.route)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// OpenStreetMap-alapú útvonal térkép, 240 px magas.
  /// A kamera automatikusan beáll az útvonal összes pontját befogadva.
  Widget _buildRouteMap(List<TripLatLng> route) {
    final points = route
        .map((p) => LatLng(p.lat, p.lng))
        .toList();

    // Határdoboz a kamera beállításához
    final bounds = LatLngBounds.fromPoints(points);

    return SizedBox(
      height: 240,
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(36),
            minZoom: 4,
            maxZoom: 17,
          ),
          // Lista görgetéssel ne ütközzön — pan tiltva, zoom engedve
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
          ),
        ),
        children: [
          // OpenStreetMap csempék (nincs API kulcs szükséges)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.obdreader2',
            maxZoom: 19,
          ),
          // Útvonal vonal
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 4.5,
                color: const Color(0xFF1E88E5),
              ),
            ],
          ),
          // Start és végpont jelölők
          MarkerLayer(
            markers: [
              Marker(
                point: points.first,
                width: 28, height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF43A047),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 14),
                ),
              ),
              Marker(
                point: points.last,
                width: 28, height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.stop,
                      color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          // Jelmagyarázat (bal alsó sarok)
          Builder(builder: (ctx) {
            final dl = ctx.read<LocaleNotifier>().strings;
            return Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 14, height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5),
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text(dl.routeLegend, style: const TextStyle(
                        color: Colors.white, fontSize: 10)),
                    const SizedBox(width: 8),
                    Container(width: 10, height: 10,
                        decoration: const BoxDecoration(
                            color: Color(0xFF43A047), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(dl.tripStartLabel, style: const TextStyle(
                        color: Colors.white, fontSize: 10)),
                    const SizedBox(width: 8),
                    Container(width: 10, height: 10,
                        decoration: const BoxDecoration(
                            color: Color(0xFFE53935), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(dl.tripEndLabel, style: const TextStyle(
                        color: Colors.white, fontSize: 10)),
                  ]),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _p2(int v) => v.toString().padLeft(2, '0');
}
