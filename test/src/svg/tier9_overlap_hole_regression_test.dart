import 'package:icongine/icongine.dart';
import 'package:test/test.dart';

import 'contour_assertions.dart';
import 'test_shape_compiler.dart';

void main() {
  group('Tier 9 - overlap hole regressions', () {
    test(
      'cloudy-night-outline keeps moon stroke contour free of interior self-crossings',
      () {
        final result = compileTestShape('cloudy-night-outline');

        expectContourCount(result.sourceContourPath, 3);
        expectAllContoursClosed(result.sourceContourPath);

        final moonContour = result.sourceContourPath.contours.singleWhere((
          contour,
        ) {
          final bounds = _boundsForContour(contour);
          return bounds.minY < 80 && bounds.maxX > 500;
        });

        expect(_countInteriorSelfIntersections(moonContour), 0);
      },
    );

    test('reload keeps overlapping head/stem contours aligned in winding', () {
      final result = compileTestShape('reload');

      expectContourCount(result.sourceContourPath, 2);
      expectAllContoursClosed(result.sourceContourPath);

      final firstArea = signedArea(result.sourceContourPath.contours[0]);
      final secondArea = signedArea(result.sourceContourPath.contours[1]);
      expect(firstArea.sign, isNonZero);
      expect(secondArea.sign, isNonZero);
      expect(firstArea.sign, equals(secondArea.sign));
    });
  });
}

int _countInteriorSelfIntersections(SvgContour contour) {
  var count = 0;
  final segmentCount = contour.segments.length;
  for (var firstIndex = 0; firstIndex < segmentCount; firstIndex += 1) {
    final first = contour.segments[firstIndex];
    for (
      var secondIndex = firstIndex + 1;
      secondIndex < segmentCount;
      secondIndex += 1
    ) {
      final isAdjacent =
          secondIndex == firstIndex ||
          secondIndex == firstIndex + 1 ||
          (firstIndex == 0 && secondIndex == segmentCount - 1);
      if (isAdjacent) {
        continue;
      }

      final intersection = _segmentInteriorIntersection(
        first.start,
        first.end,
        contour.segments[secondIndex].start,
        contour.segments[secondIndex].end,
      );
      if (intersection != null) {
        count += 1;
      }
    }
  }
  return count;
}

SvgPoint? _segmentInteriorIntersection(
  SvgPoint firstStart,
  SvgPoint firstEnd,
  SvgPoint secondStart,
  SvgPoint secondEnd,
) {
  final firstDx = firstEnd.x - firstStart.x;
  final firstDy = firstEnd.y - firstStart.y;
  final secondDx = secondEnd.x - secondStart.x;
  final secondDy = secondEnd.y - secondStart.y;
  final denominator = firstDx * secondDy - firstDy * secondDx;
  if (denominator.abs() < 1e-10) {
    return null;
  }

  final diffX = secondStart.x - firstStart.x;
  final diffY = secondStart.y - firstStart.y;
  final firstT = (diffX * secondDy - diffY * secondDx) / denominator;
  final secondT = (diffX * firstDy - diffY * firstDx) / denominator;
  if (firstT <= 1e-6 || firstT >= 1 - 1e-6) {
    return null;
  }
  if (secondT <= 1e-6 || secondT >= 1 - 1e-6) {
    return null;
  }

  return SvgPoint(
    firstStart.x + firstT * firstDx,
    firstStart.y + firstT * firstDy,
  );
}

_Bounds _boundsForContour(SvgContour contour) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = -double.infinity;
  var maxY = -double.infinity;

  for (final segment in contour.segments) {
    minX = _min3(minX, segment.start.x, segment.end.x);
    minY = _min3(minY, segment.start.y, segment.end.y);
    maxX = _max3(maxX, segment.start.x, segment.end.x);
    maxY = _max3(maxY, segment.start.y, segment.end.y);
  }

  return _Bounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

double _min3(double first, double second, double third) {
  final a = first < second ? first : second;
  return a < third ? a : third;
}

double _max3(double first, double second, double third) {
  final a = first > second ? first : second;
  return a > third ? a : third;
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
