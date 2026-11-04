import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bizkaia_transit/core/services/live_trip_service.dart';
import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/barik_icons.dart';
import 'package:bizkaia_transit/domain/models/live_trip_models.dart';
import 'package:bizkaia_transit/presentation/widgets/ambient_glow_background.dart';

/// Debug-only simulator screen to test and verify lock-screen Live Activities
/// and ongoing notifications across every state and operator.
class LiveActivitySimulatorScreen extends ConsumerStatefulWidget {
  const LiveActivitySimulatorScreen({super.key});

  @override
  ConsumerState<LiveActivitySimulatorScreen> createState() =>
      _LiveActivitySimulatorScreenState();
}

class _LiveActivitySimulatorScreenState
    extends ConsumerState<LiveActivitySimulatorScreen> {
  String _selectedOperatorId = 'renfe';
  String _lineName = 'C-3';
  String _lineColor = '#D0142B';
  String _origin = 'Llodio';
  String _destination = 'Bilbao-Abando';
  String _currentStop = 'Luiaondo';
  String _nextStop = 'Bidebieta-Basauri';
  int _stopsRemaining = 4;
  double _progress = 0.35;
  int _delaySeconds = 0;
  bool _isRealtime = true;
  LiveTripStatus _status = LiveTripStatus.tracking;
  String? _instruction = 'Bájate en Bilbao-Abando';

  void _applyPreset(LiveTripStatus status) {
    setState(() {
      _status = status;
      switch (status) {
        case LiveTripStatus.scheduled:
          _progress = 0.05;
          _isRealtime = false;
          _delaySeconds = 0;
          _stopsRemaining = 7;
          _instruction = 'Sale a las 14:58 según horario';
        case LiveTripStatus.tracking:
          _progress = 0.40;
          _isRealtime = true;
          _delaySeconds = 0;
          _stopsRemaining = 4;
          _instruction = 'En camino a $_destination';
        case LiveTripStatus.delayed:
          _progress = 0.45;
          _isRealtime = true;
          _delaySeconds = 180; // +3 min
          _stopsRemaining = 3;
          _instruction = 'Retraso de 3 min por obras en vía';
        case LiveTripStatus.arriving:
          _progress = 0.85;
          _isRealtime = true;
          _delaySeconds = 0;
          _stopsRemaining = 1;
          _instruction = 'Llegando a $_destination en 2 min';
        case LiveTripStatus.atStop:
          _progress = 0.95;
          _isRealtime = true;
          _delaySeconds = 0;
          _stopsRemaining = 0;
          _instruction = 'En andén. Bájate ahora';
        case LiveTripStatus.disrupted:
          _progress = 0.50;
          _isRealtime = true;
          _delaySeconds = 600;
          _stopsRemaining = 3;
          _instruction = 'Circulación con demoras importantes';
        case LiveTripStatus.ended:
          _progress = 1.0;
          _isRealtime = true;
          _stopsRemaining = 0;
          _instruction = 'Has llegado a $_destination';
      }
    });

    _sendToPlatform();
  }

  void _selectOperatorPreset(String op) {
    setState(() {
      _selectedOperatorId = op;
      switch (op) {
        case 'renfe':
          _lineName = 'C-3';
          _lineColor = '#D0142B';
          _origin = 'Llodio';
          _destination = 'Bilbao-Abando';
          _currentStop = 'Luiaondo';
          _nextStop = 'Bidebieta-Basauri';
        case 'metro':
          _lineName = 'L1';
          _lineColor = '#E8590C';
          _origin = 'Plentzia';
          _destination = 'San Mamés';
          _currentStop = 'Areeta';
          _nextStop = 'Deusto';
        case 'bizkaibus':
          _lineName = 'A2153';
          _lineColor = '#2E9E4F';
          _origin = 'Bilbao';
          _destination = 'Loiu';
          _currentStop = 'Severo Ochoa 13';
          _nextStop = 'Aireportua';
        case 'dbus':
          _lineName = '28';
          _lineColor = '#1D7FD1';
          _origin = 'Boulevard';
          _destination = 'Miramon';
          _currentStop = 'Urbieta';
          _nextStop = 'San Martin';
        case 'tuvisa':
          _lineName = 'BEI';
          _lineColor = '#12979F';
          _origin = 'Salburua';
          _destination = 'Unibertsitatea';
          _currentStop = 'Mendizorrotza';
          _nextStop = 'Boulevard';
      }
    });
    _sendToPlatform();
  }

  Future<void> _sendToPlatform() async {
    final arrival = DateTime.now().add(
      Duration(minutes: ((1.0 - _progress) * 15).round() + 1),
    );

    final trip = LiveTripState(
      tripId: 'sim_${DateTime.now().millisecondsSinceEpoch}',
      operatorId: _selectedOperatorId,
      mode: _selectedOperatorId == 'bizkaibus' ||
              _selectedOperatorId == 'dbus' ||
              _selectedOperatorId == 'tuvisa'
          ? 'bus'
          : 'train',
      lineId: _lineName,
      lineName: _lineName,
      lineColor: _lineColor,
      origin: _origin,
      destination: _destination,
      currentStop: _currentStop,
      nextStop: _nextStop,
      stopsRemaining: _stopsRemaining,
      progress: _progress,
      arrivalTime: arrival,
      status: _status,
      isRealtime: _isRealtime,
      delaySeconds: _delaySeconds,
      instruction: _instruction,
      updatedAt: DateTime.now(),
    );

    await ref.read(activeLiveTripProvider.notifier).startTrip(trip);
  }

  @override
  Widget build(BuildContext context) {
    final parsedColor = Color(
      int.tryParse(_lineColor.replaceAll('#', '0xFF')) ?? 0xFFE2001A,
    );

    return AmbientGlowBackground(
      accentColor: parsedColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Simulador Live Activity',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(BarikIcons.broadcast),
              tooltip: 'Emitir al sistema nativo',
              onPressed: _sendToPlatform,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Operator Presets
            const Text(
              'OPERADOR',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.darkTextSecondary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _OperatorChip(
                    label: 'Renfe C-3',
                    color: AppColors.opRenfe,
                    isSelected: _selectedOperatorId == 'renfe',
                    onTap: () => _selectOperatorPreset('renfe'),
                  ),
                  const SizedBox(width: 8),
                  _OperatorChip(
                    label: 'Metro L1',
                    color: AppColors.opMetroBilbao,
                    isSelected: _selectedOperatorId == 'metro',
                    onTap: () => _selectOperatorPreset('metro'),
                  ),
                  const SizedBox(width: 8),
                  _OperatorChip(
                    label: 'Bizkaibus A2153',
                    color: AppColors.opBizkaibus,
                    isSelected: _selectedOperatorId == 'bizkaibus',
                    onTap: () => _selectOperatorPreset('bizkaibus'),
                  ),
                  const SizedBox(width: 8),
                  _OperatorChip(
                    label: 'Dbus 28',
                    color: AppColors.opDbus,
                    isSelected: _selectedOperatorId == 'dbus',
                    onTap: () => _selectOperatorPreset('dbus'),
                  ),
                  const SizedBox(width: 8),
                  _OperatorChip(
                    label: 'TUVISA BEI',
                    color: AppColors.opTuvisa,
                    isSelected: _selectedOperatorId == 'tuvisa',
                    onTap: () => _selectOperatorPreset('tuvisa'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Live Activity Lock-Screen Preview Card (Faithful to Reference nvp)
            const Text(
              'VISTA PREVIA PANTALLA DE BLOQUEO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.darkTextSecondary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _LockScreenCardPreview(
              lineName: _lineName,
              lineColor: parsedColor,
              destination: _destination,
              origin: _origin,
              stopsRemaining: _stopsRemaining,
              progress: _progress,
              status: _status,
              isRealtime: _isRealtime,
              delaySeconds: _delaySeconds,
              instruction: _instruction,
              nextStop: _nextStop,
            ),

            const SizedBox(height: 20),

            // State Transitions
            const Text(
              'ESTADOS DEL VIAJE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.darkTextSecondary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StateButton(
                  label: 'Scheduled',
                  isSelected: _status == LiveTripStatus.scheduled,
                  onTap: () => _applyPreset(LiveTripStatus.scheduled),
                ),
                _StateButton(
                  label: 'Tracking',
                  isSelected: _status == LiveTripStatus.tracking,
                  onTap: () => _applyPreset(LiveTripStatus.tracking),
                ),
                _StateButton(
                  label: 'Delayed (+3 min)',
                  isSelected: _status == LiveTripStatus.delayed,
                  onTap: () => _applyPreset(LiveTripStatus.delayed),
                ),
                _StateButton(
                  label: 'Arriving',
                  isSelected: _status == LiveTripStatus.arriving,
                  onTap: () => _applyPreset(LiveTripStatus.arriving),
                ),
                _StateButton(
                  label: 'At Stop',
                  isSelected: _status == LiveTripStatus.atStop,
                  onTap: () => _applyPreset(LiveTripStatus.atStop),
                ),
                _StateButton(
                  label: 'Disrupted',
                  isSelected: _status == LiveTripStatus.disrupted,
                  onTap: () => _applyPreset(LiveTripStatus.disrupted),
                ),
                _StateButton(
                  label: 'Ended',
                  isSelected: _status == LiveTripStatus.ended,
                  onTap: () => _applyPreset(LiveTripStatus.ended),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Progress Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PROGRESO DEL VIAJE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            Slider(
              value: _progress,
              activeColor: parsedColor,
              inactiveColor: AppColors.darkBorderStrong,
              onChanged: (val) {
                setState(() => _progress = val);
                _sendToPlatform();
              },
            ),

            const SizedBox(height: 16),

            // Stop Service Button
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(activeLiveTripProvider.notifier).endTrip();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Viaje finalizado en el sistema nativo'),
                    ),
                  );
                }
              },
              icon: const Icon(BarikIcons.stopCircle),
              label: const Text('Detener Live Activity'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.disruptedRed,
                side: const BorderSide(color: AppColors.disruptedRed),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _OperatorChip extends StatelessWidget {
  const _OperatorChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.darkBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.darkTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _StateButton extends StatelessWidget {
  const _StateButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.darkTextPrimary
              : AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? AppColors.darkTextPrimary : AppColors.darkBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.darkBackground
                : AppColors.darkTextPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LockScreenCardPreview extends StatelessWidget {
  const _LockScreenCardPreview({
    required this.lineName,
    required this.lineColor,
    required this.destination,
    required this.origin,
    required this.stopsRemaining,
    required this.progress,
    required this.status,
    required this.isRealtime,
    required this.delaySeconds,
    this.instruction,
    required this.nextStop,
  });

  final String lineName;
  final Color lineColor;
  final String destination;
  final String origin;
  final int stopsRemaining;
  final double progress;
  final LiveTripStatus status;
  final bool isRealtime;
  final int delaySeconds;
  final String? instruction;
  final String nextStop;

  @override
  Widget build(BuildContext context) {
    final statusColor = delaySeconds > 60
        ? AppColors.delayedAmber
        : (isRealtime ? AppColors.realtimeGreen : AppColors.scheduledGray);

    final statusLabel = delaySeconds > 60
        ? '+${delaySeconds ~/ 60} min'
        : (isRealtime ? 'En directo' : 'Según horario');

    final remainingMins = ((1.0 - progress) * 15).round() + 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.darkBorderStrong),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Line Pill + Status Dot
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  lineName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              const Text(
                'Barik Live',
                style: TextStyle(
                  color: AppColors.darkTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (status == LiveTripStatus.ended) ...[
            Row(
              children: [
                const Icon(
                  BarikIcons.checkCircle,
                  color: AppColors.realtimeGreen,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Has llegado a $destination',
                        style: const TextStyle(
                          color: AppColors.darkTextPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$lineName · Viaje finalizado',
                        style: const TextStyle(
                          color: AppColors.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            // Time remaining & instruction
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$remainingMins',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkTextPrimary,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'min · $stopsRemaining paradas',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      instruction ?? 'Bájate en $destination',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    if (nextStop.isNotEmpty)
                      Text(
                        'Próxima: $nextStop',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Scenic Track Bar with Moving Vehicle
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final pos =
                    (width * progress.clamp(0.0, 1.0)).clamp(0.0, width - 24);

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Background Rail
                    Container(
                      height: 6,
                      width: width,
                      decoration: BoxDecoration(
                        color: AppColors.darkSurfaceElevated,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // Active filled progress track
                    Container(
                      height: 6,
                      width: width * progress.clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // Vehicle indicator
                    Positioned(
                      left: pos,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: lineColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: lineColor.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          BarikIcons.train,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                    // Destination terminal dot
                    Positioned(
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 8),

            // Endpoints
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  origin,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                Text(
                  destination,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
