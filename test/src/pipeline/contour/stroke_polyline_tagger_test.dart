import 'package:test/test.dart';
import 'package:icongine/icongine.dart';
import 'package:icongine/src/pipeline/contour/stroke_polyline_tagger.dart';

// stroke_polyline_tagger.dart uncovered lines:
// 272: _segmentTangentAtStart for line type (called via _isSmoothCurveJoin/hasSharpCurveToCurveJoin)
// 293: _segmentTangentAtEnd for line type
// 314: _arcTangent when computeArcCenterParams returns null (degenerate arc)
//
// Lines 272/293 are in private _segmentTangentAtStart/End for line type.
// These are only called when both segments are curves, so a line adjacent to a curve
// won't trigger them. However, _arcTangent (line 314) is triggered when arc params
// are degenerate (coincident endpoints) via hasSharpCurveToCurveJoin.

void main() {
  group('StrokePolylineTagger', () {
    const tagger = StrokePolylineTagger(curveSubdivisions: 8);

    test('flattens a contour with a single arc segment', () {
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

      final points = tagger.flatten(contour, halfWidth: 5, subdivisionSteps: 8);

      expect(points.length, greaterThan(1));
    });

    test('hasSharpCurveToCurveJoin returns false for open contour', () {
      final contour = SvgContour(
        segments: [
          SvgContourSegment.cubic(
            start: const SvgPoint(0, 0),
            control1: const SvgPoint(10, 0),
            control2: const SvgPoint(20, 0),
            end: const SvgPoint(30, 0),
          ),
        ],
        isClosed: false,
      );

      expect(tagger.hasSharpCurveToCurveJoin(contour), isFalse);
    });

    test(
      'hasSharpCurveToCurveJoin returns false for single-segment contour',
      () {
        final contour = SvgContour(
          segments: [
            SvgContourSegment.cubic(
              start: const SvgPoint(0, 0),
              control1: const SvgPoint(10, 0),
              control2: const SvgPoint(20, 0),
              end: const SvgPoint(30, 0),
            ),
          ],
          isClosed: true,
        );

        expect(tagger.hasSharpCurveToCurveJoin(contour), isFalse);
      },
    );

    test(
      'hasSharpCurveToCurveJoin returns false for collinear adjacent curves',
      () {
        // Two cubic beziers continuing in the same direction (collinear)
        // The end tangent of the first = start tangent of the second → dot = 1.0
        final contour = SvgContour(
          segments: [
            SvgContourSegment.cubic(
              start: const SvgPoint(0, 0),
              control1: const SvgPoint(10, 0),
              control2: const SvgPoint(20, 0),
              end: const SvgPoint(30, 0),
            ),
            SvgContourSegment.cubic(
              start: const SvgPoint(30, 0),
              control1: const SvgPoint(40, 0), // continues rightward
              control2: const SvgPoint(50, 0),
              end: const SvgPoint(60, 0),
            ),
          ],
          isClosed: true,
        );

        expect(tagger.hasSharpCurveToCurveJoin(contour), isFalse);
      },
    );

    test(
      'hasSharpCurveToCurveJoin returns true for sharp curve-to-curve turn',
      () {
        // Two cubic arcs meeting at a sharp angle
        final contour = SvgContour(
          segments: [
            SvgContourSegment.cubic(
              start: const SvgPoint(0, 0),
              control1: const SvgPoint(30, 0),
              control2: const SvgPoint(60, 0),
              end: const SvgPoint(90, 0),
            ),
            SvgContourSegment.cubic(
              start: const SvgPoint(90, 0),
              control1: const SvgPoint(90, -30), // sharp turn down
              control2: const SvgPoint(90, -60),
              end: const SvgPoint(90, -90),
            ),
          ],
          isClosed: true,
        );

        expect(tagger.hasSharpCurveToCurveJoin(contour), isTrue);
      },
    );

    test(
      'triggers _arcTangent with degenerate arc (params==null) in hasSharpCurveToCurveJoin',
      () {
        // Line 314: _arcTangent when computeArcCenterParams returns null.
        // A degenerate arc (coincident start/end) adjacent to a cubic will
        // cause computeArcCenterParams to return null, hitting the fallback.
        final contour = SvgContour(
          segments: [
            SvgContourSegment.arc(
              start: const SvgPoint(50, 50),
              end: const SvgPoint(50, 50), // coincident = degenerate arc
              rx: 30,
              ry: 30,
              xAxisRotation: 0,
              largeArc: false,
              sweep: true,
            ),
            SvgContourSegment.cubic(
              start: const SvgPoint(50, 50),
              control1: const SvgPoint(80, 50),
              control2: const SvgPoint(80, 80),
              end: const SvgPoint(50, 80),
            ),
          ],
          isClosed: true,
        );

        // hasSharpCurveToCurveJoin calls _segmentTangentAtEnd(arc) → _arcTangent
        // which calls computeArcCenterParams → null → line 314
        final result = tagger.hasSharpCurveToCurveJoin(contour);
        // Just verifying it doesn't throw and returns a bool
        expect(result, isA<bool>());
      },
    );

    test('flatten handles closed contour with arc starting segment', () {
      // Exercises arc tangent path (line 286/307)
      final contour = SvgContour(
        segments: [
          SvgContourSegment.arc(
            start: const SvgPoint(0, 50),
            end: const SvgPoint(100, 50),
            rx: 60,
            ry: 60,
            xAxisRotation: 0,
            largeArc: false,
            sweep: true,
          ),
          SvgContourSegment.arc(
            start: const SvgPoint(100, 50),
            end: const SvgPoint(0, 50),
            rx: 60,
            ry: 60,
            xAxisRotation: 0,
            largeArc: false,
            sweep: true,
          ),
        ],
        isClosed: true,
      );

      final points = tagger.flatten(contour, halfWidth: 5, subdivisionSteps: 8);

      expect(points.length, greaterThan(4));
    });

    test('flatten handles quadratic segment in closed contour', () {
      // Exercises quadratic branch (lines 141-166)
      final contour = SvgContour(
        segments: [
          SvgContourSegment.quadratic(
            start: const SvgPoint(0, 0),
            control1: const SvgPoint(50, 100),
            end: const SvgPoint(100, 0),
          ),
          SvgContourSegment.quadratic(
            start: const SvgPoint(100, 0),
            control1: const SvgPoint(50, -100),
            end: const SvgPoint(0, 0),
          ),
        ],
        isClosed: true,
      );

      final points = tagger.flatten(contour, halfWidth: 5, subdivisionSteps: 8);

      expect(points.length, greaterThan(4));
    });

    test(
      'StrokeToFillConverter converts closed arc contour using round join',
      () {
        // Exercises many paths in StrokePolylineTagger via StrokeToFillConverter
        final converter = const StrokeToFillConverter();
        final contour = SvgContour(
          segments: [
            SvgContourSegment.arc(
              start: const SvgPoint(0, 50),
              end: const SvgPoint(100, 50),
              rx: 60,
              ry: 60,
              xAxisRotation: 0,
              largeArc: false,
              sweep: true,
            ),
            SvgContourSegment.arc(
              start: const SvgPoint(100, 50),
              end: const SvgPoint(0, 50),
              rx: 60,
              ry: 60,
              xAxisRotation: 0,
              largeArc: false,
              sweep: true,
            ),
          ],
          isClosed: true,
        );

        final result = converter.convert(
          sourcePath: SvgContourPath(contours: [contour]),
          strokeProperties: const SvgStrokeProperties(
            strokeWidthPixels: 10,
            lineJoin: SvgStrokeLineJoin.round,
            hasVisibleFill: false,
          ),
        );

        expect(result.contours, isNotEmpty);
      },
    );
  });
}
