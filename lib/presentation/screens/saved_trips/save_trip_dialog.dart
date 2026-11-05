import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/saved_trip_models.dart';
import '../../../domain/models/transit_models.dart';
import '../../providers/saved_trips_providers.dart';
import '../../providers/transit_providers.dart';
import '../../widgets/animations/save_trip_success_dialog.dart';

/// Modal dialog for bookmarking a new transit journey.
class SaveTripDialog extends ConsumerStatefulWidget {
  const SaveTripDialog({
    super.key,
    this.initialOrigin,
    this.initialDestination,
  });

  final Stop? initialOrigin;
  final Stop? initialDestination;

  @override
  ConsumerState<SaveTripDialog> createState() => _SaveTripDialogState();
}

class _SaveTripDialogState extends ConsumerState<SaveTripDialog> {
  late final TextEditingController _nameController;
  Stop? _origin;
  Stop? _destination;
  bool _widgetEnabled = true;

  @override
  void initState() {
    super.initState();
    _origin = widget.initialOrigin;
    _destination = widget.initialDestination;

    final initialName = _origin != null && _destination != null
        ? '${_origin!.name} → ${_destination!.name}'
        : _origin != null
            ? 'Desde ${_origin!.name}'
            : 'Mi Trayecto';

    _nameController = TextEditingController(text: initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveOp = _origin != null
        ? TransitOperator.fromId(_origin!.operatorId)
        : ref.watch(selectedOperatorProvider);
    final stationsAsync = ref.watch(stopsForActiveOperatorProvider);

    return AlertDialog(
      title: Text('Guardar viaje · ${effectiveOp.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del viaje',
                hintText: 'Ej. Casa al Trabajo',
                prefixIcon: Icon(Icons.bookmark_border),
              ),
            ),
            const SizedBox(height: 16),

            // Origin Picker
            stationsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (stations) {
                final allStations = [
                  if (_origin != null &&
                      !stations.any((s) => s.id == _origin!.id))
                    _origin!,
                  ...stations,
                ];
                final currentOriginValid =
                    _origin != null && allStations.any((s) => s.id == _origin!.id);
                final selectedOrigin = currentOriginValid ? _origin : null;

                return DropdownButtonFormField<Stop>(
                  value: selectedOrigin,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Estación de origen',
                    prefixIcon: Icon(Icons.trip_origin, color: Colors.green),
                  ),
                  items: allStations
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _origin = val;
                      _destination = null;
                      _updateDefaultName();
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 12),

            // Destination Picker (Smart Reachable Only)
            FutureBuilder<List<Stop>>(
              future: _origin != null
                  ? ref
                      .read(transitRepositoryProvider)
                      .getReachableDestinations(originStopId: _origin!.id)
                  : Future.value(<Stop>[]),
              builder: (context, snapshot) {
                final reachable = snapshot.data ?? [];
                final allDestinations = [
                  if (_destination != null &&
                      !reachable.any((s) => s.id == _destination!.id))
                    _destination!,
                  ...reachable,
                ];
                final currentValid = _destination != null &&
                    allDestinations.any((s) => s.id == _destination?.id);
                final selectedDest = currentValid ? _destination : null;

                return DropdownButtonFormField<Stop>(
                  value: selectedDest,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _origin == null
                        ? 'Selecciona origen primero'
                        : 'Estación de destino (directa)',
                    prefixIcon:
                        const Icon(Icons.location_on, color: Colors.red),
                    helperText: _origin != null && reachable.isEmpty
                        ? 'No hay destinos directos sin transbordo'
                        : null,
                  ),
                  items: allDestinations
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child:
                                Text(s.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: _origin == null
                      ? null
                      : (val) {
                          setState(() {
                            _destination = val;
                            _updateDefaultName();
                          });
                        },
                );
              },
            ),
            const SizedBox(height: 16),

            // Widget switch
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar en Widget'),
              subtitle: const Text(
                  'Disponible para acceso rápido en pantalla de inicio'),
              value: _widgetEnabled,
              onChanged: (val) => setState(() => _widgetEnabled = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _origin == null || _destination == null
              ? null
              : () async {
                  final finalName = _nameController.text.trim().isNotEmpty
                      ? _nameController.text.trim()
                      : '${_origin!.name} → ${_destination!.name}';
                  final tripOp = _origin != null
                      ? TransitOperator.fromId(_origin!.operatorId)
                      : effectiveOp;
                  await ref
                      .read(savedTripsControllerProvider.notifier)
                      .saveTrip(
                        name: finalName,
                        operator: tripOp,
                        originStopId: _origin!.id,
                        originStopName: _origin!.name,
                        destStopId: _destination!.id,
                        destStopName: _destination!.name,
                        widgetEnabled: _widgetEnabled,
                      );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    await SaveTripSuccessDialog.show(
                      context,
                      tripName: finalName,
                    );
                  }
                },
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  void _updateDefaultName() {
    if (_origin != null && _destination != null) {
      _nameController.text = '${_origin!.name} → ${_destination!.name}';
    }
  }
}
