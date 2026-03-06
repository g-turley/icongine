import 'package:test/test.dart';
import 'package:icongine/icongine.dart';
import 'package:icongine/src/pipeline/svg/contour_flattener.dart';

void main() {
  group('SvgToFontCoordinateTransformer', () {
    const transformer = SvgToFontCoordinateTransformer(edgeInsetUnits: 0);
    const scaledTransformer = SvgToFontCoordinateTransformer(
      edgeInsetUnits: 0,
      contentScale: 0.9,
    );
    const insetTransformer = SvgToFontCoordinateTransformer();

    test('scales coordinates by targetUnitsPerEm / sourceSize', () {
      final input = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.line(
                start: const SvgPoint(0, 0),
                end: const SvgPoint(512, 512),
              ),
            ],
            isClosed: false,
          ),
        ],
      );

      final result = transformer.transform(
        contourPath: input,
        sourceWidth: 512,
        sourceHeight: 512,
        targetUnitsPerEm: 1024,
      );

      final segment = result.contours.first.segments.first;
      // x: 0 * 2 = 0, y: (512 - 0) * 2 = 1024
      expect(segment.start.x, closeTo(0.0, 0.01));
      expect(segment.start.y, closeTo(1024.0, 0.01));
      // x: 512 * 2 = 1024, y: (512 - 512) * 2 = 0
      expect(segment.end.x, closeTo(1024.0, 0.01));
      expect(segment.end.y, closeTo(0.0, 0.01));
    });

    test('flips Y axis from SVG top-down to font bottom-up', () {
      final input = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.line(
                start: const SvgPoint(0, 0),
                end: const SvgPoint(0, 100),
              ),
            ],
            isClosed: false,
          ),
        ],
      );

      final result = transformer.transform(
        contourPath: input,
        sourceWidth: 100,
        sourceHeight: 100,
        targetUnitsPerEm: 100,
      );

      final segment = result.contours.first.segments.first;
      // SVG (0,0) is top-left → font (0, 100) is top in font space.
      expect(segment.start.y, closeTo(100.0, 0.01));
      // SVG (0,100) is bottom-left → font (0, 0) is bottom in font space.
      expect(segment.end.y, closeTo(0.0, 0.01));
    });

    test('transforms cubic bezier control points', () {
      final input = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.cubic(
                start: const SvgPoint(0, 50),
                control1: const SvgPoint(25, 0),
                control2: const SvgPoint(75, 0),
                end: const SvgPoint(100, 50),
              ),
            ],
            isClosed: false,
          ),
        ],
      );

      final result = transformer.transform(
        contourPath: input,
        sourceWidth: 100,
        sourceHeight: 100,
        targetUnitsPerEm: 100,
      );

      final segment = result.contours.first.segments.first;
      expect(segment.type, SvgContourSegmentType.cubic);
      // The transformed controls should remain in the upper half after
      // centering/normalization, without exceeding the em square.
      expect(segment.control1!.x, closeTo(25.0, 0.01));
      expect(segment.control1!.y, inInclusiveRange(70.0, 90.0));
      expect(segment.control2!.x, closeTo(75.0, 0.01));
      expect(segment.control2!.y, inInclusiveRange(70.0, 90.0));
    });

    test('transforms arc segments with flipped sweep and rotation sign', () {
      final input = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.arc(
                start: const SvgPoint(10, 20),
                end: const SvgPoint(30, 40),
                rx: 12,
                ry: 8,
                xAxisRotation: 25,
                largeArc: false,
                sweep: true,
              ),
            ],
            isClosed: false,
          ),
        ],
      );

      final result = transformer.transform(
        contourPath: input,
        sourceWidth: 100,
        sourceHeight: 100,
        targetUnitsPerEm: 200,
      );

      final arc = result.contours.first.segments.first;
      expect(arc.type, SvgContourSegmentType.arc);
      expect(arc.start.x, inInclusiveRange(0.0, 30.0));
      expect(arc.start.y, inInclusiveRange(150.0, 200.0));
      expect(arc.end.x, inInclusiveRange(140.0, 190.0));
      expect(arc.end.y, inInclusiveRange(0.0, 30.0));
      expect(arc.rx, inInclusiveRange(90.0, 130.0));
      expect(arc.ry, inInclusiveRange(60.0, 95.0));
      expect(arc.xAxisRotation, closeTo(-25.0, 0.01));
      expect(arc.largeArc, isFalse);
      expect(arc.sweep, isFalse);
    });

    test('preserves closed contour flag', () {
      final input = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.line(
                start: const SvgPoint(0, 0),
                end: const SvgPoint(10, 10),
              ),
            ],
            isClosed: true,
          ),
        ],
      );

      final result = transformer.transform(
        contourPath: input,
        sourceWidth: 100,
        sourceHeight: 100,
        targetUnitsPerEm: 1024,
      );

      expect(result.contours.first.isClosed, isTrue);
    });

    test('returns input unchanged when source dimensions are zero', () {
      final input = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.line(
                start: const SvgPoint(5, 10),
                end: const SvgPoint(15, 20),
              ),
            ],
            isClosed: false,
          ),
        ],
      );

      final result = transformer.transform(
        contourPath: input,
        sourceWidth: 0,
        sourceHeight: 0,
        targetUnitsPerEm: 1024,
        normalize: false,
      );

      expect(result.contours.first.segments.first.start.x, 5.0);
    });

    test('transforms circle path from 512x512 to 1024 unitsPerEm', () {
      // Parse the circle-filled test shape path data.
      const parser = SvgPathDataParser();
      const circlePathData =
          'M47,256'
          'c0,-115.35 93.65,-209 209,-209'
          'c115.35,0 209,93.65 209,209'
          'c0,115.35 -93.65,209 -209,209'
          'c-115.35,0 -209,-93.65 -209,-209Z';
      final parsed = parser.parse(circlePathData);

      final result = transformer.transform(
        contourPath: parsed,
        sourceWidth: 512,
        sourceHeight: 512,
        targetUnitsPerEm: 1024,
      );

      expect(result.contours, hasLength(1));
      expect(result.contours.first.isClosed, isTrue);
      expect(result.contours.first.segments, hasLength(4));

      // Normalized bounds are 47..465 on both axes (418 side length).
      // Scale factor = 1024 / 418.
      // Start point (47, 256) → (0, (465-256)*scale) = (0, 512)
      final firstSegment = result.contours.first.segments.first;
      expect(firstSegment.start.x, closeTo(0.0, 0.01));
      expect(firstSegment.start.y, closeTo(512.0, 0.01));

      // Top of circle (256, 47) → (512, (465-47)*scale) = (512, 1024)
      expect(firstSegment.end.x, closeTo(512.0, 0.01));
      expect(firstSegment.end.y, closeTo(1024.0, 0.01));
    });

    test('supports opting out of normalization', () {
      final input = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.line(
                start: const SvgPoint(47, 256),
                end: const SvgPoint(465, 256),
              ),
            ],
            isClosed: false,
          ),
        ],
      );

      final result = transformer.transform(
        contourPath: input,
        sourceWidth: 512,
        sourceHeight: 512,
        targetUnitsPerEm: 1024,
        normalize: false,
      );

      final segment = result.contours.first.segments.first;
      expect(segment.start.x, closeTo(94.0, 0.01));
      expect(segment.end.x, closeTo(930.0, 0.01));
    });

    test('applies contentScale while keeping glyph centered', () {
      final input = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.line(
                start: const SvgPoint(0, 0),
                end: const SvgPoint(100, 100),
              ),
            ],
            isClosed: false,
          ),
        ],
      );

      final result = scaledTransformer.transform(
        contourPath: input,
        sourceWidth: 100,
        sourceHeight: 100,
        targetUnitsPerEm: 100,
        normalize: false,
      );

      final segment = result.contours.first.segments.first;
      expect(segment.start.x, closeTo(5.0, 0.01));
      expect(segment.start.y, closeTo(95.0, 0.01));
      expect(segment.end.x, closeTo(95.0, 0.01));
      expect(segment.end.y, closeTo(5.0, 0.01));
    });

    test('normalization centers short axis in em square', () {
      final input = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.line(
                start: const SvgPoint(100, 50),
                end: const SvgPoint(300, 50),
              ),
            ],
            isClosed: false,
          ),
        ],
      );

      final result = transformer.transform(
        contourPath: input,
        sourceWidth: 512,
        sourceHeight: 512,
        targetUnitsPerEm: 1024,
      );

      final segment = result.contours.first.segments.first;
      expect(segment.start.x, closeTo(0.0, 0.01));
      expect(segment.start.y, closeTo(512.0, 0.01));
    });

    test('normalization output does not exceed ascender', () {
      final input = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.arc(
                start: const SvgPoint(10, 20),
                end: const SvgPoint(30, 40),
                rx: 12,
                ry: 8,
                xAxisRotation: 25,
                largeArc: false,
                sweep: true,
              ),
            ],
            isClosed: false,
          ),
        ],
      );

      const targetUnitsPerEm = 200;
      final result = insetTransformer.transform(
        contourPath: input,
        sourceWidth: 100,
        sourceHeight: 100,
        targetUnitsPerEm: targetUnitsPerEm,
      );

      var maxY = double.negativeInfinity;
      var minX = double.infinity;
      var minY = double.infinity;
      for (final contour in result.contours) {
        final points = flattenContourToPolyline(contour, curveSteps: 16);
        for (final point in points) {
          if (point.x < minX) {
            minX = point.x;
          }
          if (point.y < minY) {
            minY = point.y;
          }
          if (point.y > maxY) {
            maxY = point.y;
          }
        }
      }
      expect(minX, greaterThanOrEqualTo(0.99));
      expect(minY, greaterThanOrEqualTo(0.99));
      expect(maxY, lessThanOrEqualTo(targetUnitsPerEm + 0.01));
    });
  });
}
