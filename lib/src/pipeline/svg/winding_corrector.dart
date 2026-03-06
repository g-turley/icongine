import 'dart:math' as math;

import 'contour.dart';
import 'contour_flattener.dart';

/// Corrects contour winding directions for CFF fonts which use the non-zero
/// winding rule.
///
/// SVG shapes that use `fill-rule: evenodd` depend on alternating fill regions
/// regardless of winding direction. CFF fonts always use non-zero winding,
/// so inner contours must wind in the opposite direction from outer contours
/// to create holes (e.g., the donut shape).
///
/// Uses point-in-polygon containment testing to determine actual nesting
/// depth rather than relying on area-based heuristics, which fail for
/// overlapping but non-nested contours (e.g., the "+" in an add icon).
class WindingCorrector {
  const WindingCorrector();

  /// Corrects winding directions so that after the SVG-to-font Y-flip:
  /// - Even-depth contours (outer surfaces) become counter-clockwise in
  ///   font space (the CFF "fill" direction).
  /// - Odd-depth contours (holes) become clockwise in font space (the CFF
  ///   "hole" direction).
  ///
  /// In SVG Y-down coordinates (before the Y-flip), this means:
  /// - Even-depth contours should have **positive** signed area (CW on screen).
  /// - Odd-depth contours should have **negative** signed area (CCW on screen).
  SvgContourPath correct(SvgContourPath contourPath) {
    final contours = contourPath.contours;
    if (contours.isEmpty) return contourPath;

    final signedAreas = <double>[
      for (final contour in contours) _signedArea(contour),
    ];

    final nestingDepths = _computeNestingDepths(contours);
    final corrected = List<SvgContour>.from(contours);

    for (var index = 0; index < contours.length; index += 1) {
      final depth = nestingDepths[index];
      final area = signedAreas[index];
      final isPositive = area >= 0;

      // Even depth → positive area (CW in SVG Y-down → CCW after Y-flip).
      // Odd depth  → negative area (CCW in SVG Y-down → CW after Y-flip).
      final shouldBePositive = depth.isEven;

      if (isPositive != shouldBePositive) {
        corrected[index] = _reverseContour(contours[index]);
      }
    }

    return SvgContourPath(contours: corrected);
  }

  /// Determines the nesting depth of each contour by counting how many other
  /// contours contain it. Uses point-in-polygon ray casting on a
  /// representative point from each contour.
  List<int> _computeNestingDepths(List<SvgContour> contours) {
    final depths = List<int>.filled(contours.length, 0);
    final absoluteAreas = <double>[
      for (final contour in contours) _signedArea(contour).abs(),
    ];

    // Flatten each contour to a polyline for containment testing.
    final polylines = <List<SvgPoint>>[
      for (final contour in contours) flattenContourToPolyline(contour),
    ];
    final contourSignatureKeys = <String>[
      for (final polyline in polylines) _contourSignatureKey(polyline),
    ];

    for (var target = 0; target < contours.length; target += 1) {
      final testPoint = _representativePoint(contours[target]);
      var depth = 0;
      final countedParentSignatures = <String>{};

      for (var candidate = 0; candidate < contours.length; candidate += 1) {
        if (candidate == target) continue;
        // Only larger contours can contribute to nesting depth.
        // This avoids false "parent" relationships where a small inner
        // contour happens to contain the target contour's representative
        // point (for example, ring-shaped glyphs).
        final candidateArea = absoluteAreas[candidate];
        final targetArea = absoluteAreas[target];
        if (candidateArea <= targetArea + 1e-9) continue;

        if (_polylineContainsPoint(polylines[candidate], testPoint)) {
          final signature = contourSignatureKeys[candidate];
          // Identical duplicated contours should contribute a single nesting
          // level. Repeated paths are common in source SVGs and represent
          // overdraw, not deeper hole parity.
          if (countedParentSignatures.add(signature)) {
            depth += 1;
          }
        }
      }

      depths[target] = depth;
    }

    return depths;
  }

  /// Returns a representative point from a contour for containment testing.
  /// Uses the centroid (average of all vertex positions) which lies inside
  /// the contour for convex and most simple polygons. A point on the
  /// boundary would give ambiguous ray casting results.
  SvgPoint _representativePoint(SvgContour contour) {
    if (contour.segments.isEmpty) return const SvgPoint(0, 0);

    var sumX = 0.0;
    var sumY = 0.0;
    var count = 0;

    for (final segment in contour.segments) {
      sumX += segment.start.x;
      sumY += segment.start.y;
      count += 1;

      // Include curve interior points for better centroid approximation.
      if (segment.type == SvgContourSegmentType.cubic) {
        final p0 = segment.start;
        final p1 = segment.control1!;
        final p2 = segment.control2!;
        final p3 = segment.end;
        for (final t in [0.25, 0.5, 0.75]) {
          final u = 1 - t;
          sumX +=
              u * u * u * p0.x +
              3 * u * u * t * p1.x +
              3 * u * t * t * p2.x +
              t * t * t * p3.x;
          sumY +=
              u * u * u * p0.y +
              3 * u * u * t * p1.y +
              3 * u * t * t * p2.y +
              t * t * t * p3.y;
          count += 1;
        }
      }
    }

    if (count == 0) return const SvgPoint(0, 0);
    return SvgPoint(sumX / count, sumY / count);
  }

