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

/// Available passenger discount profiles supported by CTB / Barik.
enum FareProfile {
  standard('Estándar', 'Tarifa general Creditrans'),
  gizatrans('Gizatrans', 'Mayores de 65 años o personas con discapacidad'),
  largeFamily20('F. Numerosa (F20)', '20% bonificación Familia Numerosa General'),
  largeFamily50('F. Numerosa (F50)', '50% bonificación Familia Numerosa Especial');

  const FareProfile(this.label, this.description);
  final String label;
  final String description;
}

/// Fare calculation breakdown containing prices, zone jump, and potential savings.
class FareCalculation {
  const FareCalculation({
    required this.operator,
    required this.zonesCount,
    required this.barikPrice,
    required this.occasionalPrice,
    required this.profile,
    required this.notes,
  });

  final TransitOperator operator;
  final int zonesCount;
  final double barikPrice;
  final double occasionalPrice;
  final FareProfile profile;
  final String notes;

  double get savings => occasionalPrice > barikPrice ? occasionalPrice - barikPrice : 0.0;
  int get savingsPercentage => occasionalPrice > 0
      ? ((savings / occasionalPrice) * 100).round()
      : 0;
}

/// Interactive Multi-Modal Fare Consultation & Calculator screen.
/// Compares official Barik monedero prices with occasional tickets across all operators.
class TransitFaresScreen extends ConsumerStatefulWidget {
  const TransitFaresScreen({super.key});

  @override
  ConsumerState<TransitFaresScreen> createState() => _TransitFaresScreenState();
}

class _TransitFaresScreenState extends ConsumerState<TransitFaresScreen> {
  TransitOperator _selectedOperator = TransitOperator.metro;
  Stop? _originStop;
  Stop? _destStop;
  int _manualZones = 1;
  FareProfile _selectedProfile = FareProfile.standard;
  bool _useCustomStops = true;

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
                  'Tarifas y Barik',
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
                    // Operator Selector Pills
                    _buildOperatorSelector(),
                    const SizedBox(height: 18),

                    // Calculator Card
                    _buildCalculatorCard(activeStopsAsync),
                    const SizedBox(height: 18),

                    // Fare Result Hero Card
                    _buildFareResultCard(calculation),
                    const SizedBox(height: 18),

                    // Transfer & CTB Benefit Card
                    _buildTransferInfoCard(),
                    const SizedBox(height: 18),

                    // Full Zone Matrix Table
                    _buildZoneTableCard(),
                    const SizedBox(height: 32),

