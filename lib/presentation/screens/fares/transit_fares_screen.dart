import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/aurora_background.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/glass_surface.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/motion.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/shapes.dart';

/// Available passenger discount profiles across Euskadi (Barik, MUGI, BAT).
enum FareProfile {
  standard('Estándar', 'Tarifa monedero general'),
  gizatrans('Social / Gizatrans', 'Mayores de 65 años o personas con discapacidad'),
  largeFamily20('F. Numerosa (F20)', '20% bonificación Familia Numerosa General'),
  largeFamily50('F. Numerosa (F50)', '50% bonificación Familia Numerosa Especial'),
  under12('Menores 12 años', '100% bonificación gratuita en toda la red');

  const FareProfile(this.label, this.description);
  final String label;
  final String description;
}

/// Fare calculation breakdown containing prices, zone jump, and potential savings.
class FareCalculation {
  const FareCalculation({
    required this.operator,
    required this.territory,
    required this.cardName,
    required this.zonesCount,
    required this.barikPrice,
    required this.occasionalPrice,
    required this.profile,
    required this.notes,
    required this.isFlatFare,
  });

  final TransitOperator operator;
  final TransitTerritory territory;
  final String cardName;
  final int zonesCount;
  final double barikPrice;
  final double occasionalPrice;
  final FareProfile profile;
  final String notes;
  final bool isFlatFare;

  double get savings => occasionalPrice > barikPrice ? occasionalPrice - barikPrice : 0.0;
  int get savingsPercentage => occasionalPrice > 0
      ? ((savings / occasionalPrice) * 100).round()
      : 0;
}

/// Interactive Multi-Modal Fare Consultation & Calculator screen.
/// Compares official Barik (Bizkaia), MUGI (Gipuzkoa) and BAT (Álava) prices
/// with single occasional tickets across all operators of Euskadi.
class TransitFaresScreen extends ConsumerStatefulWidget {
  const TransitFaresScreen({super.key});

  @override
  ConsumerState<TransitFaresScreen> createState() => _TransitFaresScreenState();
}

