import 'package:test/test.dart';

import 'contour_assertions.dart';
import 'test_shape_compiler.dart';

void main() {
  group('Tier 4 - multiple independent stroked elements', () {
    test('add expands into two independent closed contours', () {
      final result = compileTestShape('add');

      expectContourCount(result.sourceContourPath, 2);
      expectAllContoursClosed(result.sourceContourPath);

      final firstArea = signedArea(result.sourceContourPath.contours[0]);
      final secondArea = signedArea(result.sourceContourPath.contours[1]);
      expect(firstArea.abs(), greaterThan(1e-6));
      expect(secondArea.abs(), greaterThan(1e-6));
      expect(firstArea.sign, equals(secondArea.sign));
    });

    test('battery-dead-sharp expands into multiple closed contours', () {
      final result = compileTestShape('battery-dead-sharp');

      expectContourCount(result.sourceContourPath, 3);
      expectAllContoursClosed(result.sourceContourPath);
    });
  });
}
