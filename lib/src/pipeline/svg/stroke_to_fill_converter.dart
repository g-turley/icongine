import 'dart:math' as math;

import 'contour.dart';
import 'document.dart';
import 'stroke_outline_assembler.dart';
import 'stroke_polyline_tagger.dart';

/// Converts stroked SVG paths into equivalent filled outlines by expanding
/// the path perpendicular to its direction by half the stroke width on each
/// side. Handles line caps and line joins.
///
/// Cubic and quadratic bezier segments are flattened to polylines before
/// offsetting, since exact bezier offset curves are mathematically complex.
/// To avoid spurious join geometry at bezier subdivision points, each
/// flattened vertex is tagged as either a true path corner or a curve
/// subdivision point. Join geometry (arcs, bevels, miters) is only applied
/// at actual corners; subdivision points use a bisector midpoint instead.
class StrokeToFillConverter {
  const StrokeToFillConverter({
    this.tagger = const StrokePolylineTagger(),
    this.assembler = const StrokeOutlineAssembler(),
  });

  final StrokePolylineTagger tagger;
  final StrokeOutlineAssembler assembler;

  SvgContourPath convert({
    required SvgContourPath sourcePath,
    required SvgStrokeProperties strokeProperties,
  }) {
    final halfWidth = strokeProperties.strokeWidthPixels / 2;
    final resultContours = <SvgContour>[];

    for (final contour in sourcePath.contours) {
      final hasCurveSegments = _contourHasCurveSegments(contour);
      final subdivisionSteps = _resolveCurveSubdivisionSteps(
        contour: contour,
        strokeProperties: strokeProperties,
        hasCurveSegments: hasCurveSegments,
      );
      final tagged = tagger.flatten(
        contour,
        halfWidth: halfWidth,
        subdivisionSteps: subdivisionSteps,
      );
      if (tagged.length < 2) continue;

      if (contour.isClosed) {
        final hasTightArcRadius = _hasArcWithRadiusAtMost(
          contour: contour,
          radiusThreshold: halfWidth,
        );
        final hasSharpCurveJoin = tagger.hasSharpCurveToCurveJoin(contour);
        final isCoarseClosedCurve = contour.segments.length <= 8;
        final shouldCleanupClosedSelfIntersections =
            strokeProperties.lineJoin == SvgStrokeLineJoin.round &&
            (hasTightArcRadius ||
                (hasCurveSegments &&
                    (isCoarseClosedCurve || hasSharpCurveJoin)));
        final sourceMinimumDimension = _contourMinimumDimension(contour);
        assembler.expandClosed(
          tagged,
          halfWidth,
          strokeProperties.lineJoin,
          strokeProperties.miterLimit,
          shouldCleanupClosedSelfIntersections,
          sourceMinimumDimension,
          resultContours,
        );
      } else {
        final sourceHasArcSegments = contour.segments.any(
          (segment) => segment.type == SvgContourSegmentType.arc,
        );
        final shouldCleanupRoundPolylineSelfIntersections =
            strokeProperties.lineJoin == SvgStrokeLineJoin.round &&
            tagged.length <= 8;
        assembler.expandOpen(
          tagged,
          halfWidth,
          strokeProperties.lineCap,
          strokeProperties.lineJoin,
          strokeProperties.miterLimit,
          sourceHasArcSegments || shouldCleanupRoundPolylineSelfIntersections,
          resultContours,
        );
      }
    }

    return SvgContourPath(contours: resultContours);
  }

  bool _contourHasCurveSegments(SvgContour contour) {
    return contour.segments.any((segment) => segment.type.isCurve);
  }

  int _resolveCurveSubdivisionSteps({
    required SvgContour contour,
    required SvgStrokeProperties strokeProperties,
    required bool hasCurveSegments,
  }) {
    if (!hasCurveSegments) {
      return tagger.curveSubdivisions;
    }

    final baseSubdivisions = tagger.curveSubdivisions;
    final usesRoundClosedStroke =
        contour.isClosed &&
        strokeProperties.lineJoin == SvgStrokeLineJoin.round;
    if (!usesRoundClosedStroke) {
      return baseSubdivisions;
    }

    final isCoarseClosedCurve = contour.segments.length <= 8;
    if (!isCoarseClosedCurve) {
      return baseSubdivisions;
    }

    final hasSharpCurveJoin = tagger.hasSharpCurveToCurveJoin(contour);
    if (!hasSharpCurveJoin) {
      return baseSubdivisions;
    }

    // Root cause for visibly faceted round-corner shields/rings: fixed low
    // subdivision counts undersample coarse closed cubic paths with sharp
    // curve-to-curve joins before offset.
    final segmentCount = contour.segments.length;
    if (segmentCount <= 4) {
      return math.max(baseSubdivisions, 32);
    }
    if (segmentCount <= 8) {
      return math.max(baseSubdivisions, 24);
    }
    return baseSubdivisions;
  }

  double _contourMinimumDimension(SvgContour contour) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;

    for (final segment in contour.segments) {
      minX = math.min(minX, math.min(segment.start.x, segment.end.x));
      minY = math.min(minY, math.min(segment.start.y, segment.end.y));
      maxX = math.max(maxX, math.max(segment.start.x, segment.end.x));
      maxY = math.max(maxY, math.max(segment.start.y, segment.end.y));
    }

    if (minX == double.infinity || minY == double.infinity) {
      return 0;
    }
    final width = maxX - minX;
    final height = maxY - minY;
    return math.min(width, height);
  }

  bool _hasArcWithRadiusAtMost({
    required SvgContour contour,
    required double radiusThreshold,
  }) {
    for (final segment in contour.segments) {
      if (segment.type != SvgContourSegmentType.arc) {
        continue;
      }
      final rx = segment.rx?.abs();
      final ry = segment.ry?.abs();
      if (rx == null || ry == null) {
        continue;
      }
      if (math.min(rx, ry) <= radiusThreshold + 1e-6) {
        return true;
      }
    }
    return false;
  }
}
