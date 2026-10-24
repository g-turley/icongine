import 'dart:typed_data';
import 'dart:math' as math;

import 'package:image/image.dart' as image;

import 'contour.dart';
import 'raster_curve_fitter.dart';
import 'raster_topology_guard.dart';

/// Traces the 50% alpha isocontour at subpixel precision, then fits curves.
///
/// Pixel samples lie at their centers. A transparent border closes edge-touching
/// shapes; alpha saddles preserve gaps while isolated diagonal stroke pixels
/// connect. Unsafe or excessively complex fits fall back to interpolated lines.
class AlphaContourTracer {
  const AlphaContourTracer();

  SvgContourPath trace(image.Image raster) {
    final loops = _traceLoops(raster);
    if (loops.isEmpty) return const SvgContourPath(contours: []);
    // Bound the pairwise topology checks for noisy or very large silhouettes.
    // Retain all their features as interpolated lines instead of dropping detail.
    if (loops.length > 128 ||
        loops.fold<int>(0, (count, loop) => count + loop.length) > 16384) {
      return SvgContourPath(
        contours: [for (final loop in loops) rasterLineContour(loop)],
      );
    }
    // A 64px canvas is the measured balance for ordinary detailed icons.
    // Larger inputs get modest simplification, capped at 0.30 source pixels,
    // instead of retaining every extra raster step or discarding small detail.
    final scale = (math.max(raster.width, raster.height) / 64).clamp(1.0, 2.0);
    final fitter = RasterCurveFitter(toleranceScale: scale);
    final fitted = [for (final loop in loops) fitter.fit(loop)];
    final sampledVertices = fitted.fold<int>(
      0,
      (count, contour) =>
          count +
          contour.segments.fold<int>(
            0,
            (n, segment) => n + (segment.type.isCurve ? 16 : 1),
          ),
    );
    final contours =
        sampledVertices <= 8192 &&
            const RasterTopologyGuard().accepts(raster, loops, fitted)
        ? fitted
        : [for (final loop in loops) rasterLineContour(loop)];
    return SvgContourPath(contours: contours);
  }

  List<List<SvgPoint>> _traceLoops(image.Image raster) {
    final columns = raster.width + 2;
    final rows = raster.height + 2;
    final alpha = Float64List(columns * rows);
    for (var y = 0; y < raster.height; y++) {
      for (var x = 0; x < raster.width; x++) {
        final value = raster.getPixel(x, y).aNormalized.toDouble();
        // Avoid zero-length edges when a floating-point PNG sample is exactly
        // on the threshold. This also keeps graph vertices unique.
        alpha[(y + 1) * columns + x + 1] = value == 0.5 ? 0.5000001 : value;
      }
    }

    final horizontalCount = rows * (columns - 1);
    final points = <int, SvgPoint>{};
    final links = <int, int>{};
    for (var y = 0; y < rows - 1; y++) {
      for (var x = 0; x < columns - 1; x++) {
        final index = y * columns + x;
        final tl = alpha[index];
        final tr = alpha[index + 1];
        final br = alpha[index + columns + 1];
        final bl = alpha[index + columns];
        final code =
            (tl >= 0.5 ? 1 : 0) |
            (tr >= 0.5 ? 2 : 0) |
            (br >= 0.5 ? 4 : 0) |
            (bl >= 0.5 ? 8 : 0);
        var pairs = _edgePairs[code];
        if ((code == 5 || code == 10) &&
            !_connectForeground(alpha, index, columns, code)) {
          pairs = code == 5 ? const [0, 3, 2, 1] : const [1, 0, 3, 2];
        }
        if (pairs.isEmpty) continue;

        int vertex(int edge) {
          final horizontal = edge == 0 || edge == 2;
          final ex = x + (edge == 1 ? 1 : 0);
          final ey = y + (edge == 2 ? 1 : 0);
          final id = horizontal
              ? ey * (columns - 1) + ex
              : horizontalCount + ey * columns + ex;
          points.putIfAbsent(id, () {
            final start = alpha[ey * columns + ex];
            final end = alpha[ey * columns + ex + (horizontal ? 1 : columns)];
            final t = (0.5 - start) / (end - start);
            return SvgPoint(
              ex - 0.5 + (horizontal ? t : 0),
              ey - 0.5 + (horizontal ? 0 : t),
            );
          });
          return id;
        }

        for (var p = 0; p < pairs.length; p += 2) {
          final a = vertex(pairs[p]);
          final b = vertex(pairs[p + 1]);
          assert(!links.containsKey(a), 'An alpha boundary has one successor.');
          links[a] = b;
        }
      }
    }

    final visited = <int>{};
    final loops = <List<SvgPoint>>[];
    for (final start in links.keys) {
      if (visited.contains(start)) continue;
      final loop = <SvgPoint>[];
      var current = start;
      do {
        if (!visited.add(current)) break;
        loop.add(points[current]!);
        current = links[current]!;
      } while (current != start);
      if (current == start && loop.length >= 3) loops.add(loop);
    }
    return loops;
  }

  // Edges: top=0, right=1, bottom=2, left=3. Directed edges keep foreground
  // on their right, giving outer loops positive area and holes negative area
  // in Y-down source coordinates without centroid-based nesting guesses.
  // Saddle connectivity is selected from alpha support and stroke continuity.
  static const _edgePairs = <List<int>>[
    [],
    [0, 3],
    [1, 0],
    [1, 3],
    [2, 1],
    [0, 1, 2, 3],
    [2, 0],
    [2, 3],
    [3, 2],
    [0, 2],
    [3, 0, 1, 2],
    [1, 2],
    [3, 1],
    [0, 1],
    [3, 0],
    [],
  ];

  bool _connectForeground(Float64List alpha, int i, int columns, int code) {
    final first = code == 5 ? i : i + 1;
    final second = code == 5 ? i + columns + 1 : i + columns;
    // An isolated diagonal sample is evidence of a one-pixel stroke. Thick
    // regions instead use the bilinear saddle to avoid joining nearby shapes.
    bool isolated(int p) =>
        alpha[p - 1] < 0.5 &&
        alpha[p + 1] < 0.5 &&
        alpha[p - columns] < 0.5 &&
        alpha[p + columns] < 0.5;
    if (isolated(first) || isolated(second)) return true;
    final diagonal = (alpha[i] - 0.5) * (alpha[i + columns + 1] - 0.5);
    final opposite = (alpha[i + 1] - 0.5) * (alpha[i + columns] - 0.5);
    return code == 5 ? diagonal > opposite : opposite > diagonal;
  }
}
