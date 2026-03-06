import 'contour.dart';
import 'contour_flattener.dart';
import 'stroke_style.dart';

class SvgRectClipper {
  const SvgRectClipper();

  static const double _epsilon = 1e-9;

  SvgContourPath clipPath(SvgContourPath contourPath, SvgClipRect clipRect) {
    if (!clipRect.isValid) {
      return const SvgContourPath(contours: []);
    }
    final clippedContours = <SvgContour>[];
    for (final contour in contourPath.contours) {
      clippedContours.addAll(_clipContour(contour, clipRect));
    }
    return SvgContourPath(contours: clippedContours);
  }

  List<SvgContour> _clipContour(SvgContour contour, SvgClipRect clipRect) {
    if (contour.segments.isEmpty) {
      return const [];
    }
    final polyline = flattenContourToPolyline(contour, curveSteps: 16);
    if (polyline.length < 2) {
      return const [];
    }
    if (polyline.every((point) => _pointInsideRect(point, clipRect))) {
      return [contour];
    }
    if (contour.isClosed) {
      final polygon = _clipClosedPolygon(polyline, clipRect);
      if (polygon.length < 3) {
        return const [];
      }
      return [_polylineToContour(polygon, isClosed: true)];
    }
    final polylines = _clipOpenPolyline(polyline, clipRect);
    return polylines
        .where((points) => points.length >= 2)
        .map((points) => _polylineToContour(points, isClosed: false))
        .toList(growable: false);
  }

  List<SvgPoint> _clipClosedPolygon(List<SvgPoint> polyline, SvgClipRect rect) {
    var polygon = _removeClosingDuplicate(polyline);
    if (polygon.length < 3) {
      return const [];
    }
    polygon = _clipPolygonToLeft(polygon, rect.minX);
    polygon = _clipPolygonToRight(polygon, rect.maxX);
    polygon = _clipPolygonToBottom(polygon, rect.minY);
    polygon = _clipPolygonToTop(polygon, rect.maxY);
    polygon = _dedupeConsecutivePoints(polygon);
    return polygon;
  }

  List<List<SvgPoint>> _clipOpenPolyline(
    List<SvgPoint> polyline,
    SvgClipRect rect,
  ) {
    final result = <List<SvgPoint>>[];
    List<SvgPoint>? current;

    for (var index = 0; index < polyline.length - 1; index += 1) {
      final segmentStart = polyline[index];
      final segmentEnd = polyline[index + 1];
      final clipped = _clipLineSegmentToRect(segmentStart, segmentEnd, rect);
      if (clipped == null) {
        if (current != null && current.length >= 2) {
          result.add(_dedupeConsecutivePoints(current));
        }
        current = null;
        continue;
      }

      if (current == null) {
        current = [clipped.start, clipped.end];
        continue;
      }

      if (_pointsEqual(current.last, clipped.start)) {
        current.add(clipped.end);
      } else {
        if (current.length >= 2) {
          result.add(_dedupeConsecutivePoints(current));
        }
        current = [clipped.start, clipped.end];
      }
    }

    if (current != null && current.length >= 2) {
      result.add(_dedupeConsecutivePoints(current));
    }
    return result;
  }

  List<SvgPoint> _clipPolygonToLeft(List<SvgPoint> polygon, double leftX) {
    return _clipPolygon(
      polygon,
      isInside: (point) => point.x >= leftX - _epsilon,
      intersect: (start, end) => _intersectWithVertical(start, end, leftX),
    );
  }

  List<SvgPoint> _clipPolygonToRight(List<SvgPoint> polygon, double rightX) {
    return _clipPolygon(
      polygon,
      isInside: (point) => point.x <= rightX + _epsilon,
      intersect: (start, end) => _intersectWithVertical(start, end, rightX),
    );
  }

  List<SvgPoint> _clipPolygonToBottom(List<SvgPoint> polygon, double bottomY) {
    return _clipPolygon(
      polygon,
      isInside: (point) => point.y >= bottomY - _epsilon,
      intersect: (start, end) => _intersectWithHorizontal(start, end, bottomY),
    );
  }

  List<SvgPoint> _clipPolygonToTop(List<SvgPoint> polygon, double topY) {
    return _clipPolygon(
      polygon,
      isInside: (point) => point.y <= topY + _epsilon,
      intersect: (start, end) => _intersectWithHorizontal(start, end, topY),
    );
  }

