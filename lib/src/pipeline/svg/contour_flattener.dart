import 'dart:math' as math;

import 'contour.dart';

/// Precomputed center-form parameters for an SVG arc segment.
class ArcCenterParams {
  const ArcCenterParams({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.cosPhi,
    required this.sinPhi,
    required this.theta1,
    required this.deltaTheta,
  });

  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final double cosPhi;
  final double sinPhi;
  final double theta1;
  final double deltaTheta;
}

/// Converts an SVG arc segment into its center-parametrized form.
/// Returns null for degenerate arcs (zero radius, zero length, etc.).
ArcCenterParams? computeArcCenterParams(SvgContourSegment segment) {
  final rxInput = segment.rx ?? 0;
  final ryInput = segment.ry ?? 0;
  if (rxInput <= 0 || ryInput <= 0) return null;

  final start = segment.start;
  final end = segment.end;
  if ((start.x - end.x).abs() < 1e-6 && (start.y - end.y).abs() < 1e-6) {
    return null;
  }

  final phi = (segment.xAxisRotation ?? 0) * (math.pi / 180);
  final cosPhi = math.cos(phi);
  final sinPhi = math.sin(phi);

  final dx2 = (start.x - end.x) / 2;
  final dy2 = (start.y - end.y) / 2;
  final x1Prime = cosPhi * dx2 + sinPhi * dy2;
  final y1Prime = -sinPhi * dx2 + cosPhi * dy2;

  var rx = rxInput.abs();
  var ry = ryInput.abs();
  final lambda =
      (x1Prime * x1Prime) / (rx * rx) + (y1Prime * y1Prime) / (ry * ry);
  if (lambda > 1) {
    final scale = math.sqrt(lambda);
    rx *= scale;
    ry *= scale;
  }

  final rxSq = rx * rx;
  final rySq = ry * ry;
  final x1PrimeSq = x1Prime * x1Prime;
  final y1PrimeSq = y1Prime * y1Prime;
  final numerator = rxSq * rySq - rxSq * y1PrimeSq - rySq * x1PrimeSq;
  final denominator = rxSq * y1PrimeSq + rySq * x1PrimeSq;
  if (denominator.abs() < 1e-12) return null;

  final sign = segment.largeArc == segment.sweep ? -1.0 : 1.0;
  final centerFactor = sign * math.sqrt(math.max(0, numerator / denominator));

  final cxPrime = centerFactor * (rx * y1Prime / ry);
  final cyPrime = centerFactor * (-ry * x1Prime / rx);

  final cx = cosPhi * cxPrime - sinPhi * cyPrime + (start.x + end.x) / 2;
  final cy = sinPhi * cxPrime + cosPhi * cyPrime + (start.y + end.y) / 2;

  final ux = (x1Prime - cxPrime) / rx;
  final uy = (y1Prime - cyPrime) / ry;
  final vx = (-x1Prime - cxPrime) / rx;
  final vy = (-y1Prime - cyPrime) / ry;

  final theta1 = math.atan2(uy, ux);
  var deltaTheta = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);

  final sweepFlag = segment.sweep ?? false;
  if (!sweepFlag && deltaTheta > 0) {
    deltaTheta -= 2 * math.pi;
  } else if (sweepFlag && deltaTheta < 0) {
    deltaTheta += 2 * math.pi;
  }

  return ArcCenterParams(
    cx: cx,
    cy: cy,
    rx: rx,
    ry: ry,
    cosPhi: cosPhi,
    sinPhi: sinPhi,
    theta1: theta1,
    deltaTheta: deltaTheta,
  );
}

/// Flattens an arc segment into sample points using center parametrization.
///
/// [curveSteps] controls the total sampling budget for a full circle;
/// partial arcs use a proportional fraction. Returns `[segment.end]` for
/// degenerate arcs (zero radius, coincident endpoints, etc.).
List<SvgPoint> flattenArcToPoints(
  SvgContourSegment segment, {
  required int curveSteps,
  int minSteps = 1,
}) {
  final rx = segment.rx ?? 0;
  final ry = segment.ry ?? 0;
  if (rx <= 0 || ry <= 0) return [segment.end];

  final params = computeArcCenterParams(segment);
  if (params == null) return [segment.end];

  final normalizedSweep = params.deltaTheta.abs() / (2 * math.pi);
  final stepCount = math.max(minSteps, (normalizedSweep * curveSteps).ceil());

  final points = <SvgPoint>[];
  for (var step = 1; step <= stepCount; step += 1) {
    final t = step / stepCount;
    final theta = params.theta1 + params.deltaTheta * t;
    final cosTheta = math.cos(theta);
    final sinTheta = math.sin(theta);
    points.add(
      SvgPoint(
        params.cosPhi * params.rx * cosTheta -
            params.sinPhi * params.ry * sinTheta +
            params.cx,
        params.sinPhi * params.rx * cosTheta +
            params.cosPhi * params.ry * sinTheta +
            params.cy,
      ),
    );
  }
  return points;
}

/// Flattens a contour into a plain polyline by subdividing curves.
///
/// [curveSteps] controls the number of sample points per cubic/quadratic
/// segment. Arcs are sampled adaptively (up to 32 points for a full circle,
/// minimum 4).
List<SvgPoint> flattenContourToPolyline(
  SvgContour contour, {
  int curveSteps = 8,
}) {
  if (contour.segments.isEmpty) return const [];

  final points = <SvgPoint>[contour.segments.first.start];

  for (final segment in contour.segments) {
    switch (segment.type) {
      case SvgContourSegmentType.line:
        points.add(segment.end);
      case SvgContourSegmentType.cubic:
        final p0 = segment.start;
        final p1 = segment.control1!;
        final p2 = segment.control2!;
        final p3 = segment.end;
        for (var step = 1; step <= curveSteps; step += 1) {
          final t = step / curveSteps;
          final u = 1 - t;
          points.add(
            SvgPoint(
              u * u * u * p0.x +
                  3 * u * u * t * p1.x +
                  3 * u * t * t * p2.x +
                  t * t * t * p3.x,
              u * u * u * p0.y +
                  3 * u * u * t * p1.y +
                  3 * u * t * t * p2.y +
                  t * t * t * p3.y,
            ),
          );
        }
      case SvgContourSegmentType.quadratic:
        final p0 = segment.start;
        final p1 = segment.control1!;
        final p2 = segment.end;
        for (var step = 1; step <= curveSteps; step += 1) {
          final t = step / curveSteps;
          final u = 1 - t;
          points.add(
            SvgPoint(
              u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
              u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y,
            ),
          );
        }
      case SvgContourSegmentType.arc:
        points.addAll(flattenArcToPoints(segment, curveSteps: 32, minSteps: 4));
    }
  }

  return points;
}
