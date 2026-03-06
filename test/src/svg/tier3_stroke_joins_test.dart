import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

import 'contour_assertions.dart';
import 'test_shape_compiler.dart';

void main() {
  group('Tier 3 - open strokes with joins', () {
    test('miter-join-L expands to one closed contour', () {
      final result = compileTestShape('miter-join-L');

      expectContourCount(result.sourceContourPath, 1);
      expectAllContoursClosed(result.sourceContourPath);
    });

    test('bevel join emits an extra chamfer vertex versus miter join', () {
      final miterContour = compileTestShape(
        'miter-join-L',
      ).sourceContourPath.contours.single;
      final bevelContour = compileTestShape(
        'bevel-join-L',
      ).sourceContourPath.contours.single;

      expect(bevelContour.isClosed, isTrue);
      expect(
        bevelContour.segments.length,
        equals(miterContour.segments.length + 1),
      );

      final corner = const SvgPoint(73.226, 432.226);
      final miterNearCornerVertices = _vertexCountNear(
        miterContour,
        center: corner,
        radius: 20.5,
      );
      final bevelNearCornerVertices = _vertexCountNear(
        bevelContour,
        center: corner,
        radius: 20.5,
      );
      expect(
        bevelNearCornerVertices,
        greaterThan(miterNearCornerVertices),
        reason: 'Bevel join should add a chamfer edge near the L-corner.',
      );
    });

    test('polyline-problem expands to stable area and bbox extents', () {
      final result = compileTestShape('polyline-problem');

      expectContourCount(result.sourceContourPath, 1);
      expectAllContoursClosed(result.sourceContourPath);

      final contour = result.sourceContourPath.contours.single;
      final bounds = _bounds(contour);

      expect(bounds.minX, closeTo(160.07, 0.05));
      expect(bounds.maxX, closeTo(272.07, 0.05));
      expect(bounds.minY, closeTo(144.0, 0.05));
      expect(bounds.maxY, closeTo(288.0, 0.05));
      expect(_absoluteArea(contour), greaterThan(5000));
    });
  });
}

int _vertexCountNear(
  SvgContour contour, {
  required SvgPoint center,
  required double radius,
}) {
  final radiusSquared = radius * radius;
  var count = 0;
  for (final segment in contour.segments) {
    final dx = segment.start.x - center.x;
    final dy = segment.start.y - center.y;
    final distanceSquared = dx * dx + dy * dy;
    if (distanceSquared <= radiusSquared) {
      count += 1;
    }
  }
  return count;
}

double _absoluteArea(SvgContour contour) => signedArea(contour).abs();

_Bounds _bounds(SvgContour contour) {
  final xs = contour.segments.map((segment) => segment.start.x).toList();
  final ys = contour.segments.map((segment) => segment.start.y).toList();
  xs.sort();
  ys.sort();
  return _Bounds(minX: xs.first, maxX: xs.last, minY: ys.first, maxY: ys.last);
}

class _Bounds {
  const _Bounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
}
