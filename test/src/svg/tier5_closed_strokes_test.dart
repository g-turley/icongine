import 'package:test/test.dart';

import 'contour_assertions.dart';
import 'test_shape_compiler.dart';

void main() {
  group('Tier 5 - closed stroke-only rings', () {
    test('circle-outline expands to outer CW and inner CCW ring contours', () {
      final result = compileTestShape('circle-outline');

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
    });

    test('half-circle-outline-segment expands to two ring contours', () {
      final result = compileTestShape('half-circle-outline-segment');

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
    });

    test('pie-outline expands to two ring contours', () {
      final result = compileTestShape('pie-outline');

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
    });

    test('donut-outline expands to two rings (four contours)', () {
      final result = compileTestShape('donut-outline');

      expectContourCount(result.sourceContourPath, 4);
      expectAllContoursClosed(result.sourceContourPath);
      expectContourWinding(
        result.sourceContourPath.contours[0],
        clockwise: true,
      );
      expectContourWinding(
        result.sourceContourPath.contours[1],
        clockwise: false,
      );
      expectContourWinding(
        result.sourceContourPath.contours[2],
        clockwise: true,
      );
      expectContourWinding(
        result.sourceContourPath.contours[3],
        clockwise: false,
      );
    });
  });
}
