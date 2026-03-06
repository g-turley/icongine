import 'dart:math' as math;

import 'contour.dart';
import 'contour_flattener.dart';

/// Transforms [SvgContourPath] coordinates from SVG viewport space
/// (top-left origin, Y-axis pointing down) into font coordinate space
/// (bottom-left origin, Y-axis pointing up), scaled to [targetUnitsPerEm].
///
/// The Y-axis flip naturally reverses winding direction, converting SVG's
/// clockwise outer contours to the counter-clockwise convention required
/// by CFF/TrueType filled outlines.
class SvgToFontCoordinateTransformer {
  const SvgToFontCoordinateTransformer({
    this.edgeInsetUnits = 1.0,
    this.contentScale = 1.0,
  }) : assert(contentScale > 0 && contentScale <= 1.0);

  final double edgeInsetUnits;
  final double contentScale;

  /// Returns a new [SvgContourPath] with every point scaled and Y-flipped.
  ///
  /// The scale factor is computed as `targetUnitsPerEm / max(sourceWidth, sourceHeight)`
  /// to preserve aspect ratio within the font's em-square.
  SvgContourPath transform({
    required SvgContourPath contourPath,
    required double sourceWidth,
    required double sourceHeight,
    required int targetUnitsPerEm,
    bool normalize = true,
    double? normalizationReferenceLongestSide,
  }) {
    final bounds = _measureBounds(contourPath);
    final effectiveWidth = normalize
        ? bounds?.width ?? sourceWidth
        : sourceWidth;
    final effectiveHeight = normalize
        ? bounds?.height ?? sourceHeight
        : sourceHeight;
    final longestSide =
        normalize &&
            normalizationReferenceLongestSide != null &&
            normalizationReferenceLongestSide > 0
        ? normalizationReferenceLongestSide
        : math.max(effectiveWidth, effectiveHeight);
    if (longestSide <= 0) {
      return contourPath;
    }

    final scaleFactor = (targetUnitsPerEm / longestSide) * contentScale;
    final sourceMinX = normalize ? bounds?.minX ?? 0 : 0.0;
    final sourceMaxY = normalize ? bounds?.maxY ?? sourceHeight : sourceHeight;
    final horizontalInsetUnits =
        (targetUnitsPerEm - (effectiveWidth * scaleFactor)) / 2;
    final verticalInsetUnits =
        (targetUnitsPerEm - (effectiveHeight * scaleFactor)) / 2;

    SvgPoint transformPoint(SvgPoint point) {
      return SvgPoint(
        (point.x - sourceMinX) * scaleFactor + horizontalInsetUnits,
        (sourceMaxY - point.y) * scaleFactor + verticalInsetUnits,
      );
    }

    final transformedContours = <SvgContour>[];
    for (final contour in contourPath.contours) {
      final transformedSegments = <SvgContourSegment>[];

      for (final segment in contour.segments) {
        switch (segment.type) {
          case SvgContourSegmentType.line:
            transformedSegments.add(
              SvgContourSegment.line(
                start: transformPoint(segment.start),
                end: transformPoint(segment.end),
              ),
            );
          case SvgContourSegmentType.cubic:
            transformedSegments.add(
              SvgContourSegment.cubic(
                start: transformPoint(segment.start),
                control1: transformPoint(segment.control1!),
                control2: transformPoint(segment.control2!),
                end: transformPoint(segment.end),
              ),
            );
          case SvgContourSegmentType.quadratic:
            transformedSegments.add(
              SvgContourSegment.quadratic(
                start: transformPoint(segment.start),
                control1: transformPoint(segment.control1!),
                end: transformPoint(segment.end),
              ),
            );
          case SvgContourSegmentType.arc:
            // Y-flip reflects the ellipse across the X axis in font space.
            // Reflection inverts sweep direction and rotation sign.
            transformedSegments.add(
              SvgContourSegment.arc(
                start: transformPoint(segment.start),
                end: transformPoint(segment.end),
                rx: segment.rx! * scaleFactor,
                ry: segment.ry! * scaleFactor,
                xAxisRotation: -segment.xAxisRotation!,
                largeArc: segment.largeArc!,
                sweep: !segment.sweep!,
              ),
            );
        }
      }

      transformedContours.add(
        SvgContour(
          segments: List.unmodifiable(transformedSegments),
          isClosed: contour.isClosed,
        ),
      );
    }

    final transformedPath = SvgContourPath(
      contours: List.unmodifiable(transformedContours),
    );
    if (!normalize) {
      return transformedPath;
    }

    return _finalizeNormalizedPlacement(
      contourPath: transformedPath,
      targetUnitsPerEm: targetUnitsPerEm,
    );
  }

