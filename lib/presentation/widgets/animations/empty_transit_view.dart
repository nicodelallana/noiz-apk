import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Clean, delightful empty state illustration for transit screens with zero departures.
class EmptyTransitView extends StatelessWidget {
  const EmptyTransitView({
    super.key,
    this.title = 'Sin próximas salidas',
    this.message = 'No hay más servicios programados para el día de hoy.',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: SizedBox(
                width: 96,
                height: 96,
                child: MediaQuery.disableAnimationsOf(context)
                    ? Icon(
                        Icons.schedule,
                        size: 64,
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      )
                    : Lottie.asset(
                        'assets/lottie/empty_transit.json',
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualizar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
