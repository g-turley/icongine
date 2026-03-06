import 'package:test/test.dart';

import 'contour_assertions.dart';
import 'test_shape_compiler.dart';

void main() {
  group('Tier 1 - pure fill shapes', () {
    test('circle-filled has 1 clockwise contour', () {
      final result = compileTestShape('circle-filled');

      expectContourCount(result.sourceContourPath, 1);
      expectAllContoursClosed(result.sourceContourPath);
      expectContourWinding(
        result.sourceContourPath.contours[0],
        clockwise: true,
      );
    });

    test('rect-filled has 1 clockwise contour', () {
      final result = compileTestShape('rect-filled');

      expectContourCount(result.sourceContourPath, 1);
      expectAllContoursClosed(result.sourceContourPath);
      expectContourWinding(
        result.sourceContourPath.contours[0],
        clockwise: true,
      );
    });

    test('pie-filled has 1 clockwise contour', () {
      final result = compileTestShape('pie-filled');

      expectContourCount(result.sourceContourPath, 1);
      expectAllContoursClosed(result.sourceContourPath);
      expectContourWinding(
        result.sourceContourPath.contours[0],
        clockwise: true,
      );
    });

    test(
      'donut-filled has outer clockwise and inner counter-clockwise contours',
      () {
        final result = compileTestShape('donut-filled');

        expectContourCount(result.sourceContourPath, 2);
        expectAllContoursClosed(result.sourceContourPath);
        expectContourWinding(
          result.sourceContourPath.contours[0],
          clockwise: true,
        );
        expectContourWinding(
          result.sourceContourPath.contours[1],
          clockwise: false,
        );
      },
    );

    test('basket-sharp has multiple closed contours', () {
      final result = compileTestShape('basket-sharp');

      expectContourCount(result.sourceContourPath, 3);
      expectAllContoursClosed(result.sourceContourPath);
      expectContourWinding(
        result.sourceContourPath.contours[0],
        clockwise: true,
      );
      expectContourWinding(
        result.sourceContourPath.contours[1],
        clockwise: true,
      );
      expectContourWinding(
        result.sourceContourPath.contours[2],
        clockwise: false,
      );
    });
  });
}
