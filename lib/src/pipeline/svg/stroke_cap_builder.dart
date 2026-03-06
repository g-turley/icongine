import 'dart:math' as math;

import 'contour.dart';
import 'document.dart';

/// Builds stroke endpoint caps (butt, square, round).
class StrokeCapBuilder {
  const StrokeCapBuilder();

  /// Returns the points that form the cap at [endpoint].
  ///
  /// [direction] is the path direction at the endpoint (pointing away from the
  /// path interior). [halfWidth] is half the stroke width. Returns an empty
  /// list for butt caps, two points for square caps, and a semicircle arc for
  /// round caps.
  List<SvgPoint> build(
    SvgPoint endpoint,
    SvgPoint direction,
    double halfWidth,
    SvgStrokeLineCap lineCap,
  ) {
    final normal = SvgPoint(-direction.y, direction.x);

    switch (lineCap) {
      case SvgStrokeLineCap.butt:
        return const [];

      case SvgStrokeLineCap.square:
        final extended = SvgPoint(
          endpoint.x + direction.x * halfWidth,
          endpoint.y + direction.y * halfWidth,
        );
        return [
          SvgPoint(
            extended.x + normal.x * halfWidth,
            extended.y + normal.y * halfWidth,
          ),
          SvgPoint(
            extended.x - normal.x * halfWidth,
            extended.y - normal.y * halfWidth,
          ),
        ];

      case SvgStrokeLineCap.round:
        return _buildSemicircle(endpoint, direction, halfWidth);
    }
  }

  List<SvgPoint> _buildSemicircle(
    SvgPoint center,
    SvgPoint direction,
    double radius,
  ) {
    const steps = 8;
    final points = <SvgPoint>[];
    final startAngle = math.atan2(direction.y, direction.x) + math.pi / 2;

    for (var step = 0; step <= steps; step += 1) {
      final angle = startAngle - math.pi * step / steps;
      points.add(
        SvgPoint(
          center.x + radius * math.cos(angle),
          center.y + radius * math.sin(angle),
        ),
      );
    }
    return points;
  }
}