  /// Tests whether a point is inside a polyline (treated as a closed polygon)
  /// using the ray casting algorithm.
  bool _polylineContainsPoint(List<SvgPoint> polyline, SvgPoint point) {
    if (polyline.length < 3) return false;

    var crossings = 0;
    for (var index = 0; index < polyline.length; index += 1) {
      final a = polyline[index];
      final b = polyline[(index + 1) % polyline.length];

      // Check if a horizontal ray from point going right crosses this edge.
      if ((a.y <= point.y && b.y > point.y) ||
          (b.y <= point.y && a.y > point.y)) {
        final intersectX = a.x + (point.y - a.y) / (b.y - a.y) * (b.x - a.x);
        if (point.x < intersectX) {
          crossings += 1;
        }
      }
    }

    return crossings.isOdd;
  }

  String _contourSignatureKey(List<SvgPoint> polyline) {
    if (polyline.isEmpty) return 'empty';
    final normalized = _normalizeClosedPolyline(polyline);
    final buffer = StringBuffer();
    for (final point in normalized) {
      final quantizedX = (point.x * 1000).round();
      final quantizedY = (point.y * 1000).round();
      buffer.write('$quantizedX:$quantizedY;');
    }
    return buffer.toString();
  }

  List<SvgPoint> _normalizeClosedPolyline(List<SvgPoint> polyline) {
    if (polyline.length <= 1) {
      return List<SvgPoint>.from(polyline);
    }

    final loop = List<SvgPoint>.from(polyline);
    if (_pointsEqual(loop.first, loop.last)) {
      loop.removeLast();
    }
    if (loop.isEmpty) {
      return const [];
    }

    final forward = _lexicographicallyMinimalRotation(loop);
    final reversed = _lexicographicallyMinimalRotation(loop.reversed.toList());
    return _comparePointLists(forward, reversed) <= 0 ? forward : reversed;
  }

  List<SvgPoint> _lexicographicallyMinimalRotation(List<SvgPoint> points) {
    var bestStart = 0;
    for (
      var candidateStart = 1;
      candidateStart < points.length;
      candidateStart += 1
    ) {
      final comparison = _compareRotations(points, candidateStart, bestStart);
      if (comparison < 0) {
        bestStart = candidateStart;
      }
    }

    final rotated = <SvgPoint>[];
    for (var index = 0; index < points.length; index += 1) {
      rotated.add(points[(bestStart + index) % points.length]);
    }
    return rotated;
  }

  int _compareRotations(
    List<SvgPoint> points,
    int firstStart,
    int secondStart,
  ) {
    for (var offset = 0; offset < points.length; offset += 1) {
      final first = points[(firstStart + offset) % points.length];
      final second = points[(secondStart + offset) % points.length];
      final comparison = _comparePoint(first, second);
      if (comparison != 0) {
        return comparison;
      }
    }
    return 0;
  }

  int _comparePointLists(List<SvgPoint> first, List<SvgPoint> second) {
    final commonLength = math.min(first.length, second.length);
    for (var index = 0; index < commonLength; index += 1) {
      final comparison = _comparePoint(first[index], second[index]);
      if (comparison != 0) {
        return comparison;
      }
    }
    if (first.length == second.length) return 0;
    return first.length < second.length ? -1 : 1;
  }

  int _comparePoint(SvgPoint first, SvgPoint second) {
    final quantizedFirstX = (first.x * 1000).round();
    final quantizedSecondX = (second.x * 1000).round();
    if (quantizedFirstX != quantizedSecondX) {
      return quantizedFirstX < quantizedSecondX ? -1 : 1;
    }
    final quantizedFirstY = (first.y * 1000).round();
    final quantizedSecondY = (second.y * 1000).round();
    if (quantizedFirstY != quantizedSecondY) {
      return quantizedFirstY < quantizedSecondY ? -1 : 1;
    }
    return 0;
  }

  bool _pointsEqual(SvgPoint first, SvgPoint second) {
    return (first.x - second.x).abs() < 1e-6 &&
        (first.y - second.y).abs() < 1e-6;
  }

  /// Computes the signed area of a contour using the shoelace formula.
  /// In SVG Y-down coordinates: positive = clockwise on screen,
  /// negative = counter-clockwise on screen.
  double _signedArea(SvgContour contour) {
    final polyline = flattenContourToPolyline(contour);
    if (polyline.length < 3) return 0;

    var area = 0.0;
    for (var index = 0; index < polyline.length; index += 1) {
      final current = polyline[index];
      final next = polyline[(index + 1) % polyline.length];
      area += current.x * next.y - next.x * current.y;
    }
    return area / 2;
  }

  SvgContour _reverseContour(SvgContour contour) {
    final reversedSegments = <SvgContourSegment>[];
    for (final segment in contour.segments.reversed) {
      switch (segment.type) {
        case SvgContourSegmentType.line:
          reversedSegments.add(
            SvgContourSegment.line(start: segment.end, end: segment.start),
          );
        case SvgContourSegmentType.cubic:
          reversedSegments.add(
            SvgContourSegment.cubic(
              start: segment.end,
              control1: segment.control2!,
              control2: segment.control1!,
              end: segment.start,
            ),
          );
        case SvgContourSegmentType.quadratic:
          reversedSegments.add(
            SvgContourSegment.quadratic(
              start: segment.end,
              control1: segment.control1!,
              end: segment.start,
            ),
          );
        case SvgContourSegmentType.arc:
          reversedSegments.add(
            SvgContourSegment.arc(
              start: segment.end,
              end: segment.start,
              rx: segment.rx!,
              ry: segment.ry!,
              xAxisRotation: segment.xAxisRotation!,
              largeArc: segment.largeArc!,
              sweep: !(segment.sweep ?? false),
            ),
          );
      }
    }
    return SvgContour(segments: reversedSegments, isClosed: contour.isClosed);
  }
}
