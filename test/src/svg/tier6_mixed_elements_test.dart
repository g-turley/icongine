import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

import 'contour_assertions.dart';
import 'test_shape_compiler.dart';

void main() {
  group('Tier 6 - mixed fill and stroke elements', () {
    test('alert-sharp compiles to expected contour count', () {
      final result = compileTestShape('alert-sharp');

      expectContourCount(result.sourceContourPath, 2);
      expectAllContoursClosed(result.sourceContourPath);
    });

    test('alert-circle-outline compiles to expected contour count', () {
      final result = compileTestShape('alert-circle-outline');

      expectContourCount(result.sourceContourPath, 4);
      expectAllContoursClosed(result.sourceContourPath);
    });

    test(
      'alert-circle-outline contours stay within source viewport bounds',
      () {
        final result = compileTestShape('alert-circle-outline');

        for (final contour in result.sourceContourPath.contours) {
          final bounds = _bounds(contour);
          expect(bounds.minX, greaterThanOrEqualTo(-0.01));
          expect(bounds.maxX, lessThanOrEqualTo(512.01));
          expect(bounds.minY, greaterThanOrEqualTo(-0.01));
          expect(bounds.maxY, lessThanOrEqualTo(512.01));
        }
      },
    );

    test('arrow-box-L compiles to expected contour count', () {
      final result = compileTestShape('arrow-box-L');

      expectContourCount(result.sourceContourPath, 4);
      expectAllContoursClosed(result.sourceContourPath);

      final strokeContour = result.sourceContourPath.contours.reduce(
        (a, b) => a.segments.length >= b.segments.length ? a : b,
      );
      final maxStartCapSegmentLength = _maxSegmentLengthNear(
        strokeContour,
        center: const SvgPoint(72.236, 140.6),
        radius: 18,
      );
      final maxEndCapSegmentLength = _maxSegmentLengthNear(
        strokeContour,
        center: const SvgPoint(360.52, 432.061),
        radius: 18,
      );

      // A round-cap chord artifact creates a long straight segment that cuts
      // through the semicircle. Keep local cap segments short.
      expect(maxStartCapSegmentLength, lessThan(24));
      expect(maxEndCapSegmentLength, lessThan(24));
    });

    test('accessibility-outline compiles to expected contour count', () {
      final result = compileTestShape('accessibility-outline');

      expectContourCount(result.sourceContourPath, 4);
      expectAllContoursClosed(result.sourceContourPath);
    });

    test('basket-outline compiles to expected contour count', () {
      final result = compileTestShape('basket-outline');

      expectContourCount(result.sourceContourPath, 5);
      expectAllContoursClosed(result.sourceContourPath);
    });
  });
}

double _maxSegmentLengthNear(
  SvgContour contour, {
  required SvgPoint center,
  required double radius,
}) {
  final radiusSquared = radius * radius;
  var maxLength = 0.0;

  for (final segment in contour.segments) {
    final midpoint = SvgPoint(
      (segment.start.x + segment.end.x) / 2,
      (segment.start.y + segment.end.y) / 2,
    );
    final dx = midpoint.x - center.x;
    final dy = midpoint.y - center.y;
    final distanceSquared = dx * dx + dy * dy;
    if (distanceSquared > radiusSquared) {
      continue;
    }

    final segDx = segment.end.x - segment.start.x;
    final segDy = segment.end.y - segment.start.y;
    final length = math.sqrt(segDx * segDx + segDy * segDy);
    if (length > maxLength) {
      maxLength = length;
    }
  }

  return maxLength;
}

_Bounds _bounds(SvgContour contour) {
  final xs = contour.segments.map((segment) => segment.start.x).toList()
    ..sort();
  final ys = contour.segments.map((segment) => segment.start.y).toList()
    ..sort();
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
