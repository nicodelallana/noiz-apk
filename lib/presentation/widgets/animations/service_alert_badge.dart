import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Amber warning beacon indicator for lines or stations with active service disruption.
class ServiceAlertBadge extends StatelessWidget {
  const ServiceAlertBadge({
    super.key,
    this.size = 24.0,
    this.onTap,
  });

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget child = RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: MediaQuery.disableAnimationsOf(context)
            ? const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              )
            : Lottie.asset(
                'assets/lottie/service_alert.json',
                fit: BoxFit.contain,
              ),
      ),
    );

    if (onTap != null) {
      child = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: child,
      );
    }

    return child;
  }
}
