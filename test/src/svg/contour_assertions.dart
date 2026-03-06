import 'dart:math' as math;

import 'package:icongine/icongine.dart';
import 'package:test/test.dart';

void expectContourCount(SvgContourPath contourPath, int expected) {
  expect(contourPath.contours, hasLength(expected));
}

void expectContourWinding(SvgContour contour, {required bool clockwise}) {
  final area = signedArea(contour);
  if (clockwise) {
    expect(
      area,
      greaterThan(1e-6),
      reason: 'Expected clockwise winding (positive area), got $area',
    );
  } else {
    expect(
      area,
      lessThan(-1e-6),
      reason: 'Expected counter-clockwise winding (negative area), got $area',
    );
  }
}

void expectAllContoursClosed(SvgContourPath contourPath) {
  for (var index = 0; index < contourPath.contours.length; index += 1) {
    expect(
      contourPath.contours[index].isClosed,
      isTrue,
      reason: 'Contour at index $index must be closed',
    );
  }
}

/// Computes signed area in SVG coordinates (Y-down):
/// positive = clockwise, negative = counter-clockwise.
double signedArea(SvgContour contour) {
  final points = _flattenContourToPolyline(contour);
  if (points.length < 3) {
    return 0;
  }

  var area = 0.0;
  for (var index = 0; index < points.length; index += 1) {
    final current = points[index];
    final next = points[(index + 1) % points.length];
    area += current.x * next.y - next.x * current.y;
  }

  return area / 2;
}

int countInteriorSelfIntersections(SvgContour contour) {
  var count = 0;
  final segmentCount = contour.segments.length;
  for (var firstIndex = 0; firstIndex < segmentCount; firstIndex += 1) {
    final first = contour.segments[firstIndex];
    for (
      var secondIndex = firstIndex + 1;
      secondIndex < segmentCount;
      secondIndex += 1
    ) {
      final isAdjacent =
          secondIndex == firstIndex ||
          secondIndex == firstIndex + 1 ||
          (firstIndex == 0 && secondIndex == segmentCount - 1);
      if (isAdjacent) {
        continue;
      }

      final intersection = _segmentInteriorIntersection(
        first.start,
        first.end,
        contour.segments[secondIndex].start,
        contour.segments[secondIndex].end,
      );
      if (intersection != null) {
        count += 1;
      }
    }
  }
  return count;
}

List<SvgPoint> _flattenContourToPolyline(SvgContour contour) {
  if (contour.segments.isEmpty) {
    return const [];
  }

  final points = <SvgPoint>[contour.segments.first.start];
  for (final segment in contour.segments) {
    switch (segment.type) {
      case SvgContourSegmentType.line:
        points.add(segment.end);
      case SvgContourSegmentType.arc:
        points.addAll(_flattenArc(segment));
      case SvgContourSegmentType.cubic:
        _flattenCubic(
          segment.start,
          segment.control1!,
          segment.control2!,
          segment.end,
          points,
        );
      case SvgContourSegmentType.quadratic:
        _flattenQuadratic(
          segment.start,
          segment.control1!,
          segment.end,
          points,
        );
    }
  }

  if (points.length > 1) {
    final first = points.first;
    final last = points.last;
    if ((first.x - last.x).abs() < 1e-9 && (first.y - last.y).abs() < 1e-9) {
      points.removeLast();
    }
  }

  return points;
}

SvgPoint? _segmentInteriorIntersection(
  SvgPoint firstStart,
  SvgPoint firstEnd,
  SvgPoint secondStart,
  SvgPoint secondEnd,
) {
  final firstDx = firstEnd.x - firstStart.x;
  final firstDy = firstEnd.y - firstStart.y;
  final secondDx = secondEnd.x - secondStart.x;
  final secondDy = secondEnd.y - secondStart.y;
  final denominator = firstDx * secondDy - firstDy * secondDx;
  if (denominator.abs() < 1e-10) {
    return null;
  }

  final diffX = secondStart.x - firstStart.x;
  final diffY = secondStart.y - firstStart.y;
  final firstT = (diffX * secondDy - diffY * secondDx) / denominator;
  final secondT = (diffX * firstDy - diffY * firstDx) / denominator;
  if (firstT <= 1e-6 || firstT >= 1 - 1e-6) {
    return null;
  }
  if (secondT <= 1e-6 || secondT >= 1 - 1e-6) {
    return null;
  }

  return SvgPoint(
    firstStart.x + firstT * firstDx,
    firstStart.y + firstT * firstDy,
  );
}

List<SvgPoint> _flattenArc(SvgContourSegment segment) {
  final rxInput = segment.rx ?? 0;
  final ryInput = segment.ry ?? 0;
  if (rxInput <= 0 || ryInput <= 0) return [segment.end];

  final start = segment.start;
  final end = segment.end;
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
  final denominator = rxSq * y1PrimeSq + rySq * x1PrimeSq;
  if (denominator.abs() < 1e-12) return [segment.end];

  final numerator = rxSq * rySq - rxSq * y1PrimeSq - rySq * x1PrimeSq;
  final sign = segment.largeArc == segment.sweep ? -1.0 : 1.0;
  final factor = sign * math.sqrt(math.max(0, numerator / denominator));

  final cxPrime = factor * (rx * y1Prime / ry);
  final cyPrime = factor * (-ry * x1Prime / rx);
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

  final stepCount = math.max(
    4,
    ((deltaTheta.abs() / (2 * math.pi)) * 32).ceil(),
  );
  final points = <SvgPoint>[];
  for (var step = 1; step <= stepCount; step += 1) {
    final t = step / stepCount;
    final theta = theta1 + deltaTheta * t;
    final cosTheta = math.cos(theta);
    final sinTheta = math.sin(theta);
    points.add(
      SvgPoint(
        cosPhi * rx * cosTheta - sinPhi * ry * sinTheta + cx,
        sinPhi * rx * cosTheta + cosPhi * ry * sinTheta + cy,
      ),
    );
  }
  return points;
}

void _flattenCubic(
  SvgPoint p0,
  SvgPoint p1,
  SvgPoint p2,
  SvgPoint p3,
  List<SvgPoint> output,
) {
  const steps = 8;
  for (var step = 1; step <= steps; step += 1) {
    final t = step / steps;
    final u = 1 - t;
    output.add(
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
}

void _flattenQuadratic(
  SvgPoint p0,
  SvgPoint p1,
  SvgPoint p2,
  List<SvgPoint> output,
) {
  const steps = 8;
  for (var step = 1; step <= steps; step += 1) {
    final t = step / steps;
    final u = 1 - t;
    output.add(
      SvgPoint(
        u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
        u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y,
      ),
    );
  }
}