  _ContourBounds? _measureBounds(SvgContourPath contourPath) {
    double? minX;
    double? minY;
    double? maxX;
    double? maxY;

    void includePoint(SvgPoint point) {
      minX = minX == null ? point.x : math.min(minX!, point.x);
      minY = minY == null ? point.y : math.min(minY!, point.y);
      maxX = maxX == null ? point.x : math.max(maxX!, point.x);
      maxY = maxY == null ? point.y : math.max(maxY!, point.y);
    }

    for (final contour in contourPath.contours) {
      final flattenedPoints = flattenContourToPolyline(contour, curveSteps: 16);
      for (final point in flattenedPoints) {
        includePoint(point);
      }
    }

    if (minX == null || minY == null || maxX == null || maxY == null) {
      return null;
    }
    return _ContourBounds(minX: minX!, minY: minY!, maxX: maxX!, maxY: maxY!);
  }

  SvgContourPath _finalizeNormalizedPlacement({
    required SvgContourPath contourPath,
    required int targetUnitsPerEm,
  }) {
    final initialBounds = _measureBounds(contourPath);
    if (initialBounds == null) {
      return contourPath;
    }

    var translatedPath = contourPath;
    var shiftX = 0.0;
    var shiftY = 0.0;
    if (initialBounds.minX < edgeInsetUnits) {
      shiftX = edgeInsetUnits - initialBounds.minX;
    }
    if (initialBounds.minY < edgeInsetUnits) {
      shiftY = edgeInsetUnits - initialBounds.minY;
    }
    if (shiftX != 0 || shiftY != 0) {
      translatedPath = _translatePath(
        translatedPath,
        shiftX: shiftX,
        shiftY: shiftY,
      );
    }

    final ascenderBounds = _measureBounds(translatedPath);
    if (ascenderBounds == null || ascenderBounds.maxY <= targetUnitsPerEm) {
      return translatedPath;
    }
    if (ascenderBounds.maxY <= 0) {
      return translatedPath;
    }

    final scale = targetUnitsPerEm / ascenderBounds.maxY;
    final scaledPath = SvgContourPath(
      contours: translatedPath.contours
          .map((contour) => _scaleContour(contour, scale))
          .toList(growable: false),
    );

    final scaledBounds = _measureBounds(scaledPath);
    if (scaledBounds == null || scaledBounds.maxY <= targetUnitsPerEm) {
      return scaledPath;
    }
    return _translatePath(
      scaledPath,
      shiftX: 0,
      shiftY: targetUnitsPerEm - scaledBounds.maxY,
    );
  }

  SvgContourPath _translatePath(
    SvgContourPath path, {
    required double shiftX,
    required double shiftY,
  }) {
    return SvgContourPath(
      contours: path.contours
          .map(
            (contour) =>
                _translateContour(contour, shiftX: shiftX, shiftY: shiftY),
          )
          .toList(growable: false),
    );
  }

  SvgContour _translateContour(
    SvgContour contour, {
    required double shiftX,
    required double shiftY,
  }) {
    return SvgContour(
      isClosed: contour.isClosed,
      segments: contour.segments
          .map(
            (segment) =>
                _translateSegment(segment, shiftX: shiftX, shiftY: shiftY),
          )
          .toList(growable: false),
    );
  }

