import 'dart:math' as math;

import 'contour.dart';
import 'contour_flattener.dart';
import 'svg_point_math.dart' as pt;

/// Vertex classification in a flattened stroke polyline.
///
/// [corner] marks actual path corners (line endpoints, segment boundaries
/// with a true direction change). [curveSubdivision] marks interior points
/// of a flattened bezier or arc, where join geometry should not be applied.
enum VertexType { corner, curveSubdivision }

/// A polyline vertex with its [VertexType] classification and an optional
/// pre-computed tangent for smooth curve-to-curve joins.
class TaggedPoint {
  const TaggedPoint(this.point, this.type, {this.tangent});

  final SvgPoint point;
  final VertexType type;
  final SvgPoint? tangent;
}

/// Flattens SVG contours into tagged polylines for stroke expansion.
///
/// Each vertex is classified as a [VertexType.corner] or a
/// [VertexType.curveSubdivision] so the outline assembler can apply join
/// geometry only at actual corners, preventing bumpy arcs on smooth curves.
class StrokePolylineTagger {
  const StrokePolylineTagger({this.curveSubdivisions = 16});

  /// Number of line segments used to approximate each cubic/quadratic curve.
  final int curveSubdivisions;

  /// Flattens [contour] into a tagged polyline.
  ///
  /// [halfWidth] is used to collapse micro-segments smaller than 5% of the
  /// stroke width, which often come from path data noise like `v.2` / `v-.1`.
  /// [subdivisionSteps] controls how many segments bezier/quadratic curves are
  /// split into (pass [curveSubdivisions] or an adjusted value for coarse paths).
  List<TaggedPoint> flatten(
    SvgContour contour, {
    required double halfWidth,
    required int subdivisionSteps,
  }) {
    if (contour.segments.isEmpty) return const [];

    // For a closed contour where both the first and last segments are
    // curves, the start vertex lies between two bezier segments and is a
    // smooth continuation — tag it as curveSubdivision. Otherwise it's a
    // true corner (e.g. where a line meets the first bezier).
    final firstSeg = contour.segments.first;
    final lastSeg = contour.segments.last;
    final hasImplicitCloseLine =
        contour.isClosed && !pt.pointsAreEqual(lastSeg.end, firstSeg.start);
    final strictSmoothCurveJoinDetection =
        contour.isClosed && contour.segments.length <= 8;
    final startType =
        (contour.isClosed &&
            !hasImplicitCloseLine &&
            firstSeg.type.isCurve &&
            lastSeg.type.isCurve &&
            _isSmoothCurveJoin(
              lastSeg,
              firstSeg,
              strict: strictSmoothCurveJoinDetection,
            ))
        ? VertexType.curveSubdivision
        : VertexType.corner;

    final startTangent = startType == VertexType.curveSubdivision
        ? _segmentTangentAtStart(firstSeg)
        : null;
    final points = <TaggedPoint>[
      TaggedPoint(
        contour.segments.first.start,
        startType,
        tangent: startTangent,
      ),
    ];

    final segCount = contour.segments.length;

    for (var segIndex = 0; segIndex < segCount; segIndex += 1) {
      final segment = contour.segments[segIndex];

      final nextSegment = contour.isClosed
          ? ((hasImplicitCloseLine && segIndex == segCount - 1)
                ? null
                : contour.segments[(segIndex + 1) % segCount])
          : (segIndex + 1 < segCount ? contour.segments[segIndex + 1] : null);
      final nextIsCurve = nextSegment != null && nextSegment.type.isCurve;
      final isCurve = segment.type.isCurve;
      final nextCurveSegment = nextIsCurve ? nextSegment : null;
      final hasSmoothCurveJoin =
          isCurve &&
          nextCurveSegment != null &&
          _isSmoothCurveJoin(
            segment,
            nextCurveSegment,
            strict: strictSmoothCurveJoinDetection,
          );
      final endpointType = hasSmoothCurveJoin
          ? VertexType.curveSubdivision
          : VertexType.corner;

      switch (segment.type) {
        case SvgContourSegmentType.line:
          points.add(TaggedPoint(segment.end, VertexType.corner));
        case SvgContourSegmentType.cubic:
          final p0 = segment.start;
          final p1 = segment.control1!;
          final p2 = segment.control2!;
          final p3 = segment.end;
          for (var step = 1; step <= subdivisionSteps; step += 1) {
            final t = step / subdivisionSteps;
            final u = 1 - t;
            final isEndpoint = step == subdivisionSteps;
            final pointType = isEndpoint
                ? endpointType
                : VertexType.curveSubdivision;
            final tangent =
                isEndpoint && endpointType == VertexType.curveSubdivision
                ? _segmentTangentAtEnd(segment)
                : null;
            points.add(
              TaggedPoint(
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
                pointType,
                tangent: tangent,
              ),
            );
          }
        case SvgContourSegmentType.quadratic:
          final p0 = segment.start;
          final p1 = segment.control1!;
          final p2 = segment.end;
          for (var step = 1; step <= subdivisionSteps; step += 1) {
            final t = step / subdivisionSteps;
            final u = 1 - t;
            final isEndpoint = step == subdivisionSteps;
            final pointType = isEndpoint
                ? endpointType
                : VertexType.curveSubdivision;
            final tangent =
                isEndpoint && endpointType == VertexType.curveSubdivision
                ? _segmentTangentAtEnd(segment)
                : null;
            points.add(
              TaggedPoint(
                SvgPoint(
                  u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
                  u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y,
                ),
                pointType,
                tangent: tangent,
              ),
            );
          }
        case SvgContourSegmentType.arc:
          final arcPoints = flattenArcToPoints(
            segment,
            curveSteps: curveSubdivisions * 2,
          );
          for (
            var pointIndex = 0;
            pointIndex < arcPoints.length;
            pointIndex += 1
          ) {
            points.add(
              TaggedPoint(
                arcPoints[pointIndex],
                pointIndex == arcPoints.length - 1
                    ? endpointType
                    : VertexType.curveSubdivision,
                tangent:
                    pointIndex == arcPoints.length - 1 &&
                        endpointType == VertexType.curveSubdivision
                    ? _segmentTangentAtEnd(segment)
                    : null,
              ),
            );
          }
      }
    }

    return _deduplicateTaggedPoints(
      points,
      minPointDistance: math.max(1e-6, halfWidth * 0.05),
    );
  }

