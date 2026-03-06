import 'dart:math' as math;

import 'package:icongine/icongine.dart';
import 'package:test/test.dart';

import 'contour_assertions.dart';
import 'test_shape_compiler.dart';

void main() {
  group('Tier 10 - added problem shape regressions', () {
    test('card-outline keeps chip fully filled (no collapsed-inner hole)', () {
      final result = compileTestShape('card-outline');

      expectContourCount(result.sourceContourPath, 4);
      expectAllContoursClosed(result.sourceContourPath);

      final segmentCounts = result.sourceContourPath.contours
          .map((contour) => contour.segments.length)
          .toList();
      expect(segmentCounts..sort(), [4, 36, 68, 132]);

      final chipContour = result.sourceContourPath.contours.firstWhere(
        (contour) => contour.segments.length == 36,
      );
      final chipBounds = _boundsForContour(chipContour);
      final nestedOppositeContours = result.sourceContourPath.contours.where((
        contour,
      ) {
        if (identical(contour, chipContour)) {
          return false;
        }
        final contourBounds = _boundsForContour(contour);
        final contained =
            contourBounds.minX >= chipBounds.minX &&
            contourBounds.maxX <= chipBounds.maxX &&
            contourBounds.minY >= chipBounds.minY &&
            contourBounds.maxY <= chipBounds.maxY;
        if (!contained) {
          return false;
        }
        return signedArea(contour).sign != signedArea(chipContour).sign;
      }).toList();
      expect(nestedOppositeContours, isEmpty);
    });

    test('dice-outline keeps edge strokes aligned with shell winding', () {
      final result = compileTestShape('dice-outline');

      expectContourCount(result.sourceContourPath, 11);
      expectAllContoursClosed(result.sourceContourPath);

      final segmentCounts = result.sourceContourPath.contours
          .map((contour) => contour.segments.length)
          .toList();
      expect(segmentCounts, [4, 4, 4, 4, 4, 4, 4, 138, 42, 32, 22]);

      final shellOuter = result.sourceContourPath.contours.firstWhere(
        (contour) => contour.segments.length == 138,
      );
      final shellSign = signedArea(shellOuter).sign;
      expect(shellSign, isNot(0));

      final edgeContours = result.sourceContourPath.contours.where(
        (contour) =>
            contour.segments.length == 32 || contour.segments.length == 22,
      );
      for (final contour in edgeContours) {
        expect(signedArea(contour).sign, shellSign);
      }
    });

    test(
      'earth-outline keeps stable globe ring winding with inner land hole',
      () {
        final result = compileTestShape('earth-outline');

        expectContourCount(result.sourceContourPath, 8);
        expectAllContoursClosed(result.sourceContourPath);

        final segmentCounts = result.sourceContourPath.contours
            .map((contour) => contour.segments.length)
            .toList();
        expect(segmentCounts, [26, 43, 12, 10, 4, 13, 64, 64]);

        final ringContours = result.sourceContourPath.contours
            .where((contour) => contour.segments.length == 64)
            .toList();
        expect(ringContours, hasLength(2));
        final firstArea = signedArea(ringContours[0]);
        final secondArea = signedArea(ringContours[1]);
        expect(firstArea.sign, isNot(secondArea.sign));

        final fillNegativeContours = result.sourceContourPath.contours
            .where((contour) => contour.segments.length != 64)
            .where((contour) => signedArea(contour) < 0)
            .toList();
        expect(fillNegativeContours, hasLength(1));
        expect(fillNegativeContours.single.segments.length, 12);

        final fillPositiveContours = result.sourceContourPath.contours
            .where((contour) => contour.segments.length != 64)
            .where((contour) => signedArea(contour) > 0)
            .toList();
        expect(fillPositiveContours, hasLength(5));
      },
    );

    test(
      'earth-sharp keeps nonzero fill layers aligned to avoid overlap cancellation',
      () {
        final result = compileTestShape('earth-sharp');

        expectContourCount(result.sourceContourPath, 8);
        expectAllContoursClosed(result.sourceContourPath);

        final segmentCounts = result.sourceContourPath.contours
            .map((contour) => contour.segments.length)
            .toList();
        expect(segmentCounts, [2, 25, 62, 8, 8, 17, 2, 4]);

        final nonDegenerateSigns = result.sourceContourPath.contours
            .map(_signedAreaSimple)
            .where((area) => area.abs() > 1e-6)
            .map((area) => area.sign)
            .toSet();
        expect(nonDegenerateSigns, hasLength(1));
      },
    );

    test(
      'newspaper-outline keeps stroke-expanded solids from cancelling each other',
      () {
        final result = compileTestShape('newspaper-outline');

        expectContourCount(result.sourceContourPath, 9);
        expectAllContoursClosed(result.sourceContourPath);

        final segmentCounts = result.sourceContourPath.contours
            .map((contour) => contour.segments.length)
            .toList();
        expect(segmentCounts..sort(), [8, 22, 22, 22, 22, 22, 27, 75, 106]);

        final negativeContours = result.sourceContourPath.contours
            .where((contour) => signedArea(contour) < 0)
            .toList();
        expect(negativeContours, hasLength(1));
        expect(negativeContours.single.segments.length, 27);
      },
    );

    test(
      'telescope-outline keeps overlapping stroke rings from cross-cancelling',
      () {
        final result = compileTestShape('telescope-outline');

        expectContourCount(result.sourceContourPath, 8);
        expectAllContoursClosed(result.sourceContourPath);

        final segmentCounts = result.sourceContourPath.contours
            .map((contour) => contour.segments.length)
            .toList();
        expect(segmentCounts..sort(), [22, 22, 37, 38, 38, 101, 102, 102]);

        final negativeContours = result.sourceContourPath.contours
            .where((contour) => signedArea(contour) < 0)
            .toList();
        expect(negativeContours, hasLength(3));
        expect(
          negativeContours.map((contour) => contour.segments.length).toList()
            ..sort(),
          [37, 38, 38],
        );
      },
    );

    test(
      'fish-outline keeps top fin seam aligned and closed ring non-self-crossing',
      () {
        final result = compileTestShape('fish-outline');

        expectContourCount(result.sourceContourPath, 4);
        expectAllContoursClosed(result.sourceContourPath);

        final segmentCounts = result.sourceContourPath.contours
            .map((contour) => contour.segments.length)
            .toList();
        expect(segmentCounts, [4, 188, 159, 32]);

        final primaryRingContours = result.sourceContourPath.contours.where(
          (contour) => contour.segments.length >= 150,
        );
        for (final contour in primaryRingContours) {
          expect(countInteriorSelfIntersections(contour), 0);
        }
      },
    );

    test(
      'walk-outline preserves open-body slit instead of collapsing torso fill',
      () {
        final result = compileTestShape('walk-outline');

        expectContourCount(result.sourceContourPath, 6);
        expectAllContoursClosed(result.sourceContourPath);

        final segmentCounts = result.sourceContourPath.contours
            .map((contour) => contour.segments.length)
            .toList();
        expect(segmentCounts, [102, 62, 22, 22, 64, 64]);

        final torsoContour = result.sourceContourPath.contours.firstWhere(
          (contour) => contour.segments.length == 102,
        );
        expect(countInteriorSelfIntersections(torsoContour), greaterThan(0));
      },
    );

    test(
      'walk applies default fill on open stroked body path while preserving stroke contours',
      () {
        final result = compileTestShape('walk');

        expectContourCount(result.sourceContourPath, 6);
        expectAllContoursClosed(result.sourceContourPath);

        final segmentCounts = result.sourceContourPath.contours
            .map((contour) => contour.segments.length)
            .toList();
        expect(segmentCounts, [8, 7, 8, 4, 100, 62]);

        final bodyFillContour = result.sourceContourPath.contours.firstWhere(
          (contour) => contour.segments.length == 8,
        );
        expectContourWinding(bodyFillContour, clockwise: true);
      },
    );
  });
}

_Bounds _boundsForContour(SvgContour contour) {
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

  return _Bounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
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

double _signedAreaSimple(SvgContour contour) {
  if (contour.segments.isEmpty) {
    return 0;
  }

  var area = 0.0;
  for (final segment in contour.segments) {
    area += segment.start.x * segment.end.y - segment.end.x * segment.start.y;
  }

  if (contour.isClosed) {
    final firstPoint = contour.segments.first.start;
    final lastPoint = contour.segments.last.end;
    area += lastPoint.x * firstPoint.y - firstPoint.x * lastPoint.y;
  }

  return area / 2;
}
