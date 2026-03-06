import 'dart:math' as math;

import 'contour.dart';
import 'document.dart';
import 'stroke_cap_builder.dart';
import 'stroke_join_builder.dart';
import 'stroke_polyline_tagger.dart';
import 'svg_point_math.dart' as pt;

/// Expands tagged polylines into closed stroke outline contours.
///
/// Handles both closed paths (producing an outer ring and an inner hole) and
/// open paths (producing a single closed outline with end caps). Optionally
/// removes small self-intersection loops that arise from tight round joins
/// on curved geometry.
class StrokeOutlineAssembler {
  const StrokeOutlineAssembler({
    this.joinBuilder = const StrokeJoinBuilder(),
    this.capBuilder = const StrokeCapBuilder(),
  });

  final StrokeJoinBuilder joinBuilder;
  final StrokeCapBuilder capBuilder;

  /// Expands a closed [tagged] polyline into an outer contour and an inner
  /// contour wound in opposite directions, producing a stroke ring.
  void expandClosed(
    List<TaggedPoint> tagged,
    double halfWidth,
    SvgStrokeLineJoin lineJoin,
    double miterLimit,
    bool enableSelfIntersectionCleanup,
    double sourceMinimumDimension,
    List<SvgContour> output,
  ) {
    final pointCount = tagged.length;
    final vertexCount =
        pt.pointsAreEqual(tagged.first.point, tagged.last.point) &&
            pointCount > 1
        ? pointCount - 1
        : pointCount;

    final outerPoints = <SvgPoint>[];
    final innerPoints = <SvgPoint>[];

    for (var index = 0; index < vertexCount; index += 1) {
      final prevIndex = (index - 1 + vertexCount) % vertexCount;
      final nextIndex = (index + 1) % vertexCount;

      final joinPoints = joinBuilder.computeOffsets(
        tagged[prevIndex].point,
        tagged[index].point,
        tagged[nextIndex].point,
        halfWidth,
        lineJoin,
        miterLimit,
        tagged[index].type == VertexType.corner,
        preferredTangent: tagged[index].tangent,
      );
      outerPoints.addAll(joinPoints.outerPoints);
      innerPoints.addAll(joinPoints.innerPoints);
    }

    final simplifiedOuterPoints = enableSelfIntersectionCleanup
        ? _removeSmallSelfIntersectionLoops(outerPoints)
        : outerPoints;
    final simplifiedInnerPoints = enableSelfIntersectionCleanup
        ? _removeSmallSelfIntersectionLoops(innerPoints)
        : innerPoints;

    final firstOffsetArea = _polygonSignedArea(simplifiedOuterPoints).abs();
    final secondOffsetArea = _polygonSignedArea(simplifiedInnerPoints).abs();
    final firstIsGeometricOuter = firstOffsetArea >= secondOffsetArea;
    final outerRingPoints = firstIsGeometricOuter
        ? simplifiedOuterPoints
        : simplifiedInnerPoints;
    final innerRingPoints = firstIsGeometricOuter
        ? simplifiedInnerPoints
        : simplifiedOuterPoints;

    final shouldCollapseDegenerateInner =
        sourceMinimumDimension <= (halfWidth * 2) + 1e-6;
    if (shouldCollapseDegenerateInner) {
      output.add(
        _closedContourFromPoints(
          _normalizeSolidOutlineWinding(outerRingPoints),
        ),
      );
      return;
    }

    output.add(
      _closedContourFromPoints(_normalizeSolidOutlineWinding(outerRingPoints)),
    );
    // Inner contour wound opposite the outer so CFF non-zero winding creates a hole.
    output.add(
      _closedContourFromPoints(_normalizeHoleOutlineWinding(innerRingPoints)),
    );
  }

