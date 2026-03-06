import 'package:icongine/icongine.dart';
import 'package:test/test.dart';

void main() {
  group('WindingCorrector', () {
    test('handles single-point degenerate contour in signature key', () {
      // Line 186: _normalizeClosedPolyline with polyline.length <= 1
      // This is triggered when a contour has only one segment (single point polyline).
      const corrector = WindingCorrector();

      // A contour with a single zero-length segment (degenerate)
      final degenerate = SvgContour(
        segments: [
          SvgContourSegment.line(
            start: const SvgPoint(5, 5),
            end: const SvgPoint(5, 5), // zero length
          ),
        ],
        isClosed: true,
      );

      final outer = _rectangleContour(0, 0, 10, 10);

      // Should not throw; the degenerate contour gets its signature computed
      final corrected = corrector.correct(
        SvgContourPath(contours: [outer, degenerate]),
      );

      expect(corrected.contours, hasLength(2));
    });

    test(
      'correct handles contours of different sizes for _comparePointLists',
      () {
        // Lines 246-247: _comparePointLists when lengths differ
        // This path is hit when the forward and reversed polylines of a contour
        // have different lengths after removing duplicate endpoints (edge case).
        // We trigger it by having two similar-but-different sized contours.
        const corrector = WindingCorrector();

        // Two nested rectangles of different complexity
        final outer = _rectangleContour(0, 0, 100, 100);
        final inner = _triangleContour(25, 25, 75, 75);

        final corrected = corrector.correct(
          SvgContourPath(contours: [outer, inner]),
        );

        expect(corrected.contours, hasLength(2));
      },
    );

    test('treats duplicate parent contours as one nesting level', () {
      const corrector = WindingCorrector();

      final outer = _rectangleContour(0, 0, 10, 10);
      final inner = _rectangleContour(2, 2, 8, 8);
      final duplicateOuter = _rectangleContour(0, 0, 10, 10);

      final corrected = corrector.correct(
        SvgContourPath(contours: [outer, inner, duplicateOuter]),
      );

      final areas = corrected.contours.map(_signedArea).toList();
      final positiveCount = areas.where((area) => area > 1e-6).length;
      final negativeCount = areas.where((area) => area < -1e-6).length;

      expect(positiveCount, 2);
      expect(negativeCount, 1);
      expect(
        corrected.contours[1].segments.length,
        inner.segments.length,
        reason: 'The inner contour should be preserved and only reversed.',
      );
      expect(areas[1], lessThan(0));
    });
  });
}

SvgContour _triangleContour(
  double minX,
  double minY,
  double maxX,
  double maxY,
) {
  final topLeft = SvgPoint(minX, minY);
  final topRight = SvgPoint(maxX, minY);
  final bottom = SvgPoint((minX + maxX) / 2, maxY);

  return SvgContour(
    isClosed: true,
    segments: [
      SvgContourSegment.line(start: topLeft, end: topRight),
      SvgContourSegment.line(start: topRight, end: bottom),
      SvgContourSegment.line(start: bottom, end: topLeft),
    ],
  );
}

SvgContour _rectangleContour(
  double minX,
  double minY,
  double maxX,
  double maxY,
) {
  final topLeft = SvgPoint(minX, minY);
  final topRight = SvgPoint(maxX, minY);
  final bottomRight = SvgPoint(maxX, maxY);
  final bottomLeft = SvgPoint(minX, maxY);

  return SvgContour(
    isClosed: true,
    segments: [
      SvgContourSegment.line(start: topLeft, end: topRight),
      SvgContourSegment.line(start: topRight, end: bottomRight),
      SvgContourSegment.line(start: bottomRight, end: bottomLeft),
      SvgContourSegment.line(start: bottomLeft, end: topLeft),
    ],
  );
}

double _signedArea(SvgContour contour) {
  var area = 0.0;
  for (final segment in contour.segments) {
    area += segment.start.x * segment.end.y - segment.end.x * segment.start.y;
  }
  return area / 2;
}
