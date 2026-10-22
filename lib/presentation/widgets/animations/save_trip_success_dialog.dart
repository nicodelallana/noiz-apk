import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

/// Modal dialog showing an elastic checkmark animation when a trip is favorited.
class SaveTripSuccessDialog extends StatefulWidget {
  const SaveTripSuccessDialog({
    super.key,
    required this.tripName,
  });

  final String tripName;

  static Future<void> show(BuildContext context, {required String tripName}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => SaveTripSuccessDialog(tripName: tripName),
    );
  }

  @override
  State<SaveTripSuccessDialog> createState() => _SaveTripSuccessDialogState();
}

class _SaveTripSuccessDialogState extends State<SaveTripSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: SizedBox(
                width: 72,
                height: 72,
                child: MediaQuery.disableAnimationsOf(context)
                    ? const Icon(
                        Icons.check_circle,
                        color: Color(0xFF0052CC),
                        size: 64,
                      )
                    : Lottie.asset(
                        'assets/lottie/save_trip_success.json',
                        controller: _controller,
                        repeat: false,
                        onLoaded: (composition) {
                          _controller
                            ..duration = composition.duration
                            ..forward();
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Viaje guardado!',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.tripName,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}