  /// Returns true if [contour] has any two adjacent curve segments with
  /// a sharp direction change between them (dot product of outgoing/incoming
  /// tangents below 0.8).
  bool hasSharpCurveToCurveJoin(SvgContour contour) {
    final segmentCount = contour.segments.length;
    if (!contour.isClosed || segmentCount < 2) {
      return false;
    }

    for (var segmentIndex = 0; segmentIndex < segmentCount; segmentIndex += 1) {
      final current = contour.segments[segmentIndex];
      final next = contour.segments[(segmentIndex + 1) % segmentCount];
      if (!current.type.isCurve || !next.type.isCurve) {
        continue;
      }

      final outgoing = _segmentTangentAtEnd(current);
      final incoming = _segmentTangentAtStart(next);
      final dot = outgoing.x * incoming.x + outgoing.y * incoming.y;
      if (dot < 0.8) {
        return true;
      }
    }

    return false;
  }

  List<TaggedPoint> _deduplicateTaggedPoints(
    List<TaggedPoint> points, {
    required double minPointDistance,
  }) {
    if (points.isEmpty) return const [];

    final deduplicated = <TaggedPoint>[points.first];
    for (var index = 1; index < points.length; index += 1) {
      final current = points[index];
      final last = deduplicated.last;
      final dx = last.point.x - current.point.x;
      final dy = last.point.y - current.point.y;
      final isNearDuplicate =
          (dx * dx + dy * dy) <= minPointDistance * minPointDistance;
      if (isNearDuplicate) {
        if (last.type == VertexType.curveSubdivision &&
            current.type == VertexType.corner) {
          deduplicated[deduplicated.length - 1] = current;
        }
        continue;
      }
      deduplicated.add(current);
    }

    return deduplicated;
  }

  bool _isSmoothCurveJoin(
    SvgContourSegment current,
    SvgContourSegment next, {
    required bool strict,
  }) {
    final outgoing = _segmentTangentAtEnd(current);
    final incoming = _segmentTangentAtStart(next);
    final dot = outgoing.x * incoming.x + outgoing.y * incoming.y;
    final arcInvolved =
        current.type == SvgContourSegmentType.arc ||
        next.type == SvgContourSegmentType.arc;
    final smoothThreshold = strict ? 0.8 : (arcInvolved ? 0.6 : -0.2);
    return dot > smoothThreshold;
  }

  SvgPoint _segmentTangentAtStart(SvgContourSegment segment) {
    switch (segment.type) {
      case SvgContourSegmentType.line:
        return pt.direction(segment.start, segment.end);
      case SvgContourSegmentType.cubic:
        return _normalized(
          segment.control1!.x - segment.start.x,
          segment.control1!.y - segment.start.y,
          fallback: pt.direction(segment.start, segment.end),
        );
      case SvgContourSegmentType.quadratic:
        return _normalized(
          segment.control1!.x - segment.start.x,
          segment.control1!.y - segment.start.y,
          fallback: pt.direction(segment.start, segment.end),
        );
      case SvgContourSegmentType.arc:
        return _arcTangent(segment, atEnd: false);
    }
  }

  SvgPoint _segmentTangentAtEnd(SvgContourSegment segment) {
    switch (segment.type) {
      case SvgContourSegmentType.line:
        return pt.direction(segment.start, segment.end);
      case SvgContourSegmentType.cubic:
        return _normalized(
          segment.end.x - segment.control2!.x,
          segment.end.y - segment.control2!.y,
          fallback: pt.direction(segment.start, segment.end),
        );
      case SvgContourSegmentType.quadratic:
        return _normalized(
          segment.end.x - segment.control1!.x,
          segment.end.y - segment.control1!.y,
          fallback: pt.direction(segment.start, segment.end),
        );
      case SvgContourSegmentType.arc:
        return _arcTangent(segment, atEnd: true);
    }
  }

  SvgPoint _arcTangent(SvgContourSegment segment, {required bool atEnd}) {
    final params = computeArcCenterParams(segment);
    if (params == null) {
      return pt.direction(segment.start, segment.end);
    }

    final theta = atEnd ? params.theta1 + params.deltaTheta : params.theta1;
    final directionSign = params.deltaTheta >= 0 ? 1.0 : -1.0;
    final dx =
        (-params.cosPhi * params.rx * math.sin(theta) -
            params.sinPhi * params.ry * math.cos(theta)) *
        directionSign;
    final dy =
        (-params.sinPhi * params.rx * math.sin(theta) +
            params.cosPhi * params.ry * math.cos(theta)) *
        directionSign;
    return _normalized(
      dx,
      dy,
      fallback: pt.direction(segment.start, segment.end),
    );
  }

  SvgPoint _normalized(double dx, double dy, {required SvgPoint fallback}) {
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1e-10) {
      return fallback;
    }
    return SvgPoint(dx / length, dy / length);
  }
}