  SvgContourSegment _translateSegment(
    SvgContourSegment segment, {
    required double shiftX,
    required double shiftY,
  }) {
    switch (segment.type) {
      case SvgContourSegmentType.line:
        return SvgContourSegment.line(
          start: _translatePoint(segment.start, shiftX: shiftX, shiftY: shiftY),
          end: _translatePoint(segment.end, shiftX: shiftX, shiftY: shiftY),
        );
      case SvgContourSegmentType.cubic:
        return SvgContourSegment.cubic(
          start: _translatePoint(segment.start, shiftX: shiftX, shiftY: shiftY),
          control1: _translatePoint(
            segment.control1!,
            shiftX: shiftX,
            shiftY: shiftY,
          ),
          control2: _translatePoint(
            segment.control2!,
            shiftX: shiftX,
            shiftY: shiftY,
          ),
          end: _translatePoint(segment.end, shiftX: shiftX, shiftY: shiftY),
        );
      case SvgContourSegmentType.quadratic:
        return SvgContourSegment.quadratic(
          start: _translatePoint(segment.start, shiftX: shiftX, shiftY: shiftY),
          control1: _translatePoint(
            segment.control1!,
            shiftX: shiftX,
            shiftY: shiftY,
          ),
          end: _translatePoint(segment.end, shiftX: shiftX, shiftY: shiftY),
        );
      case SvgContourSegmentType.arc:
        return SvgContourSegment.arc(
          start: _translatePoint(segment.start, shiftX: shiftX, shiftY: shiftY),
          end: _translatePoint(segment.end, shiftX: shiftX, shiftY: shiftY),
          rx: segment.rx!,
          ry: segment.ry!,
          xAxisRotation: segment.xAxisRotation!,
          largeArc: segment.largeArc!,
          sweep: segment.sweep!,
        );
    }
  }

  SvgContour _scaleContour(SvgContour contour, double scale) {
    return SvgContour(
      isClosed: contour.isClosed,
      segments: contour.segments
          .map((segment) => _scaleSegment(segment, scale))
          .toList(growable: false),
    );
  }

  SvgContourSegment _scaleSegment(SvgContourSegment segment, double scale) {
    switch (segment.type) {
      case SvgContourSegmentType.line:
        return SvgContourSegment.line(
          start: _scalePoint(segment.start, scale),
          end: _scalePoint(segment.end, scale),
        );
      case SvgContourSegmentType.cubic:
        return SvgContourSegment.cubic(
          start: _scalePoint(segment.start, scale),
          control1: _scalePoint(segment.control1!, scale),
          control2: _scalePoint(segment.control2!, scale),
          end: _scalePoint(segment.end, scale),
        );
      case SvgContourSegmentType.quadratic:
        return SvgContourSegment.quadratic(
          start: _scalePoint(segment.start, scale),
          control1: _scalePoint(segment.control1!, scale),
          end: _scalePoint(segment.end, scale),
        );
      case SvgContourSegmentType.arc:
        return SvgContourSegment.arc(
          start: _scalePoint(segment.start, scale),
          end: _scalePoint(segment.end, scale),
          rx: segment.rx! * scale,
          ry: segment.ry! * scale,
          xAxisRotation: segment.xAxisRotation!,
          largeArc: segment.largeArc!,
          sweep: segment.sweep!,
        );
    }
  }

  SvgPoint _scalePoint(SvgPoint point, double scale) {
    return SvgPoint(point.x * scale, point.y * scale);
  }

  SvgPoint _translatePoint(
    SvgPoint point, {
    required double shiftX,
    required double shiftY,
  }) {
    return SvgPoint(point.x + shiftX, point.y + shiftY);
  }
}

class _ContourBounds {
  const _ContourBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  double get width => maxX - minX;
  double get height => maxY - minY;
}