class _TransitFaresScreenState extends ConsumerState<TransitFaresScreen> {
  TransitTerritory _selectedTerritory = TransitTerritory.bizkaia;
  TransitOperator _selectedOperator = TransitOperator.metro;
  Stop? _originStop;
  Stop? _destStop;
  int _manualZones = 1;
  FareProfile _selectedProfile = FareProfile.standard;
  bool _useCustomStops = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final curTerritory = ref.read(selectedTerritoryProvider);
      if (curTerritory != TransitTerritory.all) {
        setState(() {
          _selectedTerritory = curTerritory;
          _selectedOperator = _defaultOperatorForTerritory(curTerritory);
        });
      }
    });
  }

  TransitOperator _defaultOperatorForTerritory(TransitTerritory territory) {
    return switch (territory) {
      TransitTerritory.bizkaia => TransitOperator.metro,
      TransitTerritory.gipuzkoa => TransitOperator.dbus,
      TransitTerritory.araba => TransitOperator.tuvisa,
      TransitTerritory.all => TransitOperator.metro,
    };
  }

  List<TransitOperator> _operatorsForTerritory(TransitTerritory territory) {
    return switch (territory) {
      TransitTerritory.bizkaia => const [
          TransitOperator.metro,
          TransitOperator.bizkaibus,
          TransitOperator.bilbobus,
          TransitOperator.renfe,
          TransitOperator.euskotren,
          TransitOperator.tranbiaBilbao,
          TransitOperator.pteColgante,
          TransitOperator.artxanda,
        ],
      TransitTerritory.gipuzkoa => const [
          TransitOperator.dbus,
          TransitOperator.lurraldebus,
          TransitOperator.euskotren,
        ],
      TransitTerritory.araba => const [
          TransitOperator.tuvisa,
          TransitOperator.alavabus,
          TransitOperator.tranbiaGasteiz,
        ],
      TransitTerritory.all => const [
          TransitOperator.metro,
          TransitOperator.bizkaibus,
          TransitOperator.bilbobus,
          TransitOperator.renfe,
          TransitOperator.euskotren,
        ],
    };
  }

  String _cardNameForTerritory(TransitTerritory territory) {
    return switch (territory) {
      TransitTerritory.bizkaia => 'Barik',
      TransitTerritory.gipuzkoa => 'MUGI',
      TransitTerritory.araba => 'BAT',
      TransitTerritory.all => 'Barik / MUGI / BAT',
    };
  }

  bool _isFlatFareOperator(TransitOperator op) {
    return op == TransitOperator.bilbobus ||
        op == TransitOperator.tuvisa ||
        op == TransitOperator.dbus ||
        op == TransitOperator.tranbiaBilbao ||
        op == TransitOperator.tranbiaGasteiz ||
        op == TransitOperator.artxanda ||
        op == TransitOperator.pteColgante;
  }

  @override
  Widget build(BuildContext context) {
    final activeStopsAsync = ref.watch(stopsForActiveOperatorProvider);
    final currentOperatorColor = Color(_selectedOperator.colorHex);
    final calculation = _computeFare();

    return AuroraBackground(
      accent: currentOperatorColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              expandedHeight: 110,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                title: Text(
                  'Tarifas y Tarjetas',
                  style: AppTypography.textTheme().displayMedium!.copyWith(
                    color: AppColors.darkTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.darkTextSecondary,
                  ),
                  tooltip: 'Licencias y atribución de datos',
                  onPressed: () => context.go('/fares/licenses'),
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Main Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Territory Selector Tabs (Bizkaia / Gipuzkoa / Álava)
                    _buildTerritorySelector(),
                    const SizedBox(height: 14),

                    // Operator Selector Pills
                    _buildOperatorSelector(),
                    const SizedBox(height: 18),

                    // Connected Stop / Route Calculator Card
                    _buildCalculatorCard(activeStopsAsync),
                    const SizedBox(height: 18),

                    // Fare Result Hero Card
                    _buildFareResultCard(calculation),
                    const SizedBox(height: 18),

                    // Interoperability & Transfer Card
                    _buildInteroperabilityCard(calculation.cardName),
                    const SizedBox(height: 18),

                    // Full Zone Matrix Table
                    _buildZoneTableCard(),
                    const SizedBox(height: 32),

                    // Legal Footnote
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.gavel_rounded, size: 16, color: AppColors.darkTextTertiary),
                        label: Text(
                          'Tarifas oficiales Euskadi · ${_cardNameForTerritory(_selectedTerritory)}',
                          style: const TextStyle(color: AppColors.darkTextTertiary, fontSize: 12),
                        ),
                        onPressed: () => context.go('/fares/licenses'),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Territory Selector with dedicated pills for Bizkaia, Gipuzkoa, and Araba.
  Widget _buildTerritorySelector() {
    final territories = [
      (TransitTerritory.bizkaia, 'Bizkaia', 'Barik'),
      (TransitTerritory.gipuzkoa, 'Gipuzkoa', 'MUGI'),
      (TransitTerritory.araba, 'Álava', 'BAT'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: territories.map((item) {
          final isSelected = item.$1 == _selectedTerritory;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (isSelected) return;
                HapticFeedback.selectionClick();
                final newOp = _defaultOperatorForTerritory(item.$1);
                setState(() {
                  _selectedTerritory = item.$1;
                  _selectedOperator = newOp;
                  _originStop = null;
                  _destStop = null;
                  _manualZones = 1;
                });
                ref.read(selectedTerritoryProvider.notifier).state = item.$1;
                ref.read(selectedOperatorProvider.notifier).state = newOp;
              },
              child: AnimatedContainer(
                duration: Motion.snappy.duration,
                curve: Motion.snappy.curve,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.darkSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1.2)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.$2,
                      style: TextStyle(
                        color: isSelected ? AppColors.darkTextPrimary : AppColors.darkTextSecondary,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.$3,
                      style: TextStyle(
                        color: isSelected ? AppColors.accent : AppColors.darkTextTertiary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOperatorSelector() {
    final operators = _operatorsForTerritory(_selectedTerritory);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: operators.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final op = operators[i];
          final selected = op == _selectedOperator;
          final color = Color(op.colorHex);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedOperator = op;
                _originStop = null;
                _destStop = null;
                _manualZones = 1;
              });
              ref.read(selectedOperatorProvider.notifier).state = op;
            },
            child: AnimatedContainer(
              duration: Motion.snappy.duration,
              curve: Motion.snappy.curve,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: ShapeDecoration(
                color: selected ? color.withValues(alpha: 0.22) : AppColors.darkSurface,
                shape: continuousShape(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: selected ? color : AppColors.darkBorder,
                    width: selected ? 1.5 : 1.0,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    op.name,
                    style: TextStyle(
                      color: selected ? AppColors.darkTextPrimary : AppColors.darkTextSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalculatorCard(AsyncValue<List<Stop>> activeStopsAsync) {
    final isFlat = _isFlatFareOperator(_selectedOperator);

    return GlassSurface(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calculador de trayecto',
                style: AppTypography.textTheme().titleMedium?.copyWith(
                      color: AppColors.darkTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (!isFlat)
                Row(
                  children: [
                    Text(
                      _useCustomStops ? 'Por paradas' : 'Por zonas',
                      style: const TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Switch.adaptive(
                      value: _useCustomStops,
                      activeColor: Color(_selectedOperator.colorHex),
                      onChanged: (val) {
                        setState(() => _useCustomStops = val);
                      },
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Tarifa plana',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Flat Fare Banner or Connected Stop Selector
          if (isFlat)
            _buildFlatFareBanner()
          else if (_useCustomStops)
            activeStopsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
              error: (_, __) => _buildManualZoneSelector(),
              data: (stops) => _buildConnectedStopSelector(stops),
            )
          else
            _buildManualZoneSelector(),

          const SizedBox(height: 18),

          // Passenger Profile Selector
          Text(
            'Perfil de viajero',
            style: AppTypography.textTheme().labelMedium?.copyWith(
                  color: AppColors.darkTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FareProfile.values.map((profile) {
              final selected = profile == _selectedProfile;
              return ChoiceChip(
                label: Text(profile.label),
                selected: selected,
                selectedColor: Color(_selectedOperator.colorHex).withValues(alpha: 0.3),
                backgroundColor: AppColors.darkSurfaceElevated,
                labelStyle: TextStyle(
                  color: selected ? AppColors.darkTextPrimary : AppColors.darkTextSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedProfile = profile);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatFareBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(_selectedOperator.colorHex).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.confirmation_number_outlined,
              color: Color(_selectedOperator.colorHex),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tarifa única en ${_selectedOperator.name}',
                  style: const TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'El precio es fijo en toda la red municipal/flota, sin importar el origen ni el destino.',
                  style: TextStyle(
                    color: AppColors.darkTextSecondary.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Visually connected stop selector with origin/destination indicators and swap button.
  Widget _buildConnectedStopSelector(List<Stop> stops) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.darkBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Vertical Route Track Indicator
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent.shade400,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              Container(
                width: 2,
                height: 38,
                color: AppColors.darkBorderStrong,
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.disruptedRed,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Stop Pickers (Origin & Destination)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStopTile(
                  isOrigin: true,
                  stop: _originStop,
                  onTap: () => _openStopPicker(
                    context: context,
                    isOrigin: true,
                    stops: stops,
                  ),
                ),
                const Divider(color: AppColors.darkBorder, height: 16),
                _buildStopTile(
                  isOrigin: false,
                  stop: _destStop,
                  onTap: () => _openStopPicker(
                    context: context,
                    isOrigin: false,
                    stops: stops,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Swap and Clear Actions
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.swap_vert_rounded, color: AppColors.darkTextPrimary),
                tooltip: 'Invertir paradas',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.darkSurface,
                  padding: const EdgeInsets.all(8),
                ),
                onPressed: (_originStop != null || _destStop != null)
                    ? () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          final tmp = _originStop;
                          _originStop = _destStop;
                          _destStop = tmp;
                        });
                      }
                    : null,
              ),
              if (_originStop != null || _destStop != null)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, color: AppColors.darkTextTertiary, size: 18),
                  tooltip: 'Borrar selección',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _originStop = null;
                      _destStop = null;
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStopTile({
    required bool isOrigin,
    required Stop? stop,
    required VoidCallback onTap,
  }) {
    final hasSelection = stop != null;
    final zone = stop?.zoneId ?? (stop != null ? _guessZone(stop) : null);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isOrigin ? 'ORIGEN' : 'DESTINO',
                  style: const TextStyle(
                    color: AppColors.darkTextTertiary,
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (zone != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Text(
                      'Zona $zone',
                      style: const TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              hasSelection ? stop.name : (isOrigin ? 'Elegir origen...' : 'Elegir destino...'),
              style: TextStyle(
                color: hasSelection ? AppColors.darkTextPrimary : AppColors.darkTextTertiary,
                fontWeight: hasSelection ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Opens an interactive search modal bottom sheet for picking stops.
  void _openStopPicker({
    required BuildContext context,
    required bool isOrigin,
    required List<Stop> stops,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final trimmed = query.trim().toLowerCase();
            final filtered = trimmed.isEmpty
                ? stops
                : stops.where((s) {
                    return s.name.toLowerCase().contains(trimmed) ||
                        s.code.toLowerCase().contains(trimmed);
                  }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              decoration: const BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: AppColors.darkBorderStrong, width: 1.5),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.darkBorderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color(_selectedOperator.colorHex).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isOrigin ? Icons.trip_origin_rounded : Icons.location_on_rounded,
                            color: isOrigin ? Colors.greenAccent : AppColors.disruptedRed,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isOrigin
                                ? 'Seleccionar origen · ${_selectedOperator.name}'
                                : 'Seleccionar destino · ${_selectedOperator.name}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search TextField
                    TextField(
                      autofocus: stops.length > 8,
                      onChanged: (v) => setModalState(() => query = v),
                      style: const TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.darkTextSecondary,
                          size: 20,
                        ),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  size: 18,
                                  color: AppColors.darkTextSecondary,
                                ),
                                onPressed: () => setModalState(() => query = ''),
                              )
                            : null,
                        hintText: 'Buscar estación o parada...',
                        hintStyle: const TextStyle(
                          color: AppColors.darkTextTertiary,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.darkSurfaceElevated,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.darkBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.darkBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Color(_selectedOperator.colorHex)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Stops List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.search_off_rounded,
                                    size: 40,
                                    color: AppColors.darkTextTertiary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No se encontraron paradas con "$query"',
                                    style: const TextStyle(
                                      color: AppColors.darkTextSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Color(0x14FFFFFF),
                                height: 1,
                              ),
                              itemBuilder: (ctx, i) {
                                final stop = filtered[i];
                                final isSelected = isOrigin
                                    ? _originStop?.id == stop.id
                                    : _destStop?.id == stop.id;
                                final zone = stop.zoneId ?? _guessZone(stop);

                                return ListTile(
                                  dense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Color(_selectedOperator.colorHex).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _modeIcon(stop.mode),
                                      color: Color(_selectedOperator.colorHex),
                                      size: 16,
                                    ),
                                  ),
                                  title: Text(
                                    stop.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Color(_selectedOperator.colorHex)
                                          : AppColors.darkTextPrimary,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: zone != null
                                      ? Text(
                                          'Zona $zone',
                                          style: const TextStyle(
                                            color: AppColors.darkTextTertiary,
                                            fontSize: 11,
                                          ),
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(_selectedOperator.colorHex),
                                          size: 20,
                                        )
                                      : const Icon(
                                          Icons.chevron_right_rounded,
                                          color: AppColors.darkBorderStrong,
                                          size: 18,
                                        ),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.of(ctx).pop();
                                    setState(() {
                                      if (isOrigin) {
                                        _originStop = stop;
                                      } else {
                                        _destStop = stop;
                                      }
                                    });
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

  IconData _modeIcon(String mode) {
    return switch (mode.toLowerCase()) {
      'subway' || 'metro' => Icons.subway_rounded,
      'tram' => Icons.tram_rounded,
      'funicular' || 'cable' => Icons.cable_rounded,
      'train' => Icons.train_rounded,
      _ => Icons.directions_bus_rounded,
    };
  }

  Widget _buildManualZoneSelector() {
    final maxZones = _getMaxZonesForOperator(_selectedOperator);

    if (maxZones == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: const Text(
          'Tarifa única / Zona urbana única',
          style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Número de zonas del viaje:',
          style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(maxZones, (i) {
            final z = i + 1;
            final selected = z == _manualZones;
            final color = Color(_selectedOperator.colorHex);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == maxZones - 1 ? 0 : 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _manualZones = z);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.25) : Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? color : AppColors.darkBorder,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$z ${z == 1 ? "Zona" : "Zonas"}',
                      style: TextStyle(
                        color: selected ? AppColors.darkTextPrimary : AppColors.darkTextSecondary,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  int _getMaxZonesForOperator(TransitOperator op) {
    return switch (op) {
      TransitOperator.metro => 3,
      TransitOperator.renfe => 5,
      TransitOperator.bizkaibus => 5,
      TransitOperator.euskotren => 5,
      TransitOperator.lurraldebus => 5,
      TransitOperator.alavabus => 4,
      _ => 1,
    };
  }

  Widget _buildFareResultCard(FareCalculation calc) {
    final opColor = Color(calc.operator.colorHex);

    return Container(
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            opColor.withValues(alpha: 0.28),
            AppColors.darkSurface,
          ],
        ),
        shape: continuousShape(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: opColor.withValues(alpha: 0.4), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.credit_card_rounded, color: AppColors.realtimeGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Viaje con ${calc.cardName}',
                    style: AppTypography.textTheme().titleMedium!.copyWith(
                      color: AppColors.darkTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (calc.savingsPercentage > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.realtimeGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.realtimeGreen.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'Ahorras ${calc.savingsPercentage}%',
                    style: const TextStyle(
                      color: AppColors.realtimeGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Price Comparison Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${calc.barikPrice.toStringAsFixed(2)} €',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkTextPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'vs ${calc.occasionalPrice.toStringAsFixed(2)} € ocasional',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.darkTextSecondary,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.disruptedRed,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            calc.isFlatFare
                ? 'Tarifa plana única · ${calc.profile.label}'
                : '${calc.zonesCount == 1 ? "1 Zona" : "${calc.zonesCount} Zonas recorridas"} · ${calc.profile.label}',
            style: const TextStyle(
              color: AppColors.darkTextSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (calc.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              calc.notes,
              style: const TextStyle(
                color: AppColors.darkTextTertiary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInteroperabilityCard(String cardName) {
    return GlassSurface(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sync_alt_rounded, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interoperabilidad en todo Euskadi',
                      style: TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Barik, MUGI y BAT son válidas en toda la red de las 3 provincias.',
                      style: TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.darkBorder, height: 1),
          const SizedBox(height: 10),
          const Text(
            'Descuento por transbordo: Al validar con tu tarjeta de transporte, el transbordo dentro del tiempo reglamentario (50 min o 90 min según distancia) disfruta de un 20% de descuento automático en el segundo operador.',
            style: TextStyle(
              color: AppColors.darkTextTertiary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneTableCard() {
    final maxZones = _getMaxZonesForOperator(_selectedOperator);
    final isFlat = _isFlatFareOperator(_selectedOperator);
    final cardName = _cardNameForTerritory(_selectedTerritory);

    return GlassSurface(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tabla oficial de tarifas · ${_selectedOperator.name}',
            style: const TextStyle(
              color: AppColors.darkTextPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1.0),
              2: FlexColumnWidth(1.0),
              3: FlexColumnWidth(1.0),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
                ),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Zona',
                        style: TextStyle(
                            color: AppColors.darkTextSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(cardName,
                        style: const TextStyle(
                            color: AppColors.realtimeGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Ocasional',
                        style: TextStyle(
                            color: AppColors.darkTextSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Ahorro',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ],
              ),
              if (isFlat)
                _buildZoneTableRow(1, labelOverride: 'Única')
              else
                for (int z = 1; z <= maxZones; z++) ...[
                  _buildZoneTableRow(z),
                ],
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildZoneTableRow(int zone, {String? labelOverride}) {
    final (cardPrice, occasional) = _getBasePrices(_selectedOperator, zone);
    final profileFactor = _getProfileFactor(_selectedProfile);
    final finalCard = cardPrice * profileFactor;
    final diff = occasional - finalCard;

    final label = labelOverride ?? '$zone ${zone == 1 ? "Zona" : "Zonas"}';

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.darkTextPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            '${finalCard.toStringAsFixed(2)} €',
            style: const TextStyle(
              color: AppColors.realtimeGreen,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            '${occasional.toStringAsFixed(2)} €',
            style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            '-${diff.toStringAsFixed(2)} €',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  FareCalculation _computeFare() {
    int zones = _manualZones;
    final isFlat = _isFlatFareOperator(_selectedOperator);

    if (isFlat) {
      zones = 1;
    } else if (_useCustomStops && _originStop != null && _destStop != null) {
      zones = _resolveZonesFromStops(_selectedOperator, _originStop!, _destStop!);
    }

    final (baseCard, baseOccasional) = _getBasePrices(_selectedOperator, zones);
    final factor = _getProfileFactor(_selectedProfile);
    final finalCard = baseCard * factor;

    String notes = '';
    if (_originStop != null && _destStop != null) {
      notes = '${_originStop!.name} → ${_destStop!.name}';
    }

    return FareCalculation(
      operator: _selectedOperator,
      territory: _selectedTerritory,
      cardName: _cardNameForTerritory(_selectedTerritory),
      zonesCount: zones,
      barikPrice: finalCard,
      occasionalPrice: baseOccasional,
      profile: _selectedProfile,
      notes: notes,
      isFlatFare: isFlat,
    );
  }

  (double, double) _getBasePrices(TransitOperator op, int zones) {
    return switch (op) {
      // Bizkaia
      TransitOperator.metro => switch (zones) {
          1 => (1.02, 2.00),
          2 => (1.19, 2.20),
          _ => (1.30, 2.25),
        },
      TransitOperator.bizkaibus => switch (zones) {
          1 => (1.02, 2.00),
          2 => (1.19, 2.20),
          3 => (1.40, 2.25),
          4 => (1.90, 3.40),
          _ => (2.45, 4.50),
        },
      TransitOperator.bilbobus => (0.65, 1.35),
      TransitOperator.renfe => switch (zones) {
          1 => (1.06, 1.65),
          2 => (1.32, 1.95),
          3 => (1.56, 2.05),
          4 => (1.92, 2.60),
          _ => (2.46, 3.35),
        },
      TransitOperator.euskotren => switch (zones) {
          1 => (1.02, 2.00),
          2 => (1.19, 2.20),
          3 => (1.40, 2.50),
          4 => (1.90, 3.40),
          _ => (2.45, 4.50),
        },
      TransitOperator.tranbiaBilbao => (0.73, 1.50),
      TransitOperator.pteColgante => (0.55, 0.60),
      TransitOperator.artxanda => (0.65, 2.50),

      // Gipuzkoa
      TransitOperator.dbus => (1.26, 1.85),
      TransitOperator.lurraldebus => switch (zones) {
          1 => (1.02, 1.85),
          2 => (1.40, 2.65),
          3 => (1.90, 3.60),
          4 => (2.50, 4.75),
          _ => (3.10, 5.90),
        },

      // Álava
      TransitOperator.tuvisa => (0.60, 1.40),
      TransitOperator.alavabus => switch (zones) {
          1 => (0.90, 1.60),
          2 => (1.45, 2.50),
          3 => (2.10, 3.60),
          _ => (2.80, 4.80),
        },
      TransitOperator.tranbiaGasteiz => (0.73, 1.50),

      _ => (1.02, 2.00),
    };
  }

  double _getProfileFactor(FareProfile profile) {
    return switch (profile) {
      FareProfile.standard => 1.0,
      FareProfile.gizatrans => 0.40,
      FareProfile.largeFamily20 => 0.80,
      FareProfile.largeFamily50 => 0.50,
      FareProfile.under12 => 0.0,
    };
  }

  int _resolveZonesFromStops(TransitOperator op, Stop o, Stop d) {
    if (_isFlatFareOperator(op)) return 1;

    // Metro Bilbao: Zone rings 1, 2, 3
    if (op == TransitOperator.metro) {
      final zO = _normalizeMetroZone(o.zoneId ?? o.name);
      final zD = _normalizeMetroZone(d.zoneId ?? d.name);
      if (zO == zD) return 1;
      if ((zO == 1 && zD == 2) || (zO == 2 && zD == 1)) return 2;
      return 3;
    }

    // Bizkaibus & Lurraldebus & Álavabus
    if (op == TransitOperator.bizkaibus ||
        op == TransitOperator.lurraldebus ||
        op == TransitOperator.alavabus) {
      final zO = int.tryParse(o.zoneId ?? '1') ?? 1;
      final zD = int.tryParse(d.zoneId ?? '1') ?? 1;
      final maxZ = _getMaxZonesForOperator(op);
      return ((zO - zD).abs() + 1).clamp(1, maxZ);
    }

    // Renfe Cercanías: calculate zone distance from station list
    if (op == TransitOperator.renfe) {
      final zO = _resolveRenfeZone(o);
      final zD = _resolveRenfeZone(d);
      return ((zO - zD).abs() + 1).clamp(1, 5);
    }

    return 1;
  }

  int _normalizeMetroZone(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('a') || lower == '1') return 1;
    if (lower.contains('b') || lower == '2') return 2;
    if (lower.contains('c') || lower == '3') return 3;
    return 1;
  }

  String? _guessZone(Stop stop) {
    if (_selectedOperator == TransitOperator.metro) {
      return _normalizeMetroZone(stop.name).toString();
    }
    if (_selectedOperator == TransitOperator.renfe) {
      return _resolveRenfeZone(stop).toString();
    }
    return stop.zoneId;
  }

  int _resolveRenfeZone(Stop stop) {
    final name = stop.name.toLowerCase();
    // Zone 1: Bilbao City Centre
    if (name.contains('abando') ||
        name.contains('zabalburu') ||
        name.contains('ametzola') ||
        name.contains('autonomía') ||
        name.contains('san mamés') ||
        name.contains('olabeaga') ||
        name.contains('zorrotza') ||
        name.contains('concordia') ||
        name.contains('basurto') ||
        name.contains('miribilla')) {
      return 1;
    }
    // Zone 2: Inner Metropolitan
    if (name.contains('barakaldo') ||
        name.contains('lutxana') ||
        name.contains('sestao') ||
        name.contains('iberia') ||
        name.contains('portugalete') ||
        name.contains('peñota') ||
        name.contains('santurtzi') ||
        name.contains('muskiz') ||
        name.contains('gallarta') ||
        name.contains('ortuella') ||
        name.contains('trapagaran') ||
        name.contains('trápaga') ||
        name.contains('urioste') ||
        name.contains('basauri') ||
        name.contains('bidebieta') ||
        name.contains('san miguel') ||
        name.contains('santa águeda') ||
        name.contains('kastrexana') ||
        name.contains('irauregui')) {
      return 2;
    }
    // Zone 3: Intermediate Valley
    if (name.contains('arrigorriaga') ||
        name.contains('miraballes') ||
        name.contains('ugao') ||
        name.contains('bedia') ||
        name.contains('arrankudiaga') ||
        name.contains('la quadra') ||
        name.contains('sodupe') ||
        name.contains('güeñes') ||
        name.contains('zalla') ||
        name.contains('balmaseda')) {
      return 3;
    }
    // Zone 4: Outer
    if (name.contains('llodio') ||
        name.contains('areta') ||
        name.contains('luiaondo') ||
        name.contains('karranza')) {
      return 4;
    }
    // Zone 5: Terminus
    if (name.contains('amurrio') || name.contains('orduña')) {
      return 5;
    }
    return 1;
  }
}