  /// Expands an open [tagged] polyline into a single closed contour:
  /// forward along the left side, end cap, backward along the right side,
  /// start cap.
  void expandOpen(
    List<TaggedPoint> tagged,
    double halfWidth,
    SvgStrokeLineCap lineCap,
    SvgStrokeLineJoin lineJoin,
    double miterLimit,
    bool enableSelfIntersectionCleanup,
    List<SvgContour> output,
  ) {
    final leftSide = <SvgPoint>[];
    final rightSide = <SvgPoint>[];

    for (var index = 0; index < tagged.length; index += 1) {
      if (index == 0 || index == tagged.length - 1) {
        final SvgPoint direction;
        if (index == 0) {
          direction = pt.direction(tagged[0].point, tagged[1].point);
        } else {
          direction = pt.direction(
            tagged[tagged.length - 2].point,
            tagged[tagged.length - 1].point,
          );
        }
        final normal = SvgPoint(-direction.y, direction.x);
        leftSide.add(
          SvgPoint(
            tagged[index].point.x + normal.x * halfWidth,
            tagged[index].point.y + normal.y * halfWidth,
          ),
        );
        rightSide.add(
          SvgPoint(
            tagged[index].point.x - normal.x * halfWidth,
            tagged[index].point.y - normal.y * halfWidth,
          ),
        );
      } else {
        final joinPoints = joinBuilder.computeOffsets(
          tagged[index - 1].point,
          tagged[index].point,
          tagged[index + 1].point,
          halfWidth,
          lineJoin,
          miterLimit,
          tagged[index].type == VertexType.corner,
          preferredTangent: tagged[index].tangent,
        );
        leftSide.addAll(joinPoints.outerPoints);
        rightSide.addAll(joinPoints.innerPoints);
      }
    }

    final outlinePoints = <SvgPoint>[];

    outlinePoints.addAll(leftSide);

    final endDirection = pt.direction(
      tagged[tagged.length - 2].point,
      tagged[tagged.length - 1].point,
    );
    outlinePoints.addAll(
      capBuilder.build(tagged.last.point, endDirection, halfWidth, lineCap),
    );

    outlinePoints.addAll(rightSide.reversed);

    final startDirection = pt.direction(tagged[1].point, tagged[0].point);
    outlinePoints.addAll(
      capBuilder.build(tagged.first.point, startDirection, halfWidth, lineCap),
    );

    final maxSmallLoopAreaRatio = lineCap == SvgStrokeLineCap.round
        ? 0.01
        : 0.2;
    final simplifiedOutlinePoints = enableSelfIntersectionCleanup
        ? _removeSmallSelfIntersectionLoops(
            outlinePoints,
            maxSmallLoopAreaRatio: maxSmallLoopAreaRatio,
          )
        : outlinePoints;
    output.add(
      _closedContourFromPoints(
        _normalizeSolidOutlineWinding(simplifiedOutlinePoints),
      ),
    );
  }

  SvgContour _closedContourFromPoints(List<SvgPoint> points) {
    if (points.isEmpty) {
      return const SvgContour(segments: [], isClosed: true);
    }

    final segments = <SvgContourSegment>[];
    for (var index = 0; index < points.length; index += 1) {
      final start = points[index];
      final end = points[(index + 1) % points.length];
      segments.add(SvgContourSegment.line(start: start, end: end));
    }
    return SvgContour(segments: segments, isClosed: true);
  }

  List<SvgPoint> _removeSmallSelfIntersectionLoops(
    List<SvgPoint> points, {
    double maxSmallLoopAreaRatio = 0.12,
  }) {
    if (points.length < 4) {
      return points;
    }

    var vertices = List<SvgPoint>.from(points, growable: true);
    final interiorIntersectionCount = _countInteriorSelfIntersections(vertices);
    if (interiorIntersectionCount == 0 || interiorIntersectionCount > 12) {
      return vertices;
    }

    const maxIterations = 8;
    var currentArea = _polygonSignedArea(vertices).abs();
    for (var iteration = 0; iteration < maxIterations; iteration += 1) {
      final intersection = _findInteriorSelfIntersection(vertices);
      if (intersection == null) {
        break;
      }

      final firstLoop = <SvgPoint>[intersection.point];
      for (
        var index = intersection.firstSegmentIndex + 1;
        index <= intersection.secondSegmentIndex;
        index += 1
      ) {
        firstLoop.add(vertices[index]);
      }
      firstLoop.add(intersection.point);

      final secondLoop = <SvgPoint>[intersection.point];
      for (
        var index = intersection.secondSegmentIndex + 1;
        index < vertices.length;
        index += 1
      ) {
        secondLoop.add(vertices[index]);
      }
      for (var index = 0; index <= intersection.firstSegmentIndex; index += 1) {
        secondLoop.add(vertices[index]);
      }
      secondLoop.add(intersection.point);

      final firstArea = _polygonSignedArea(firstLoop).abs();
      final secondArea = _polygonSignedArea(secondLoop).abs();
      if (currentArea > 1e-6) {
        final smallerLoopArea = math.min(firstArea, secondArea);
        if (smallerLoopArea / currentArea > maxSmallLoopAreaRatio) {
          break;
        }
      }
      final selectedLoop = firstArea >= secondArea ? firstLoop : secondLoop;
      vertices = _normalizeLoopVertices(selectedLoop);
      if (vertices.length < 3) {
        break;
      }
      currentArea = _polygonSignedArea(vertices).abs();
    }

    return vertices;
  }

