import 'dart:math' as math;

import 'contour.dart';

/// Fits closed raster loops using source-pixel units, independent of font size.
///
/// Base tolerances are 0.15px for simplification and 0.18px for cubic controls.
/// [toleranceScale] allows at most twice that error on larger source canvases.
/// Controls cannot overshoot chord ends; the caller checks topology.
class RasterCurveFitter {
  const RasterCurveFitter({this.toleranceScale = 1})
    : assert(toleranceScale >= 1 && toleranceScale <= 2);

  final double toleranceScale;

  SvgContour fit(List<SvgPoint> raw) {
    final corners = _restoreSquareCorners(_removeCollinear(raw));
    final points = _simplifyClosed(corners);
    if (points.length < 3) return rasterLineContour(raw);
    final sharp = List<bool>.generate(points.length, (i) {
      final p = points[(i + points.length - 1) % points.length];
      final c = points[i];
      final n = points[(i + 1) % points.length];
      final ax = p.x - c.x;
      final ay = p.y - c.y;
      final bx = n.x - c.x;
      final by = n.y - c.y;
      return math.atan2((ax * by - ay * bx).abs(), ax * bx + ay * by) <
          110 * math.pi / 180;
    });

    final segments = <SvgContourSegment>[];
    for (var i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      final a = points[i];
      final b = points[j];
      final previous = sharp[i]
          ? a
          : points[(i + points.length - 1) % points.length];
      final next = sharp[j] ? b : points[(j + 1) % points.length];
      final c1 = _constrain(
        SvgPoint(a.x + (b.x - previous.x) / 6, a.y + (b.y - previous.y) / 6),
        a,
        b,
      );
      final c2 = _constrain(
        SvgPoint(b.x - (next.x - a.x) / 6, b.y - (next.y - a.y) / 6),
        a,
        b,
      );
      final straight =
          sharp[i] && sharp[j] ||
          (_distanceToLine(c1, a, b) < 1e-8 &&
              _distanceToLine(c2, a, b) < 1e-8);
      segments.add(
        straight
            ? SvgContourSegment.line(start: a, end: b)
            : SvgContourSegment.cubic(
                start: a,
                control1: c1,
                control2: c2,
                end: b,
              ),
      );
    }
    return SvgContour(segments: segments, isClosed: true);
  }

  SvgPoint _constrain(SvgPoint control, SvgPoint a, SvgPoint b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1e-10) return a;
    final ux = dx / length;
    final uy = dy / length;
    final cx = control.x - a.x;
    final cy = control.y - a.y;
    final along = (cx * ux + cy * uy).clamp(0.0, length);
    final limit = 0.18 * toleranceScale;
    final across = (cy * ux - cx * uy).clamp(-limit, limit);
    return SvgPoint(
      a.x + along * ux - across * uy,
      a.y + along * uy + across * ux,
    );
  }

  List<SvgPoint> _removeCollinear(List<SvgPoint> points) {
    return [
      for (var i = 0; i < points.length; i++)
        if (_distanceToLine(
              points[i],
              points[(i + points.length - 1) % points.length],
              points[(i + 1) % points.length],
            ) >
            1e-8)
          points[i],
    ];
  }

  // Marching squares bevels binary rectangle corners by half a pixel. Recover
  // the intersection only when BOTH flanking edges are long and perpendicular;
  // this cannot mistake an isolated pixel or a short curve for a square corner.
  List<SvgPoint> _restoreSquareCorners(List<SvgPoint> points) {
    if (points.length < 6) return points;
    final result = <SvgPoint>[];
    final skipped = <int>{};
    for (var i = 0; i < points.length; i++) {
      if (skipped.contains(i)) continue;
      final p = points[(i + points.length - 1) % points.length];
      final a = points[i];
      final j = (i + 1) % points.length;
      final b = points[j];
      final n = points[(i + 2) % points.length];
      final ux = a.x - p.x;
      final uy = a.y - p.y;
      final vx = n.x - b.x;
      final vy = n.y - b.y;
      final cross = ux * vy - uy * vx;
      if (j != 0 &&
          !skipped.contains(j) &&
          ux * ux + uy * uy >= 2.25 &&
          vx * vx + vy * vy >= 2.25 &&
          (ux * vx + uy * vy).abs() < 1e-8 &&
          cross.abs() > 1e-8 &&
          _squaredDistance(a, b) <= 0.51) {
        final t = ((b.x - a.x) * vy - (b.y - a.y) * vx) / cross;
        final corner = SvgPoint(a.x + ux * t, a.y + uy * t);
        if (_squaredDistance(a, corner) <= 0.26 &&
            _squaredDistance(b, corner) <= 0.26) {
          result.add(corner);
          skipped.add(j);
          continue;
        }
      }
      result.add(a);
    }
    return result;
  }

  List<SvgPoint> _simplifyClosed(List<SvgPoint> points) {
    if (points.length <= 3) return points;
    var split = 1;
    for (var i = 2; i < points.length; i++) {
      if (_squaredDistance(points.first, points[i]) >
          _squaredDistance(points.first, points[split])) {
        split = i;
      }
    }
    final first = _simplifyOpen(points.sublist(0, split + 1));
    final second = _simplifyOpen([...points.sublist(split), points.first]);
    final result = [
      ...first.take(first.length - 1),
      ...second.take(second.length - 1),
    ];
    return result.length >= 3 ? result : points;
  }

  List<SvgPoint> _simplifyOpen(List<SvgPoint> points) {
    // Iterative Douglas-Peucker avoids recursion limits on large, noisy PNGs.
    final keep = List<bool>.filled(points.length, false);
    keep[0] = keep[points.length - 1] = true;
    final stack = <(int, int)>[(0, points.length - 1)];
    while (stack.isNotEmpty) {
      final (start, end) = stack.removeLast();
      var split = -1;
      var maximum = 0.15 * toleranceScale;
      for (var i = start + 1; i < end; i++) {
        final distance = _distanceToLine(points[i], points[start], points[end]);
        if (distance > maximum) {
          maximum = distance;
          split = i;
        }
      }
      if (split >= 0) {
        keep[split] = true;
        stack.add((start, split));
        stack.add((split, end));
      }
    }
    return [
      for (var i = 0; i < points.length; i++)
        if (keep[i]) points[i],
    ];
  }

  double _distanceToLine(SvgPoint p, SvgPoint a, SvgPoint b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared < 1e-20) return math.sqrt(_squaredDistance(p, a));
    final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared).clamp(
      0.0,
      1.0,
    );
    return math.sqrt(_squaredDistance(p, SvgPoint(a.x + dx * t, a.y + dy * t)));
  }

  double _squaredDistance(SvgPoint a, SvgPoint b) =>
      (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y);
}

SvgContour rasterLineContour(List<SvgPoint> points) => SvgContour(
  isClosed: true,
  segments: [
    for (var i = 0; i < points.length; i++)
      SvgContourSegment.line(
        start: points[i],
        end: points[(i + 1) % points.length],
      ),
  ],
);
