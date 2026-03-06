import 'dart:math' as math;

import 'contour.dart';
import 'stroke_style.dart';
import 'svg_point_math.dart' as pt;

/// The offset points produced at a single polyline vertex join.
class JoinResult {
  const JoinResult({required this.outerPoints, required this.innerPoints});

  final List<SvgPoint> outerPoints;
  final List<SvgPoint> innerPoints;
}

/// Computes per-vertex offset geometry for stroke joins (miter, bevel, round).
class StrokeJoinBuilder {
  const StrokeJoinBuilder();

  /// Returns the left-side and right-side offset points at [current], where
  /// the incoming edge arrives from [prev] and the outgoing edge departs to
  /// [next].
  ///
  /// [isCorner] must be true for actual path corners (line endpoints, segment
  /// boundaries with a true direction change). Pass false at bezier subdivision
  /// points — the bisector midpoint is returned regardless of join style,
  /// preventing bumpy arcs on smooth curves.
  ///
  /// For actual corners the concave side always uses the sharp offset-line
  /// intersection, matching SVG stroke semantics. The convex side uses the
  /// selected [lineJoin] style.
  JoinResult computeOffsets(
    SvgPoint prev,
    SvgPoint current,
    SvgPoint next,
    double halfWidth,
    SvgStrokeLineJoin lineJoin,
    double miterLimit,
    bool isCorner, {
    SvgPoint? preferredTangent,
  }) {
    final dirIn = pt.direction(prev, current);
    final dirOut = pt.direction(current, next);
    final normalIn = SvgPoint(-dirIn.y, dirIn.x);
    final normalOut = SvgPoint(-dirOut.y, dirOut.x);

    final outerIn = SvgPoint(
      current.x + normalIn.x * halfWidth,
      current.y + normalIn.y * halfWidth,
    );
    final outerOut = SvgPoint(
      current.x + normalOut.x * halfWidth,
      current.y + normalOut.y * halfWidth,
    );
    final innerIn = SvgPoint(
      current.x - normalIn.x * halfWidth,
      current.y - normalIn.y * halfWidth,
    );
    final innerOut = SvgPoint(
      current.x - normalOut.x * halfWidth,
      current.y - normalOut.y * halfWidth,
    );

    final cross = dirIn.x * dirOut.y - dirIn.y * dirOut.x;
    final dot = dirIn.x * dirOut.x + dirIn.y * dirOut.y;

    if (!isCorner) {
      final tangentAlignment = dirIn.x * dirOut.x + dirIn.y * dirOut.y;
      if (preferredTangent != null && tangentAlignment > 0.97) {
        final normal = SvgPoint(-preferredTangent.y, preferredTangent.x);
        return JoinResult(
          outerPoints: [
            SvgPoint(
              current.x + normal.x * halfWidth,
              current.y + normal.y * halfWidth,
            ),
          ],
          innerPoints: [
            SvgPoint(
              current.x - normal.x * halfWidth,
              current.y - normal.y * halfWidth,
            ),
          ],
        );
      }

      final tangentX = dirIn.x + dirOut.x;
      final tangentY = dirIn.y + dirOut.y;
      final tangentLength = math.sqrt(
        tangentX * tangentX + tangentY * tangentY,
      );
      if (tangentLength < 1e-8) {
        final fallbackNormal = SvgPoint(-dirOut.y, dirOut.x);
        return JoinResult(
          outerPoints: [
            SvgPoint(
              current.x + fallbackNormal.x * halfWidth,
              current.y + fallbackNormal.y * halfWidth,
            ),
          ],
          innerPoints: [
            SvgPoint(
              current.x - fallbackNormal.x * halfWidth,
              current.y - fallbackNormal.y * halfWidth,
            ),
          ],
        );
      }

      final tangent = SvgPoint(
        tangentX / tangentLength,
        tangentY / tangentLength,
      );
      final normal = SvgPoint(-tangent.y, tangent.x);
      return JoinResult(
        outerPoints: [
          SvgPoint(
            current.x + normal.x * halfWidth,
            current.y + normal.y * halfWidth,
          ),
        ],
        innerPoints: [
          SvgPoint(
            current.x - normal.x * halfWidth,
            current.y - normal.y * halfWidth,
          ),
        ],
      );
    }

    final isNearTurnback = dot < -0.9;
    if (isNearTurnback) {
      switch (lineJoin) {
        case SvgStrokeLineJoin.round:
          return JoinResult(
            outerPoints: _buildArc(current, outerIn, outerOut, halfWidth),
            innerPoints: _buildArc(current, innerIn, innerOut, halfWidth),
          );
        case SvgStrokeLineJoin.bevel:
        case SvgStrokeLineJoin.miter:
          return JoinResult(
            outerPoints: [outerIn, outerOut],
            innerPoints: [innerIn, innerOut],
          );
      }
    }

    final incomingLength = pt.distance(prev, current);
    final outgoingLength = pt.distance(current, next);
    final minAdjacentLength = math.min(incomingLength, outgoingLength);
    final shouldMidpointBlend =
        lineJoin != SvgStrokeLineJoin.miter &&
        cross.abs() < 0.01 &&
        minAdjacentLength < halfWidth;
    if (shouldMidpointBlend) {
      return JoinResult(
        outerPoints: [_midpoint(outerIn, outerOut)],
        innerPoints: [_midpoint(innerIn, innerOut)],
      );
    }

    var outerCorner =
        _lineIntersection(
          outerIn,
          SvgPoint(outerIn.x + dirIn.x, outerIn.y + dirIn.y),
          outerOut,
          SvgPoint(outerOut.x - dirOut.x, outerOut.y - dirOut.y),
        ) ??
        _midpoint(outerIn, outerOut);
    var innerCorner =
        _lineIntersection(
          innerIn,
          SvgPoint(innerIn.x + dirIn.x, innerIn.y + dirIn.y),
          innerOut,
          SvgPoint(innerOut.x - dirOut.x, innerOut.y - dirOut.y),
        ) ??
        _midpoint(innerIn, innerOut);

    switch (lineJoin) {
      case SvgStrokeLineJoin.bevel:
        if (cross < 0) {
          return JoinResult(
            outerPoints: [outerIn, outerOut],
            innerPoints: [innerCorner],
          );
        } else {
          return JoinResult(
            outerPoints: [outerCorner],
            innerPoints: [innerIn, innerOut],
          );
        }

      case SvgStrokeLineJoin.round:
        if (cross < 0) {
          return JoinResult(
            outerPoints: _buildArc(current, outerIn, outerOut, halfWidth),
            innerPoints: [innerCorner],
          );
        } else {
          return JoinResult(
            outerPoints: [outerCorner],
            innerPoints: _buildArc(current, innerIn, innerOut, halfWidth),
          );
        }

      case SvgStrokeLineJoin.miter:
        final convexCorner = cross < 0 ? outerCorner : innerCorner;
        final miterRatio = pt.distance(current, convexCorner) / halfWidth;
        if (miterRatio > miterLimit) {
          if (cross < 0) {
            return JoinResult(
              outerPoints: [outerIn, outerOut],
              innerPoints: [innerCorner],
            );
          }
          return JoinResult(
            outerPoints: [outerCorner],
            innerPoints: [innerIn, innerOut],
          );
        }
        return JoinResult(
          outerPoints: [outerCorner],
          innerPoints: [innerCorner],
        );
    }
  }