                    // Legal Footnote
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.gavel_rounded, size: 16, color: AppColors.darkTextTertiary),
                        label: const Text(
                          'Licencias oficiales y atribución de datos CTB',
                          style: TextStyle(color: AppColors.darkTextTertiary, fontSize: 12),
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

  Widget _buildOperatorSelector() {
    final operators = [
      TransitOperator.metro,
      TransitOperator.bizkaibus,
      TransitOperator.bilbobus,
      TransitOperator.renfe,
      TransitOperator.euskotren,
    ];

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
    final hasZonePicker = _selectedOperator != TransitOperator.bilbobus;

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
                'Calculador de viaje',
                style: AppTypography.textTheme().titleMedium?.copyWith(
                      color: AppColors.darkTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (hasZonePicker)
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
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_useCustomStops && hasZonePicker) ...[
            // Origin Dropdown
            activeStopsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => _buildManualZoneSelector(),
              data: (stops) {
                final allStops = [
                  if (_originStop != null && !stops.any((s) => s.id == _originStop!.id))
                    _originStop!,
                  ...stops,
                ];
                return DropdownButtonFormField<Stop>(
                  value: _originStop,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Parada de origen',
                    prefixIcon: const Icon(Icons.trip_origin, color: Colors.green, size: 18),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.darkBorder),
                    ),
                  ),
                  items: allStops.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _originStop = val;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 10),

            // Destination Dropdown
            activeStopsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (stops) {
                final allStops = [
                  if (_destStop != null && !stops.any((s) => s.id == _destStop!.id))
                    _destStop!,
                  ...stops,
                ];
                return DropdownButtonFormField<Stop>(
                  value: _destStop,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Parada de destino',
                    prefixIcon: const Icon(Icons.location_on, color: Colors.red, size: 18),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.darkBorder),
                    ),
                  ),
                  items: allStops.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _destStop = val;
                    });
                  },
                );
              },
            ),
          ] else ...[
            _buildManualZoneSelector(),
          ],

          const SizedBox(height: 16),

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

  Widget _buildManualZoneSelector() {
    final maxZones = switch (_selectedOperator) {
      TransitOperator.metro => 3,
      TransitOperator.bilbobus => 1,
      TransitOperator.renfe => 5,
      TransitOperator.bizkaibus => 5,
      TransitOperator.euskotren => 5,
      _ => 3,
    };

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
                    'Viaje con Barik',
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
            '${calc.zonesCount == 1 ? "1 Zona" : "${calc.zonesCount} Zonas recorridas"} · ${calc.profile.label}',
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

  Widget _buildTransferInfoCard() {
    return GlassSurface(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  'Descuento por transbordo CTB',
                  style: TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Al usar Barik, el segundo transporte realizado dentro de los 50 minutos (90 min en viajes de más de 3 zonas) disfruta automáticamente de un 20% de descuento sobre su tarifa.',
                  style: TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneTableCard() {
    final maxZones = switch (_selectedOperator) {
      TransitOperator.metro => 3,
      TransitOperator.bilbobus => 1,
      TransitOperator.renfe => 5,
      TransitOperator.bizkaibus => 5,
      TransitOperator.euskotren => 5,
      _ => 3,
    };

    return GlassSurface(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tabla completa de tarifas · ${_selectedOperator.name}',
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
              const TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Zona', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Barik', style: TextStyle(color: AppColors.realtimeGreen, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Ocasional', style: TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Ahorro', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ),
              for (int z = 1; z <= maxZones; z++) ...[
                _buildZoneTableRow(z),
              ],
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildZoneTableRow(int zone) {
    final (barik, occasional) = _getBasePrices(_selectedOperator, zone);
    final profileFactor = _getProfileFactor(_selectedProfile);
    final finalBarik = barik * profileFactor;
    final diff = occasional - finalBarik;

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text('$zone ${zone == 1 ? "Zona" : "Zonas"}', style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text('${finalBarik.toStringAsFixed(2)} €', style: const TextStyle(color: AppColors.realtimeGreen, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text('${occasional.toStringAsFixed(2)} €', style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 12)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text('-${diff.toStringAsFixed(2)} €', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  FareCalculation _computeFare() {
    int zones = _manualZones;

    // Automatic zone detection if origin & destination are selected
    if (_useCustomStops && _originStop != null && _destStop != null) {
      zones = _resolveZonesFromStops(_selectedOperator, _originStop!, _destStop!);
    }

    final (baseBarik, baseOccasional) = _getBasePrices(_selectedOperator, zones);
    final factor = _getProfileFactor(_selectedProfile);
    final finalBarik = baseBarik * factor;

    String notes = '';
    if (_originStop != null && _destStop != null && _useCustomStops) {
      notes = '${_originStop!.name} → ${_destStop!.name}';
    }

    return FareCalculation(
      operator: _selectedOperator,
      zonesCount: zones,
      barikPrice: finalBarik,
      occasionalPrice: baseOccasional,
      profile: _selectedProfile,
      notes: notes,
    );
  }

  (double, double) _getBasePrices(TransitOperator op, int zones) {
    return switch (op) {
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
      TransitOperator.bilbobus => (0.65, 1.30),
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
      _ => (1.02, 2.00),
    };
  }

  double _getProfileFactor(FareProfile profile) {
    return switch (profile) {
      FareProfile.standard => 1.0,
      FareProfile.gizatrans => 0.40,
      FareProfile.largeFamily20 => 0.80,
      FareProfile.largeFamily50 => 0.50,
    };
  }

  int _resolveZonesFromStops(TransitOperator op, Stop o, Stop d) {
    if (op == TransitOperator.bilbobus) return 1;

    // Metro Bilbao: Zone rings A (1), B0-B2 (2), C (3)
    if (op == TransitOperator.metro) {
      final zO = _normalizeMetroZone(o.zoneId ?? o.name);
      final zD = _normalizeMetroZone(d.zoneId ?? d.name);
      if (zO == zD) return 1;
      if ((zO == 1 && zD == 2) || (zO == 2 && zD == 1)) return 2;
      return 3;
    }

    // Bizkaibus: numeric zones 1 to 5
    if (op == TransitOperator.bizkaibus) {
      final zO = int.tryParse(o.zoneId ?? '1') ?? 1;
      final zD = int.tryParse(d.zoneId ?? '1') ?? 1;
      return ((zO - zD).abs() + 1).clamp(1, 5);
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
    // Zone 2: Inner Metropolitan (Barakaldo, Sestao, Portugalete, Santurtzi, Basauri)
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
    // Zone 3: Intermediate Valley (Arrigorriaga, Ugao, Sodupe, Güeñes)
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
    // Zone 4: Outer (Llodio, Luiaondo, Karranza)
    if (name.contains('llodio') ||
        name.contains('areta') ||
        name.contains('luiaondo') ||
        name.contains('karranza')) {
      return 4;
    }
    // Zone 5: Terminus (Amurrio, Orduña)
    if (name.contains('amurrio') || name.contains('orduña')) {
      return 5;
    }
    return 1;
  }
}
