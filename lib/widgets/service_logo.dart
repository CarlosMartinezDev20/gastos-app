import 'package:flutter/material.dart';

import '../core/utils/subscriptions.dart';

/// An app-icon-like tile for a subscription: the service's gradient and its
/// monogram (no trademarked logos). Services outside the catalog get colors
/// and letters from their name.
class ServiceLogo extends StatelessWidget {
  const ServiceLogo({
    super.key,
    required this.serviceKey,
    required this.name,
    this.size = 44,
  });

  final String? serviceKey;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final service = serviceFor(serviceKey);
    final colors = service?.colors ?? colorsFor(name);
    final monogram = service?.monogram ?? monogramFor(name);
    // iOS app icons round their corners to ~22% of the side.
    final radius = BorderRadius.circular(size * .23);
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          // A soft top highlight, like a glossy icon.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Colors.white.withValues(alpha: .18), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.all(size * .16),
        child: FittedBox(
          child: Text(
            monogram,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -.5,
            ),
          ),
        ),
      ),
    );
  }
}
