import 'dart:math' as math;

import 'package:image/image.dart' as image;

import 'contour.dart';
import 'contour_flattener.dart';

/// Accepts fitted outlines only if confident alpha samples and nesting survive.
/// Curves are sampled at 16 steps for crossing checks; invalid fits fall back
/// as a whole so neighboring contours cannot acquire inconsistent boundaries.
class RasterTopologyGuard {
  const RasterTopologyGuard();

  bool accepts(
    image.Image raster,
    List<List<SvgPoint>> raw,
    List<SvgContour> fitted,
  ) {
    final loops = <List<SvgPoint>>[];
    for (var i = 0; i < fitted.length; i++) {
      final contour = fitted[i];
      for (final segment in contour.segments) {
        for (final p in [
          segment.start,
          segment.end,
          segment.control1,
          segment.control2,
        ]) {
          if (p == null) continue;
          if (!p.x.isFinite ||
              !p.y.isFinite ||
              p.x < 0 ||
              p.x > raster.width ||
              p.y < 0 ||
              p.y > raster.height) {
            return false;
          }
        }
      }
      final sampled = flattenContourToPolyline(contour, curveSteps: 16);
      if (sampled.length < 4) return false;
      final loop = sampled.sublist(0, sampled.length - 1);
      if (_area(raw[i]) * _area(loop) <= 0) return false;
      loops.add(loop);
    }
    if (_hasCrossings(loops)) return false;
    for (var i = 0; i < loops.length; i++) {
      for (var j = 0; j < loops.length; j++) {
        if (i == j) continue;
        if (_contains(raw[j], raw[i].first) !=
            _contains(loops[j], loops[i].first)) {
          return false;
        }
      }
    }

    // Keep confident interior/exterior samples (alpha outside 25–75%). Soft
    // antialiased samples encode coverage, not a hard inside/outside verdict.
    // Treating alpha=128 as certain was rejecting useful curve fits wholesale.
    for (var y = 0; y < raster.height; y++) {
      final scanY = y + 0.5;
      final intersections = <double>[];
      for (final loop in loops) {
        for (var i = 0; i < loop.length; i++) {
          final a = loop[i];
          final b = loop[(i + 1) % loop.length];
          if ((a.y > scanY) != (b.y > scanY)) {
            intersections.add(a.x + (scanY - a.y) * (b.x - a.x) / (b.y - a.y));
          }
        }
      }
      intersections.sort();
      var crossing = 0;
      for (var x = 0; x < raster.width; x++) {
        while (crossing < intersections.length &&
            intersections[crossing] < x + 0.5) {
          crossing++;
        }
        final alpha = raster.getPixel(x, y).aNormalized;
        if ((alpha <= 0.25 || alpha >= 0.75) &&
            crossing.isOdd != (alpha >= 0.5)) {
          return false;
        }
      }
    }
    return true;
  }

  bool _hasCrossings(List<List<SvgPoint>> loops) {
    final edges = <_Edge>[
      for (var c = 0; c < loops.length; c++)
        for (var i = 0; i < loops[c].length; i++)
          _Edge(loops[c][i], loops[c][(i + 1) % loops[c].length], c, i),
    ]..sort((a, b) => a.minX.compareTo(b.minX));
    final active = <_Edge>[];
    for (final edge in edges) {
      active.removeWhere((other) => other.maxX < edge.minX - 1e-9);
      for (final other in active) {
        if (other.maxY < edge.minY || edge.maxY < other.minY) continue;
        if (edge.contour == other.contour) {
          final separation = (edge.index - other.index).abs();
          if (separation == 1 || separation == loops[edge.contour].length - 1) {
            continue;
          }
        }
        if (_intersects(edge, other)) return true;
      }
      active.add(edge);
    }
    return false;
  }

  bool _intersects(_Edge a, _Edge b) {
    double side(SvgPoint p, SvgPoint q, SvgPoint r) =>
        (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
    final ab1 = side(a.a, a.b, b.a);
    final ab2 = side(a.a, a.b, b.b);
    final ba1 = side(b.a, b.b, a.a);
    final ba2 = side(b.a, b.b, a.b);
    return ab1 * ab2 <= 1e-18 && ba1 * ba2 <= 1e-18;
  }

  bool _contains(List<SvgPoint> loop, SvgPoint p) {
    var inside = false;
    for (var i = 0; i < loop.length; i++) {
      final a = loop[i];
      final b = loop[(i + 1) % loop.length];
      if ((a.y > p.y) != (b.y > p.y) &&
          p.x < a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y)) {
        inside = !inside;
      }
    }
    return inside;
  }

  double _area(List<SvgPoint> loop) {
    var twiceArea = 0.0;
    for (var i = 0; i < loop.length; i++) {
      final a = loop[i];
      final b = loop[(i + 1) % loop.length];
      twiceArea += a.x * b.y - b.x * a.y;
    }
    return twiceArea / 2;
  }
}

class _Edge {
  _Edge(this.a, this.b, this.contour, this.index)
    : minX = math.min(a.x, b.x),
      maxX = math.max(a.x, b.x),
      minY = math.min(a.y, b.y),
      maxY = math.max(a.y, b.y);

  final SvgPoint a;
  final SvgPoint b;
  final int contour;
  final int index;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
}
