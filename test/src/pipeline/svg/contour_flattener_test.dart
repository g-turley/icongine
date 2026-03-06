import 'package:test/test.dart';
import 'package:icongine/icongine.dart';
import 'package:icongine/src/pipeline/svg/contour_flattener.dart';

// contour_flattener.dart has these uncovered lines:
// 55, 56, 57 - computeArcCenterParams: coincident endpoints return null
// 87         - computeArcCenterParams: sweepFlag=false && deltaTheta>0 branch
// 119        - flattenArcToPoints: params==null branch (degenerate arc)

void main() {
  group('computeArcCenterParams', () {
    test('returns null for arc with coincident start and end points', () {
      // Lines 55-57: coincident endpoints guard
      final segment = SvgContourSegment.arc(
        start: const SvgPoint(100, 100),
        end: const SvgPoint(100, 100), // same as start
        rx: 50,
        ry: 50,
        xAxisRotation: 0,
        largeArc: false,
        sweep: true,
      );

      final result = computeArcCenterParams(segment);

      expect(result, isNull);
    });

    test(
      'returns null for arc with nearly coincident start and end points',
      () {
        // Lines 55-57: coincident endpoints guard (within 1e-6)
        final segment = SvgContourSegment.arc(
          start: const SvgPoint(100, 100),
          end: const SvgPoint(100.0000001, 100.0000001),
          rx: 50,
          ry: 50,
          xAxisRotation: 0,
          largeArc: false,
          sweep: true,
        );

        final result = computeArcCenterParams(segment);

        expect(result, isNull);
      },
    );

    test(
      'adjusts deltaTheta negative when sweep is false and deltaTheta > 0',
      () {
        // Line 87: sweepFlag=false && deltaTheta > 0 branch
        // Use a standard arc where the natural atan2 deltaTheta would be positive,
        // but sweep=false forces it negative.
        final segment = SvgContourSegment.arc(
          start: const SvgPoint(0, 0),
          end: const SvgPoint(100, 0),
          rx: 60,
          ry: 60,
          xAxisRotation: 0,
          largeArc: false,
          sweep: false, // sweep=false triggers the branch
        );

        final result = computeArcCenterParams(segment);

        // If the branch fires, deltaTheta should be <= 0
        expect(result, isNotNull);
        expect(result!.deltaTheta, lessThanOrEqualTo(0));
      },
    );

    test('adjusts deltaTheta positive when sweep is true and deltaTheta < 0', () {
      // Line 89: sweepFlag=true && deltaTheta < 0 branch
      final segment = SvgContourSegment.arc(
        start: const SvgPoint(100, 0),
        end: const SvgPoint(0, 0),
        rx: 60,
        ry: 60,
        xAxisRotation: 0,
        largeArc: false,
        sweep:
            true, // sweep=true with reversed geometry triggers negative deltaTheta
      );

      final result = computeArcCenterParams(segment);

      expect(result, isNotNull);
      // When sweep=true and deltaTheta would be negative, it should be adjusted positive
      expect(result!.deltaTheta, greaterThanOrEqualTo(0));
    });
  });

  group('flattenArcToPoints', () {
    test(
      'returns single endpoint for degenerate arc with coincident endpoints',
      () {
        // Line 119: params==null branch when arc is degenerate
        final segment = SvgContourSegment.arc(
          start: const SvgPoint(100, 100),
          end: const SvgPoint(100, 100), // coincident
          rx: 50,
          ry: 50,
          xAxisRotation: 0,
          largeArc: false,
          sweep: true,
        );

        final points = flattenArcToPoints(segment, curveSteps: 32, minSteps: 4);

        expect(points, hasLength(1));
        expect(points.first.x, closeTo(100, 1e-9));
        expect(points.first.y, closeTo(100, 1e-9));
      },
    );

    test('returns single endpoint for arc with zero radius', () {
      // Line 116: zero-radius guard
      final segment = SvgContourSegment.arc(
        start: const SvgPoint(0, 0),
        end: const SvgPoint(100, 0),
        rx: 0,
        ry: 0,
        xAxisRotation: 0,
        largeArc: false,
        sweep: true,
      );

      final points = flattenArcToPoints(segment, curveSteps: 32, minSteps: 4);

      expect(points, hasLength(1));
      expect(points.first.x, closeTo(100, 1e-9));
    });

    test('returns multiple points for a valid arc', () {
      final segment = SvgContourSegment.arc(
        start: const SvgPoint(0, 0),
        end: const SvgPoint(100, 0),
        rx: 60,
        ry: 60,
        xAxisRotation: 0,
        largeArc: false,
        sweep: true,
      );

      final points = flattenArcToPoints(segment, curveSteps: 32, minSteps: 4);

      expect(points.length, greaterThanOrEqualTo(4));
      // Last point should be near the arc endpoint
      expect(points.last.x, closeTo(100, 1.0));
      expect(points.last.y, closeTo(0, 1.0));
    });
  });

  group('flattenContourToPolyline', () {
    test('returns empty for contour with no segments', () {
      const contour = SvgContour(segments: [], isClosed: false);

      final points = flattenContourToPolyline(contour);

      expect(points, isEmpty);
    });

    test('handles quadratic bezier segment', () {
      final contour = SvgContour(
        segments: [
          SvgContourSegment.quadratic(
            start: const SvgPoint(0, 0),
            control1: const SvgPoint(50, 100),
            end: const SvgPoint(100, 0),
          ),
        ],
        isClosed: false,
      );

      final points = flattenContourToPolyline(contour, curveSteps: 4);

      // 1 start + 4 steps = 5 points
      expect(points.length, 5);
      expect(points.first.x, closeTo(0, 1e-9));
      expect(points.last.x, closeTo(100, 1e-9));
    });

    test('handles arc segment in polyline flattening', () {
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

      final points = flattenContourToPolyline(contour);

      expect(points.length, greaterThan(2));
      expect(points.first.x, closeTo(0, 1e-9));
    });
  });
}