  List<SvgPoint> _clipPolygon(
    List<SvgPoint> polygon, {
    required bool Function(SvgPoint point) isInside,
    required SvgPoint Function(SvgPoint start, SvgPoint end) intersect,
  }) {
    if (polygon.isEmpty) {
      return const [];
    }
    final output = <SvgPoint>[];
    var previous = polygon.last;
    var previousInside = isInside(previous);
    for (final current in polygon) {
      final currentInside = isInside(current);
      if (currentInside) {
        if (!previousInside) {
          output.add(intersect(previous, current));
        }
        output.add(current);
      } else if (previousInside) {
        output.add(intersect(previous, current));
      }
      previous = current;
      previousInside = currentInside;
    }
    return output;
  }

  _LineSegment? _clipLineSegmentToRect(
    SvgPoint start,
    SvgPoint end,
    SvgClipRect rect,
  ) {
    var t0 = 0.0;
    var t1 = 1.0;
    final dx = end.x - start.x;
    final dy = end.y - start.y;

    bool clip(double p, double q) {
      if (p.abs() < _epsilon) {
        return q >= 0;
      }
      final r = q / p;
      if (p < 0) {
        if (r > t1) {
          return false;
        }
        if (r > t0) {
          t0 = r;
        }
      } else {
        if (r < t0) {
          return false;
        }
        if (r < t1) {
          t1 = r;
        }
      }
      return true;
    }

    if (!clip(-dx, start.x - rect.minX)) return null;
    if (!clip(dx, rect.maxX - start.x)) return null;
    if (!clip(-dy, start.y - rect.minY)) return null;
    if (!clip(dy, rect.maxY - start.y)) return null;

    final clippedStart = SvgPoint(start.x + t0 * dx, start.y + t0 * dy);
    final clippedEnd = SvgPoint(start.x + t1 * dx, start.y + t1 * dy);
    return _LineSegment(start: clippedStart, end: clippedEnd);
  }

  SvgContour _polylineToContour(
    List<SvgPoint> points, {
    required bool isClosed,
  }) {
    final normalized = _dedupeConsecutivePoints(points);
    if (isClosed && normalized.isNotEmpty) {
      normalized.add(normalized.first);
    }
    final segments = <SvgContourSegment>[];
    for (var index = 0; index < normalized.length - 1; index += 1) {
      final start = normalized[index];
      final end = normalized[index + 1];
      if (_pointsEqual(start, end)) {
        continue;
      }
      segments.add(SvgContourSegment.line(start: start, end: end));
    }
    return SvgContour(segments: segments, isClosed: isClosed);
  }

  List<SvgPoint> _removeClosingDuplicate(List<SvgPoint> polyline) {
    final points = List<SvgPoint>.from(polyline);
    if (points.length >= 2 && _pointsEqual(points.first, points.last)) {
      points.removeLast();
    }
    return _dedupeConsecutivePoints(points);
  }

  List<SvgPoint> _dedupeConsecutivePoints(List<SvgPoint> points) {
    if (points.isEmpty) {
      return points;
    }
    final deduped = <SvgPoint>[points.first];
    for (var index = 1; index < points.length; index += 1) {
      if (_pointsEqual(deduped.last, points[index])) {
        continue;
      }
      deduped.add(points[index]);
    }
    return deduped;
  }

  SvgPoint _intersectWithVertical(SvgPoint start, SvgPoint end, double x) {
    final dx = end.x - start.x;
    if (dx.abs() < _epsilon) {
      return SvgPoint(x, start.y);
    }
    final t = (x - start.x) / dx;
    return SvgPoint(x, start.y + (end.y - start.y) * t);
  }

  SvgPoint _intersectWithHorizontal(SvgPoint start, SvgPoint end, double y) {
    final dy = end.y - start.y;
    if (dy.abs() < _epsilon) {
      return SvgPoint(start.x, y);
    }
    final t = (y - start.y) / dy;
    return SvgPoint(start.x + (end.x - start.x) * t, y);
  }

  bool _pointsEqual(SvgPoint first, SvgPoint second) {
    return (first.x - second.x).abs() < _epsilon &&
        (first.y - second.y).abs() < _epsilon;
  }

  bool _pointInsideRect(SvgPoint point, SvgClipRect rect) {
    return point.x >= rect.minX - _epsilon &&
        point.x <= rect.maxX + _epsilon &&
        point.y >= rect.minY - _epsilon &&
        point.y <= rect.maxY + _epsilon;
  }
}

class _LineSegment {
  const _LineSegment({required this.start, required this.end});

  final SvgPoint start;
  final SvgPoint end;
}
