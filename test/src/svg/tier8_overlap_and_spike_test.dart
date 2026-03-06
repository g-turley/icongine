import 'package:icongine/icongine.dart';
import 'package:test/test.dart';

import 'contour_assertions.dart';
import 'test_shape_compiler.dart';

void main() {
  group('Tier 8 - spike regressions', () {
    test('color-fill-outline avoids pathological miter spikes', () {
      final result = compileTestShape('color-fill-outline');

      expectContourCount(result.sourceContourPath, 4);
      expectAllContoursClosed(result.sourceContourPath);
      final segmentCounts = result.sourceContourPath.contours
          .map((contour) => contour.segments.length)
          .toList();
      expect(segmentCounts, [69, 69, 87, 87]);

      final bounds = _boundsForPath(result.sourceContourPath);
      expect(bounds.minX, greaterThan(-1024));
      expect(bounds.maxX, lessThan(1024));
      expect(bounds.minY, greaterThan(-1024));
      expect(bounds.maxY, lessThan(1024));
    });

    test(
      'contrast-outline keeps stroke ring winding stable with half-fill',
      () {
        final result = compileTestShape('contrast-outline');

        expectContourCount(result.sourceContourPath, 3);
        expectAllContoursClosed(result.sourceContourPath);

        final contoursByArea = [...result.sourceContourPath.contours]
          ..sort(
            (first, second) =>
                signedArea(second).abs().compareTo(signedArea(first).abs()),
          );
        expectContourWinding(contoursByArea[0], clockwise: true);
        expectContourWinding(contoursByArea[1], clockwise: false);
      },
    );

    test('desktop-outline keeps base stroke contour winding stable', () {
      final result = compileTestShape('desktop-outline');

      expectContourCount(result.sourceContourPath, 6);
      expectAllContoursClosed(result.sourceContourPath);

      final baseStrokeContour = result.sourceContourPath.contours.singleWhere(
        (contour) => contour.segments.length == 22,
      );
      expectContourWinding(baseStrokeContour, clockwise: true);
    });

    test('navigate-outline keeps outer/inner closed stroke ring winding', () {
      final result = compileTestShape('navigate-outline');

      expectContourCount(result.sourceContourPath, 2);
      expectAllContoursClosed(result.sourceContourPath);

      final contoursByArea = [...result.sourceContourPath.contours]
        ..sort(
          (first, second) =>
              signedArea(second).abs().compareTo(signedArea(first).abs()),
        );
      final outerArea = signedArea(contoursByArea[0]);
      final innerArea = signedArea(contoursByArea[1]);
      expect(outerArea.abs(), greaterThan(innerArea.abs()));
      expect(outerArea.sign, isNot(equals(innerArea.sign)));
      expect(countInteriorSelfIntersections(contoursByArea[0]), 0);
      expect(countInteriorSelfIntersections(contoursByArea[1]), 0);
    });

    test('storefront-outline avoids roof spike burst artifacts', () {
      final result = compileTestShape('storefront-outline');

      expectContourCount(result.sourceContourPath, 8);
      expectAllContoursClosed(result.sourceContourPath);

      final bounds = _boundsForPath(result.sourceContourPath);
      expect(bounds.minY, greaterThanOrEqualTo(0));
      expect(bounds.maxY, lessThanOrEqualTo(512));
    });
  });
}

_Bounds _boundsForPath(SvgContourPath contourPath) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = -double.infinity;
  var maxY = -double.infinity;

  for (final contour in contourPath.contours) {
    for (final segment in contour.segments) {
      minX = _min3(minX, segment.start.x, segment.end.x);
      minY = _min3(minY, segment.start.y, segment.end.y);
      maxX = _max3(maxX, segment.start.x, segment.end.x);
      maxY = _max3(maxY, segment.start.y, segment.end.y);
    }
  }

  return _Bounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

double _min3(double a, double b, double c) {
  final first = a < b ? a : b;
  return first < c ? first : c;
}

double _max3(double a, double b, double c) {
  final first = a > b ? a : b;
  return first > c ? first : c;
}

class _Bounds {
  const _Bounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
}