  List<SvgPoint> _buildArc(
    SvgPoint center,
    SvgPoint from,
    SvgPoint to,
    double radius,
  ) {
    final startAngle = math.atan2(from.y - center.y, from.x - center.x);
    var endAngle = math.atan2(to.y - center.y, to.x - center.x);

    var sweep = endAngle - startAngle;
    if (sweep > math.pi) sweep -= 2 * math.pi;
    if (sweep < -math.pi) sweep += 2 * math.pi;

    const steps = 8;
    final points = <SvgPoint>[from];
    for (var step = 1; step < steps; step += 1) {
      final t = step / steps;
      final angle = startAngle + sweep * t;
      points.add(
        SvgPoint(
          center.x + radius * math.cos(angle),
          center.y + radius * math.sin(angle),
        ),
      );
    }
    points.add(to);
    return points;
  }

  SvgPoint _midpoint(SvgPoint a, SvgPoint b) {
    return SvgPoint((a.x + b.x) / 2, (a.y + b.y) / 2);
  }

  SvgPoint? _lineIntersection(
    SvgPoint p1,
    SvgPoint p2,
    SvgPoint p3,
    SvgPoint p4,
  ) {
    final d1x = p2.x - p1.x;
    final d1y = p2.y - p1.y;
    final d2x = p4.x - p3.x;
    final d2y = p4.y - p3.y;
    final denominator = d1x * d2y - d1y * d2x;
    if (denominator.abs() < 1e-10) return null;

    final t = ((p3.x - p1.x) * d2y - (p3.y - p1.y) * d2x) / denominator;
    return SvgPoint(p1.x + t * d1x, p1.y + t * d1y);
  }
}
