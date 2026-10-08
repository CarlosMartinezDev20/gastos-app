import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';

import '../core/utils/brand_marks.dart';
import '../core/utils/subscriptions.dart';

/// An app-icon-like tile for a subscription: the service's gradient with
/// its mark in white (`brandMarks`), or its monogram when it has none.
/// Services outside the catalog get colors and letters from their name.
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
    final mark = markFor(service?.key);
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
        padding: EdgeInsets.all(size * (mark == null ? .16 : .22)),
        child: mark != null
            ? CustomPaint(painter: _MarkPainter(mark), size: Size.infinite)
            : FittedBox(
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

  /// Parsed once per service.
  static final _marks = <String, Path>{};

  static Path? markFor(String? key) {
    final data = brandMarks[key];
    if (data == null) return null;
    return _marks.putIfAbsent(key!, () {
      final writer = _PathWriter();
      writeSvgPathDataToPath(data, writer);
      return writer.path;
    });
  }
}

/// Paints a 24×24 mark scaled to the tile, in white.
class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.mark);

  final Path mark;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas
      ..save()
      ..translate((size.width - 24 * scale) / 2, (size.height - 24 * scale) / 2)
      ..scale(scale)
      ..drawPath(mark, Paint()..color = Colors.white)
      ..restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.mark != mark;
}

class _PathWriter extends PathProxy {
  final path = Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}
