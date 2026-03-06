import 'package:icongine/icongine.dart';
import 'package:test/test.dart';

import 'contour_assertions.dart';
import 'test_shape_compiler.dart';

void main() {
  group('Tier 7 - new shape regressions', () {
    test('albums-outline keeps expected four contour stroke structure', () {
      final result = compileTestShape('albums-outline');

      expectContourCount(result.sourceContourPath, 4);
      expectAllContoursClosed(result.sourceContourPath);
      final segmentCounts = result.sourceContourPath.contours
          .map((contour) => contour.segments.length)
          .toList();
      expect(segmentCounts..sort(), [22, 22, 68, 132]);
    });

    test(
      'alert-circle-sharp skips non-painted polygon and keeps 3 contours',
      () {
        final result = compileTestShape('alert-circle-sharp');

        expectContourCount(result.sourceContourPath, 3);
        expectAllContoursClosed(result.sourceContourPath);
        final segmentCounts = result.sourceContourPath.contours
            .map((contour) => contour.segments.length)
            .toList();
        expect(segmentCounts, [4, 3, 3]);
      },
    );

    test(
      'american-football-outline keeps transformed ellipse + lace structure',
      () {
        final result = compileTestShape('american-football-outline');

        expectContourCount(result.sourceContourPath, 8);
        expectAllContoursClosed(result.sourceContourPath);
        final segmentCounts = result.sourceContourPath.contours
            .map((contour) => contour.segments.length)
            .toList();
        expect(segmentCounts, [64, 64, 22, 22, 22, 22, 22, 22]);
      },
    );

    test('bandage-outline keeps transformed bandage + dot structure', () {
      final result = compileTestShape('bandage-outline');

      expectContourCount(result.sourceContourPath, 8);
      expectAllContoursClosed(result.sourceContourPath);
      final segmentCounts = result.sourceContourPath.contours
          .map((contour) => contour.segments.length)
          .toList();
      expect(segmentCounts..sort(), [4, 4, 4, 4, 66, 68, 114, 132]);
    });

    test('cloud-offline-sharp keeps rotated slash plus cloud fills', () {
      final result = compileTestShape('cloud-offline-sharp');

      expectContourCount(result.sourceContourPath, 3);
      expectAllContoursClosed(result.sourceContourPath);
      final segmentCounts = result.sourceContourPath.contours
          .map((contour) => contour.segments.length)
          .toList();
      expect(segmentCounts, [3, 6, 7]);
    });

    test(
      'walk-sharp keeps default-filled open body plus stroked outline support contours',
      () {
        final result = compileTestShape('walk-sharp');

        expectContourCount(result.sourceContourPath, 6);
        expectAllContoursClosed(result.sourceContourPath);
        final segmentCounts = result.sourceContourPath.contours
            .map((contour) => contour.segments.length)
            .toList();
        expect(segmentCounts, [8, 4, 4, 4, 62, 18]);

        final bodyStrokeContour = result.sourceContourPath.contours.singleWhere(
          (contour) => contour.segments.length == 62,
        );
        expect(countInteriorSelfIntersections(bodyStrokeContour), 0);
      },
    );
    
    test(
      'shield-checkmark-outline keeps rounded closed ring with no inner self-intersections',
      () {
        final result = compileTestShape('shield-checkmark-outline');

        expectContourCount(result.sourceContourPath, 3);
        expectAllContoursClosed(result.sourceContourPath);

        final segmentCounts = result.sourceContourPath.contours
            .map((contour) => contour.segments.length)
            .toList();
        expect(segmentCounts, [32, 160, 124]);

        final shieldRingContours = result.sourceContourPath.contours
            .where((contour) => contour.segments.length >= 62)
            .toList();
        expect(shieldRingContours, hasLength(2));
        for (final contour in shieldRingContours) {
          expect(countInteriorSelfIntersections(contour), 0);
        }
      },
    );

    test(
      'phone-portrait preserves inner hole contours after winding correction',
      () {
        final result = compileTestShape('phone-portrait');

        expectContourCount(result.sourceContourPath, 5);
        expectAllContoursClosed(result.sourceContourPath);

        final sortedSegmentCounts =
            result.sourceContourPath.contours
                .map((contour) => contour.segments.length)
                .toList()
              ..sort();
        expect(sortedSegmentCounts, [8, 8, 13, 13, 14]);

        final holeContours = result.sourceContourPath.contours
            .where((contour) => signedArea(contour) < 0)
            .toList();
        expect(holeContours, hasLength(2));
        final holeSegmentCounts =
            holeContours.map((contour) => contour.segments.length).toList()
              ..sort();
        expect(holeSegmentCounts, [13, 13]);
      },
    );
  });
}

_Bounds _bounds(SvgContourPath contourPath) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = -double.infinity;
  var maxY = -double.infinity;

  for (final contour in contourPath.contours) {
    for (final segment in contour.segments) {
      minX = _min(minX, segment.start.x, segment.end.x);
      minY = _min(minY, segment.start.y, segment.end.y);
      maxX = _max(maxX, segment.start.x, segment.end.x);
      maxY = _max(maxY, segment.start.y, segment.end.y);
    }
  }

  return _Bounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

double _min(double current, double first, double second) {
  final smaller = first < second ? first : second;
  return current < smaller ? current : smaller;
}

double _max(double current, double first, double second) {
  final larger = first > second ? first : second;
  return current > larger ? current : larger;
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