  int _countInteriorSelfIntersections(List<SvgPoint> vertices) {
    var count = 0;
    final vertexCount = vertices.length;
    for (var firstIndex = 0; firstIndex < vertexCount; firstIndex += 1) {
      final firstNext = (firstIndex + 1) % vertexCount;
      final firstStart = vertices[firstIndex];
      final firstEnd = vertices[firstNext];

      for (
        var secondIndex = firstIndex + 1;
        secondIndex < vertexCount;
        secondIndex += 1
      ) {
        final isAdjacent =
            secondIndex == firstIndex ||
            secondIndex == firstIndex + 1 ||
            (firstIndex == 0 && secondIndex == vertexCount - 1);
        if (isAdjacent) {
          continue;
        }

        final secondNext = (secondIndex + 1) % vertexCount;
        final secondStart = vertices[secondIndex];
        final secondEnd = vertices[secondNext];
        final intersection = _segmentInteriorIntersection(
          firstStart,
          firstEnd,
          secondStart,
          secondEnd,
        );
        if (intersection != null) {
          count += 1;
          if (count > 2) {
            return count;
          }
        }
      }
    }
    return count;
  }

  _SelfIntersection? _findInteriorSelfIntersection(List<SvgPoint> vertices) {
    final count = vertices.length;
    for (var firstIndex = 0; firstIndex < count; firstIndex += 1) {
      final firstNext = (firstIndex + 1) % count;
      final firstStart = vertices[firstIndex];
      final firstEnd = vertices[firstNext];

      for (
        var secondIndex = firstIndex + 1;
        secondIndex < count;
        secondIndex += 1
      ) {
        final secondNext = (secondIndex + 1) % count;
        final isAdjacent =
            secondIndex == firstIndex ||
            secondIndex == firstIndex + 1 ||
            (firstIndex == 0 && secondIndex == count - 1);
        if (isAdjacent) {
          continue;
        }

        final secondStart = vertices[secondIndex];
        final secondEnd = vertices[secondNext];
        final intersection = _segmentInteriorIntersection(
          firstStart,
          firstEnd,
          secondStart,
          secondEnd,
        );
        if (intersection != null) {
          return _SelfIntersection(
            firstSegmentIndex: firstIndex,
            secondSegmentIndex: secondIndex,
            point: intersection,
          );
        }
      }
    }
    return null;
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

  List<SvgPoint> _normalizeLoopVertices(List<SvgPoint> loop) {
    if (loop.isEmpty) {
      return const [];
    }

    final normalized = <SvgPoint>[loop.first];
    for (var index = 1; index < loop.length; index += 1) {
      final candidate = loop[index];
      if (pt.pointsAreEqual(normalized.last, candidate)) {
        continue;
      }
      normalized.add(candidate);
    }

    if (normalized.length > 1 &&
        pt.pointsAreEqual(normalized.first, normalized.last)) {
      normalized.removeLast();
    }
    return normalized;
  }

  double _polygonSignedArea(List<SvgPoint> polygon) {
    if (polygon.length < 3) {
      return 0;
    }

    var area = 0.0;
    for (var index = 0; index < polygon.length; index += 1) {
      final current = polygon[index];
      final next = polygon[(index + 1) % polygon.length];
      area += current.x * next.y - next.x * current.y;
    }
    return area / 2;
  }

  List<SvgPoint> _normalizeSolidOutlineWinding(List<SvgPoint> points) {
    if (points.length < 3) {
      return points;
    }
    final area = _polygonSignedArea(points);
    if (area < 0) {
      return points.reversed.toList(growable: false);
    }
    return points;
  }

  List<SvgPoint> _normalizeHoleOutlineWinding(List<SvgPoint> points) {
    if (points.length < 3) {
      return points;
    }
    final area = _polygonSignedArea(points);
    if (area > 0) {
      return points.reversed.toList(growable: false);
    }
    return points;
  }
}

class _SelfIntersection {
  const _SelfIntersection({
    required this.firstSegmentIndex,
    required this.secondSegmentIndex,
    required this.point,
  });

  final int firstSegmentIndex;
  final int secondSegmentIndex;
  final SvgPoint point;
}
