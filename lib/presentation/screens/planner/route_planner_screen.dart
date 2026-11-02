import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/services/live_trip_service.dart';
import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/barik_icons.dart';
import 'package:bizkaia_transit/domain/models/live_trip_models.dart';
import 'package:bizkaia_transit/domain/repositories/transit_repository.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/widgets/ambient_glow_background.dart';

/// Step-by-Step Multi-Modal Route Planner with transfers and lock-screen follow trip action.
class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final _originController = TextEditingController(text: 'Moyua');
  final _destController = TextEditingController(text: 'Santurtzi');
  List<TransitItinerary>? _itineraries;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchRoutes();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  void _swapStops() {
    HapticFeedback.mediumImpact();
    final temp = _originController.text;
    _originController.text = _destController.text;
    _destController.text = temp;
    _searchRoutes();
  }

  Future<void> _pickStation({required bool isOrigin}) async {
    HapticFeedback.lightImpact();
    final repo = ref.read(transitRepositoryProvider);
    final stops = await repo.getStops();

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = query.isEmpty
                ? stops
                : stops
                    .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
                    .toList();

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: AppColors.darkBorderStrong, width: 1.5),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.darkBorderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isOrigin ? 'Seleccionar parada de origen' : 'Seleccionar parada de destino',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => setModalState(() => query = v.trim()),
                      style: const TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          BarikIcons.magnifyingGlass,
                          color: AppColors.darkTextSecondary,
                        ),
                        hintText: 'Buscar parada...',
                        hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
                        filled: true,
                        fillColor: AppColors.darkSurfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: AppColors.darkBorder,
                        ),
                        itemBuilder: (ctx, idx) {
                          final stop = filtered[idx];
                          return ListTile(
                            leading: Icon(
                              isOrigin ? BarikIcons.circle : BarikIcons.mapPin,
                              size: 16,
                              color: isOrigin ? AppColors.opMetroBilbao : AppColors.realtimeGreen,
                            ),
                            title: Text(
                              stop.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkTextPrimary,
                              ),
                            ),
                            subtitle: Text(
                              stop.operatorId.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.darkTextSecondary,
                              ),
                            ),
                            onTap: () {
                              if (isOrigin) {
                                _originController.text = stop.name;
                              } else {
                                _destController.text = stop.name;
                              }
                              Navigator.of(context).pop();
                              _searchRoutes();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _searchRoutes() async {
    setState(() => _isLoading = true);
    final repo = ref.read(transitRepositoryProvider);
    final results = await repo.planRoute(
      origin: _originController.text.trim(),
      destination: _destController.text.trim(),
    );
    setState(() {
      _itineraries = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AmbientGlowBackground(
      accentColor: AppColors.opMetroBilbao,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Tu ruta paso a paso',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Search Input Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.darkBorderStrong),
              ),
              child: Column(
                children: [
                  // Origin Input
                  TextField(
                    controller: _originController,
                    style: const TextStyle(
                      color: AppColors.darkTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        BarikIcons.circle,
                        color: AppColors.opMetroBilbao,
                        size: 14,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.list_alt_rounded, color: AppColors.darkTextSecondary, size: 20),
                        tooltip: 'Elegir parada de la lista',
                        onPressed: () => _pickStation(isOrigin: true),
                      ),
                      hintText: '¿Desde dónde sales?',
                      hintStyle: const TextStyle(
                        color: AppColors.darkTextSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.darkSurfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  // Swap Button
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.swap_vert_rounded, color: AppColors.darkTextPrimary),
                        tooltip: 'Intercambiar origen y destino',
                        onPressed: _swapStops,
                      ),
                    ),
                  ),

                  // Destination Input
                  TextField(
                    controller: _destController,
                    style: const TextStyle(
                      color: AppColors.darkTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        BarikIcons.mapPin,
                        color: AppColors.realtimeGreen,
                        size: 16,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.list_alt_rounded, color: AppColors.darkTextSecondary, size: 20),
                        tooltip: 'Elegir parada de la lista',
                        onPressed: () => _pickStation(isOrigin: false),
                      ),
                      hintText: '¿A dónde vas?',
                      hintStyle: const TextStyle(
                        color: AppColors.darkTextSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.darkSurfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _searchRoutes,
                      icon: const Icon(BarikIcons.magnifyingGlass),
                      label: const Text('Calcular ruta'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.opMetroBilbao,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(
                    color: AppColors.opMetroBilbao,
                  ),
                ),
              )
            else if (_itineraries != null && _itineraries!.isNotEmpty) ...[
              for (final itin in _itineraries!) ...[
                _ItineraryResultCard(itinerary: itin),
                const SizedBox(height: 16),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ItineraryResultCard extends ConsumerWidget {
  const _ItineraryResultCard({required this.itinerary});

  final TransitItinerary itinerary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours = itinerary.totalDurationMinutes ~/ 60;
    final mins = itinerary.totalDurationMinutes % 60;
    final durationStr =
        hours > 0 ? '${hours}h ${mins} min' : '$mins min';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.darkBorderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Duration + Transfer count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                durationStr,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkTextPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Text(
                  itinerary.transfersCount == 1
                      ? '1 transbordo'
                      : '${itinerary.transfersCount} transbordos',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Step by Step Legs
          for (int i = 0; i < itinerary.legs.length; i++) ...[
            _LegStepTile(
              leg: itinerary.legs[i],
              isLast: i == itinerary.legs.length - 1,
            ),
          ],

          const SizedBox(height: 18),

          // Follow trip button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final firstLeg = itinerary.legs.first;
                final hasPerm = await ref
                    .read(liveTripServiceProvider)
                    .requestPermission();

                final liveTrip = LiveTripState(
                  tripId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
                  operatorId: firstLeg.operatorId ?? 'metro',
                  mode: firstLeg.operatorId == 'metro' ? 'metro' : 'bus',
                  lineId: firstLeg.lineName ?? 'Línea',
                  lineName: firstLeg.lineName ?? 'Línea',
                  lineColor: firstLeg.lineColorHex ?? '#E8590C',
                  origin: itinerary.origin,
                  destination: itinerary.destination,
                  currentStop: firstLeg.originStopName,
                  nextStop: firstLeg.destStopName,
                  stopsRemaining: firstLeg.stopsCount,
                  progress: 0.1,
                  arrivalTime: itinerary.arrivalTime,
                  status: LiveTripStatus.tracking,
                  isRealtime: true,
                  delaySeconds: 0,
                  instruction: firstLeg.instruction,
                  updatedAt: DateTime.now(),
                );

                await ref
                    .read(activeLiveTripProvider.notifier)
                    .startTrip(liveTrip);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.darkSurfaceElevated,
                      content: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_rounded,
                            color: AppColors.realtimeGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              hasPerm
                                  ? 'Siguiendo ruta hacia ${itinerary.destination} en la pantalla de bloqueo'
                                  : 'Viaje iniciado. Para ver el progreso en bloqueo, activa las notificaciones.',
                              style: const TextStyle(
                                color: AppColors.darkTextPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(BarikIcons.navigationArrow),
              label: const Text('Voy a coger este viaje'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.opMetroBilbao,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegStepTile extends StatelessWidget {
  const _LegStepTile({
    required this.leg,
    required this.isLast,
  });

  final TransitLeg leg;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isTransit = leg.type == TransitLegType.transit;
    final legColor = isTransit
        ? (leg.lineColorHex != null
            ? Color(int.tryParse(leg.lineColorHex!.replaceAll('#', '0xFF')) ??
                0xFFE2001A)
            : AppColors.opMetroBilbao)
        : AppColors.darkTextSecondary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Pillar
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isTransit ? legColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: legColor,
                    width: isTransit ? 2 : 1.5,
                  ),
                ),
                child: !isTransit
                    ? const Icon(
                        BarikIcons.walk,
                        size: 8,
                        color: AppColors.darkTextSecondary,
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isTransit
                        ? legColor.withValues(alpha: 0.5)
                        : AppColors.darkBorderStrong,
                  ),
                ),
            ],
          ),

          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isTransit && leg.lineName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: legColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            leg.lineName!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          leg.instruction,
                          style: const TextStyle(
                            color: AppColors.darkTextPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTransit
                        ? '${leg.stopsCount} paradas · ${leg.durationMinutes} min'
                        : '${leg.durationMinutes} min a pie (${leg.distanceMeters ?? 150} m)',
                    style: const TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
