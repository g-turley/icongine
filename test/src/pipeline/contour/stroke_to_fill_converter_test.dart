import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

// stroke_to_fill_converter.dart uncovered lines:
// 130-131: _resolveCurveSubdivisionSteps returns max(baseSubdivisions, 24)
//          for segmentCount in range (4,8] with sharp curve-to-curve join
//          and round closed stroke.

void main() {
  group('StrokeToFillConverter', () {
    const converter = StrokeToFillConverter();

    // Helper to build a closed polygon contour with N cubic segments
    // that form a sharp angle at one junction.
    SvgContour buildSharpCurveContour(int segmentCount) {
      // Build a closed contour with `segmentCount` cubic segments.
      // Each segment is a horizontal run with a sharp downward kink at segment 0→1.
      final step = 100.0 / segmentCount;
      final segments = <SvgContourSegment>[];
      for (var i = 0; i < segmentCount; i += 1) {
        final startX = i * step;
        final endX = (i + 1) * step;
        // First segment goes right; second segment goes sharply downward
        // to create a sharp curve-to-curve join.
        if (i == 0) {
          segments.add(
            SvgContourSegment.cubic(
              start: SvgPoint(startX, 0),
              control1: SvgPoint(startX + step / 3, 0),
              control2: SvgPoint(endX - step / 3, 0),
              end: SvgPoint(endX, 0),
            ),
          );
        } else if (i == 1) {
          // Sharp downward curve (perpendicular to first segment)
          segments.add(
            SvgContourSegment.cubic(
              start: SvgPoint(endX - step, 0),
              control1: SvgPoint(endX - step + step / 3, -50),
              control2: SvgPoint(endX - step / 3, -100),
              end: SvgPoint(endX, -100),
            ),
          );
        } else {
          segments.add(
            SvgContourSegment.cubic(
              start: SvgPoint(startX, -100),
              control1: SvgPoint(startX + step / 3, -100),
              control2: SvgPoint(endX - step / 3, -100),
              end: SvgPoint(endX, -100),
            ),
          );
        }
      }
      return SvgContour(segments: segments, isClosed: true);
    }

    test(
      'converts a 6-segment closed curve with round join (segmentCount in 4..8 branch)',
      () {
        // Lines 130-131: segmentCount <= 8 && > 4 → max(base, 24)
        // Requires: closed, round join, hasCurveSegments, isCoarseClosedCurve,
        //           hasSharpCurveJoin, segmentCount > 4.
        final contour = buildSharpCurveContour(6);

        final result = converter.convert(
          sourcePath: SvgContourPath(contours: [contour]),
          strokeProperties: const SvgStrokeProperties(
            strokeWidthPixels: 4.0,
            lineJoin: SvgStrokeLineJoin.round,
            hasVisibleFill: false,
          ),
        );

        expect(result.contours, isNotEmpty);
      },
    );

    test('converts a 5-segment closed curve contour with round join', () {
      // Another case in the 4..8 range
      final contour = buildSharpCurveContour(5);

      final result = converter.convert(
        sourcePath: SvgContourPath(contours: [contour]),
        strokeProperties: const SvgStrokeProperties(
          strokeWidthPixels: 4.0,
          lineJoin: SvgStrokeLineJoin.round,
          hasVisibleFill: false,
        ),
      );

      expect(result.contours, isNotEmpty);
    });

    test('converts closed contour with arc segments using round join', () {
      // Exercises _hasArcWithRadiusAtMost (tight arc) path
      final contour = SvgContour(
        segments: [
          SvgContourSegment.arc(
            start: const SvgPoint(0, 0),
            end: const SvgPoint(3, 0), // small arc - radius will be small
            rx: 2, // radius <= halfWidth (5/2=2.5) → hasTightArcRadius
            ry: 2,
            xAxisRotation: 0,
            largeArc: false,
            sweep: true,
          ),
          SvgContourSegment.line(
            start: const SvgPoint(3, 0),
            end: const SvgPoint(0, 0),
          ),
        ],
        isClosed: true,
      );

      final result = converter.convert(
        sourcePath: SvgContourPath(contours: [contour]),
        strokeProperties: const SvgStrokeProperties(
          strokeWidthPixels: 5.0,
          lineJoin: SvgStrokeLineJoin.round,
          hasVisibleFill: false,
        ),
      );

      expect(result.contours, isNotEmpty);
    });

    test('converts open contour with arc segments using round join', () {
      // Exercises sourceHasArcSegments path for open contours
      final contour = SvgContour(
        segments: [
          SvgContourSegment.arc(
            start: const SvgPoint(0, 0),
            end: const SvgPoint(100, 0),
            rx: 60,
            ry: 60,
            xAxisRotation: 0,
            largeArc: false,
            sweep: true,
          ),
        ],
        isClosed: false,
      );

      final result = converter.convert(
        sourcePath: SvgContourPath(contours: [contour]),
        strokeProperties: const SvgStrokeProperties(
          strokeWidthPixels: 5.0,
          lineJoin: SvgStrokeLineJoin.round,
          lineCap: SvgStrokeLineCap.round,
          hasVisibleFill: false,
        ),
      );

      expect(result.contours, isNotEmpty);
    });
  });
}
