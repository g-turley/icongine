import 'package:icongine/icongine.dart';
import 'package:test/test.dart';

import 'contour_assertions.dart';
import 'test_shape_compiler.dart';

void main() {
  group('Tier 2 - simple open strokes', () {
    test('butt-cap-line expands to one closed contour', () {
      final result = compileTestShape('butt-cap-line');

      expectContourCount(result.sourceContourPath, 1);
      expectAllContoursClosed(result.sourceContourPath);
    });

    test('square-cap-line expands to one closed contour', () {
      final result = compileTestShape('square-cap-line');

      expectContourCount(result.sourceContourPath, 1);
      expectAllContoursClosed(result.sourceContourPath);
    });

    test('square-cap-line extends farther than butt-cap-line', () {
      final butt = compileTestShape(
        'butt-cap-line',
      ).sourceContourPath.contours.single;
      final square = compileTestShape(
        'square-cap-line',
      ).sourceContourPath.contours.single;

      final buttPrimaryExtent = _primaryExtent(butt);
      final squarePrimaryExtent = _primaryExtent(square);

      expect(
        squarePrimaryExtent,
        greaterThan(buttPrimaryExtent),
        reason: 'Square caps should add half-width extension at both ends.',
      );
    });
  });
}

double _primaryExtent(SvgContour contour) {
  final points = <SvgPoint>[];
  for (final segment in contour.segments) {
    points.add(segment.start);
    points.add(segment.end);
  }

  final xs = points.map((point) => point.x).toList();
  final ys = points.map((point) => point.y).toList();
  xs.sort();
  ys.sort();

  final width = xs.last - xs.first;
  final height = ys.last - ys.first;
  return width > height ? width : height;
}
