import 'dart:math' as math;

import 'package:icongine/icongine.dart';
import 'package:icongine/src/pipeline/contour/raster_loop_smoother.dart';
import 'package:test/test.dart';

void main() {
  group('RasterLoopSmoother', () {
    const exactSmoother = RasterLoopSmoother(douglasPeuckerEpsilon: 0);

    test('preserves square corners as line segments', () {
      final contour = exactSmoother.smooth([
        const SvgPoint(0, 0),
        const SvgPoint(4, 0),
        const SvgPoint(4, 4),
        const SvgPoint(0, 4),
      ]);

      expect(contour.isClosed, isTrue);
      expect(contour.segments, hasLength(4));
      expect(
        contour.segments.every(
          (segment) => segment.type == SvgContourSegmentType.line,
        ),
        isTrue,
      );
    });

    test('fits a closed cubic spline for a smooth 16-gon loop', () {
      final contour = exactSmoother.smooth(_regularPolygon(16, radius: 10));

      expect(contour.isClosed, isTrue);
      expect(contour.segments, hasLength(16));
      expect(
        contour.segments.every(
          (segment) => segment.type == SvgContourSegmentType.cubic,
        ),
        isTrue,
      );
    });

    test('treats sharp star points as corners', () {
      final contour = exactSmoother.smooth(_starPolygon());

      expect(contour.segments, hasLength(10));
      expect(
        contour.segments.every(
          (segment) => segment.type == SvgContourSegmentType.line,
        ),
        isTrue,
      );
    });

    test('fits cubics across a smooth run between corners', () {
      final contour = exactSmoother.smooth([
        const SvgPoint(0, 0),
        const SvgPoint(1, 0.1),
        const SvgPoint(2, 0.4),
        const SvgPoint(3, 0.1),
        const SvgPoint(4, 0),
        const SvgPoint(4, 3),
        const SvgPoint(0, 3),
      ]);

      final cubicSegments = contour.segments
          .where((segment) => segment.type == SvgContourSegmentType.cubic)
          .toList(growable: false);
      final lineSegments = contour.segments
          .where((segment) => segment.type == SvgContourSegmentType.line)
          .toList(growable: false);

      expect(cubicSegments, isNotEmpty);
      expect(lineSegments, isNotEmpty);
      expect(
        cubicSegments.any((segment) {
          return (segment.control1!.y - segment.start.y).abs() > 1e-6 ||
              (segment.control2!.y - segment.end.y).abs() > 1e-6;
        }),
        isTrue,
      );
    });

    test('emits cubic interpolation for a run with a single smooth point', () {
      final contour = exactSmoother.smooth([
        const SvgPoint(0, 0),
        const SvgPoint(1, 0.05),
        const SvgPoint(2, 0),
        const SvgPoint(2, 2),
        const SvgPoint(0, 2),
      ]);

      expect(
        contour.segments.where(
          (segment) => segment.type == SvgContourSegmentType.cubic,
        ),
        hasLength(greaterThanOrEqualTo(2)),
      );
      expect(
        contour.segments.where(
          (segment) => segment.type == SvgContourSegmentType.line,
        ),
        isNotEmpty,
      );
    });

    test('returns an empty contour for degenerate loops', () {
      expect(exactSmoother.smooth(const []).segments, isEmpty);
      expect(
        exactSmoother.smooth(const [SvgPoint(1, 1), SvgPoint(1, 1)]).segments,
        isEmpty,
      );
    });

    test('preserves triangles as line-only contours', () {
      final contour = exactSmoother.smooth([
        const SvgPoint(0, 0),
        const SvgPoint(3, 0),
        const SvgPoint(1.5, 2),
      ]);

      expect(contour.segments, hasLength(3));
      expect(
        contour.segments.every(
          (segment) => segment.type == SvgContourSegmentType.line,
        ),
        isTrue,
      );
    });

    test('handles coincident adjacent points without NaN coordinates', () {
      final contour = exactSmoother.smooth([
        const SvgPoint(0, 0),
        const SvgPoint(1, 0),
        const SvgPoint(1, 0),
        const SvgPoint(2, 0.1),
        const SvgPoint(3, 0),
        const SvgPoint(3, 2),
        const SvgPoint(0, 2),
      ]);

      for (final segment in contour.segments) {
        expect(segment.start.x.isFinite, isTrue);
        expect(segment.start.y.isFinite, isTrue);
        expect(segment.end.x.isFinite, isTrue);
        expect(segment.end.y.isFinite, isTrue);
        if (segment.control1 != null) {
          expect(segment.control1!.x.isFinite, isTrue);
          expect(segment.control1!.y.isFinite, isTrue);
        }
        if (segment.control2 != null) {
          expect(segment.control2!.x.isFinite, isTrue);
          expect(segment.control2!.y.isFinite, isTrue);
        }
      }
    });

    test('keeps every segment endpoint chained to the next segment start', () {
      final contour = exactSmoother.smooth([
        const SvgPoint(0, 0),
        const SvgPoint(1, 0.1),
        const SvgPoint(2, 0.4),
        const SvgPoint(3, 0.1),
        const SvgPoint(4, 0),
        const SvgPoint(4, 3),
        const SvgPoint(0, 3),
      ]);

      for (var index = 0; index < contour.segments.length; index += 1) {
        final current = contour.segments[index];
        final next = contour.segments[(index + 1) % contour.segments.length];
        expect(current.end.x, closeTo(next.start.x, 1e-9));
        expect(current.end.y, closeTo(next.start.y, 1e-9));
      }
    });
  });
}

List<SvgPoint> _regularPolygon(int sideCount, {required double radius}) {
  return List<SvgPoint>.generate(sideCount, (index) {
    final angle = (2 * math.pi * index) / sideCount;
    return SvgPoint(radius * math.cos(angle), radius * math.sin(angle));
  }, growable: false);
}

List<SvgPoint> _starPolygon() {
  const outerRadius = 10.0;
  const innerRadius = 4.0;
  return List<SvgPoint>.generate(10, (index) {
    final radius = index.isEven ? outerRadius : innerRadius;
    final angle = -math.pi / 2 + (math.pi * index) / 5;
    return SvgPoint(radius * math.cos(angle), radius * math.sin(angle));
  }, growable: false);
}
