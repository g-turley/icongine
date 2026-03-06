import 'package:test/test.dart';

import 'contour_assertions.dart';
import 'test_shape_compiler.dart';

void main() {
  group('Fill Rule Semantics', () {
    test('nonzero fill keeps overlapping nested paths as additive fills', () {
      final result = compileTestShape('nonzero-overlap');
      final contours = result.sourceContourPath.contours;

      expectContourCount(result.sourceContourPath, 2);
      expectAllContoursClosed(result.sourceContourPath);

      final firstSign = signedArea(contours[0]).sign;
      final secondSign = signedArea(contours[1]).sign;
      expect(firstSign, isNot(0));
      expect(secondSign, isNot(0));
      expect(
        firstSign,
        secondSign,
        reason:
            'Nested nonzero paths from separate elements should keep the same winding direction.',
      );
    });

    test(
      'evenodd fill converts nested subpaths into opposite winding directions',
      () {
        final result = compileTestShape('evenodd-overlap');
        final contours = result.sourceContourPath.contours;

        expectContourCount(result.sourceContourPath, 2);
        expectAllContoursClosed(result.sourceContourPath);

        final firstSign = signedArea(contours[0]).sign;
        final secondSign = signedArea(contours[1]).sign;
        expect(firstSign, isNot(0));
        expect(secondSign, isNot(0));
        expect(
          firstSign,
          isNot(secondSign),
          reason:
              'Evenodd fill should alternate winding between nested subpaths.',
        );
      },
    );
  });
}
