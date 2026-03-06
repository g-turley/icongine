import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  group('SvgPathDataParser', () {
    const parser = SvgPathDataParser();

    group('moveto and lineto', () {
      test('parses absolute moveto and lineto into one open contour', () {
        final result = parser.parse('M10,20 L30,40');

        expect(result.contours, hasLength(1));
        expect(result.contours.first.isClosed, isFalse);
        expect(result.contours.first.segments, hasLength(1));

        final segment = result.contours.first.segments.first;
        expect(segment.type, SvgContourSegmentType.line);
        expect(segment.start.x, 10.0);
        expect(segment.start.y, 20.0);
        expect(segment.end.x, 30.0);
        expect(segment.end.y, 40.0);
      });

      test('parses relative moveto and lineto', () {
        final result = parser.parse('m10,20 l20,20');

        final segment = result.contours.first.segments.first;
        expect(segment.start.x, 10.0);
        expect(segment.start.y, 20.0);
        expect(segment.end.x, 30.0);
        expect(segment.end.y, 40.0);
      });

      test('treats extra coordinate pairs after M as implicit lineto', () {
        final result = parser.parse('M0,0 10,10 20,20');

        expect(result.contours.first.segments, hasLength(2));
        expect(result.contours.first.segments[0].end.x, 10.0);
        expect(result.contours.first.segments[1].end.x, 20.0);
      });
    });

    group('horizontal and vertical lineto', () {
      test('parses absolute horizontal lineto', () {
        final result = parser.parse('M10,20 H50');

        final segment = result.contours.first.segments.first;
        expect(segment.end.x, 50.0);
        expect(segment.end.y, 20.0);
      });

      test('parses relative horizontal lineto', () {
        final result = parser.parse('M10,20 h40');

        final segment = result.contours.first.segments.first;
        expect(segment.end.x, 50.0);
        expect(segment.end.y, 20.0);
      });

      test('parses absolute vertical lineto', () {
        final result = parser.parse('M10,20 V50');

        final segment = result.contours.first.segments.first;
        expect(segment.end.x, 10.0);
        expect(segment.end.y, 50.0);
      });

      test('parses relative vertical lineto', () {
        final result = parser.parse('M10,20 v30');

        final segment = result.contours.first.segments.first;
        expect(segment.end.x, 10.0);
        expect(segment.end.y, 50.0);
      });
    });

    group('closepath', () {
      test('marks contour as closed', () {
        final result = parser.parse('M0,0 L10,10 L20,0 Z');

        expect(result.contours, hasLength(1));
        expect(result.contours.first.isClosed, isTrue);
        expect(result.contours.first.segments, hasLength(2));
      });

      test('resets cursor to contour start after close', () {
        final result = parser.parse('M10,20 L30,40 Z M0,0 L5,5');

        expect(result.contours, hasLength(2));
        expect(result.contours[0].isClosed, isTrue);
        expect(result.contours[1].isClosed, isFalse);
        expect(result.contours[1].segments.first.start.x, 0.0);
      });
    });

    group('cubic bezier', () {
      test('parses absolute cubic bezier', () {
        final result = parser.parse('M0,0 C10,20 30,40 50,60');

        expect(result.contours.first.segments, hasLength(1));
        final segment = result.contours.first.segments.first;
        expect(segment.type, SvgContourSegmentType.cubic);
        expect(segment.start.x, 0.0);
        expect(segment.control1!.x, 10.0);
        expect(segment.control1!.y, 20.0);
        expect(segment.control2!.x, 30.0);
        expect(segment.control2!.y, 40.0);
        expect(segment.end.x, 50.0);
        expect(segment.end.y, 60.0);
      });

      test('parses relative cubic bezier', () {
        final result = parser.parse('M100,200 c10,20 30,40 50,60');

        final segment = result.contours.first.segments.first;
        expect(segment.start.x, 100.0);
        expect(segment.control1!.x, 110.0);
        expect(segment.control1!.y, 220.0);
        expect(segment.control2!.x, 130.0);
        expect(segment.control2!.y, 240.0);
        expect(segment.end.x, 150.0);
        expect(segment.end.y, 260.0);
      });

      test('parses multiple cubic beziers in sequence', () {
        final result = parser.parse(
          'M0,0 c10,0 20,10 20,20 c0,10 -10,20 -20,20',
        );

        expect(result.contours.first.segments, hasLength(2));
        expect(result.contours.first.segments[0].end.x, 20.0);
        expect(result.contours.first.segments[0].end.y, 20.0);
        expect(result.contours.first.segments[1].start.x, 20.0);
        expect(result.contours.first.segments[1].end.x, 0.0);
        expect(result.contours.first.segments[1].end.y, 40.0);
      });
    });

    group('smooth cubic bezier', () {
      test('parses absolute smooth cubic with reflected first control point', () {
        final result = parser.parse('M10,10 C20,10 30,20 40,20 S60,30 70,20');

        expect(result.contours, hasLength(1));
        expect(result.contours.first.segments, hasLength(2));

        final smooth = result.contours.first.segments[1];
        expect(smooth.type, SvgContourSegmentType.cubic);
        expect(smooth.start.x, 40.0);
        expect(smooth.start.y, 20.0);
        // Reflection of previous C control2=(30,20) over current (40,20) => (50,20)
        expect(smooth.control1!.x, 50.0);
        expect(smooth.control1!.y, 20.0);
        expect(smooth.control2!.x, 60.0);
        expect(smooth.control2!.y, 30.0);
        expect(smooth.end.x, 70.0);
        expect(smooth.end.y, 20.0);
      });
    });

    group('quadratic bezier', () {
      test('parses absolute quadratic bezier', () {
        final result = parser.parse('M0,0 Q25,50 50,0');

        final segment = result.contours.first.segments.first;
        expect(segment.type, SvgContourSegmentType.quadratic);
        expect(segment.control1!.x, 25.0);
        expect(segment.control1!.y, 50.0);
        expect(segment.end.x, 50.0);
        expect(segment.end.y, 0.0);
      });
    });

    group('elliptical arc', () {
      test('parses absolute arc command', () {
        final result = parser.parse('M100,100 A40,20 30 1 0 180,140');

        expect(result.contours, hasLength(1));
        expect(result.contours.first.segments, hasLength(1));
        final segment = result.contours.first.segments.first;
        expect(segment.type, SvgContourSegmentType.arc);
        expect(segment.start.x, 100.0);
        expect(segment.start.y, 100.0);
        expect(segment.end.x, 180.0);
        expect(segment.end.y, 140.0);
        expect(segment.rx, 40.0);
        expect(segment.ry, 20.0);
        expect(segment.xAxisRotation, 30.0);
        expect(segment.largeArc, isTrue);
        expect(segment.sweep, isFalse);
      });

      test('parses relative arc command', () {
        final result = parser.parse('M10,10 a5,5 0 0 1 20,15');

        expect(result.contours, hasLength(1));
        expect(result.contours.first.segments, hasLength(1));
        final segment = result.contours.first.segments.first;
        expect(segment.type, SvgContourSegmentType.arc);
        expect(segment.start.x, 10.0);
        expect(segment.start.y, 10.0);
        expect(segment.end.x, 30.0);
        expect(segment.end.y, 25.0);
        expect(segment.largeArc, isFalse);
        expect(segment.sweep, isTrue);
      });
    });

    group('circle test shape', () {
      test('parses circle-filled path data into 4 closed cubic segments', () {
        const circlePathData =
            'M47,256'
            'c0,-115.35 93.65,-209 209,-209'
            'c115.35,0 209,93.65 209,209'
            'c0,115.35 -93.65,209 -209,209'
            'c-115.35,0 -209,-93.65 -209,-209Z';

        final result = parser.parse(circlePathData);

        expect(result.contours, hasLength(1));

        final contour = result.contours.first;
        expect(contour.isClosed, isTrue);
        expect(contour.segments, hasLength(4));

        // All segments should be cubic beziers.
        for (final segment in contour.segments) {
          expect(segment.type, SvgContourSegmentType.cubic);
        }

        // Verify start/end points trace the circle quadrants.
        // Start at (47, 256) — leftmost point.
        expect(contour.segments[0].start.x, closeTo(47.0, 0.01));
        expect(contour.segments[0].start.y, closeTo(256.0, 0.01));

        // First cubic ends at (256, 47) — top point.
        expect(contour.segments[0].end.x, closeTo(256.0, 0.01));
        expect(contour.segments[0].end.y, closeTo(47.0, 0.01));

        // Second cubic ends at (465, 256) — rightmost point.
        expect(contour.segments[1].end.x, closeTo(465.0, 0.01));
        expect(contour.segments[1].end.y, closeTo(256.0, 0.01));

        // Third cubic ends at (256, 465) — bottom point.
        expect(contour.segments[2].end.x, closeTo(256.0, 0.01));
        expect(contour.segments[2].end.y, closeTo(465.0, 0.01));

        // Fourth cubic returns to (47, 256) — start.
        expect(contour.segments[3].end.x, closeTo(47.0, 0.01));
        expect(contour.segments[3].end.y, closeTo(256.0, 0.01));
      });
    });

    group('multiple contours', () {
      test('parses two closed sub-paths as separate contours', () {
        final result = parser.parse(
          'M0,0 L10,0 L10,10 Z M20,20 L30,20 L30,30 Z',
        );

        expect(result.contours, hasLength(2));
        expect(result.contours[0].isClosed, isTrue);
        expect(result.contours[0].segments, hasLength(2));
        expect(result.contours[1].isClosed, isTrue);
        expect(result.contours[1].segments, hasLength(2));
      });
    });

    group('smooth quadratic bezier (T/t)', () {
      test('parses absolute smooth quadratic (T) with reflected control', () {
        // Lines 93-94, 280-303: T command and _handleSmoothQuadratic
        // After Q command, T reflects the previous control point.
        final result = parser.parse('M0,0 Q25,50 50,0 T100,0');

        expect(result.contours, hasLength(1));
        expect(result.contours.first.segments, hasLength(2));

        final smooth = result.contours.first.segments[1];
        expect(smooth.type, SvgContourSegmentType.quadratic);
        expect(smooth.start.x, 50.0);
        expect(smooth.start.y, 0.0);
        // Reflection of Q control (25,50) over current (50,0) → (75,-50)
        expect(smooth.control1!.x, closeTo(75.0, 0.01));
        expect(smooth.control1!.y, closeTo(-50.0, 0.01));
        expect(smooth.end.x, 100.0);
        expect(smooth.end.y, 0.0);
      });

      test('parses relative smooth quadratic (t) with reflected control', () {
        // Lines 95-96, 280-303: t command
        final result = parser.parse('M0,0 Q25,50 50,0 t50,0');

        expect(result.contours.first.segments, hasLength(2));
        final smooth = result.contours.first.segments[1];
        expect(smooth.type, SvgContourSegmentType.quadratic);
        expect(smooth.end.x, closeTo(100.0, 0.01));
        expect(smooth.end.y, closeTo(0.0, 0.01));
      });

      test('T without preceding Q uses current point as control', () {
        // Lines 408-409: hasQuadraticPredecessor=false → control = currentPoint
        // _reflectedQuadraticControl returns (cursorX, cursorY) when no Q predecessor
        final result = parser.parse('M10,20 T50,60');

        expect(result.contours.first.segments, hasLength(1));
        final seg = result.contours.first.segments.first;
        expect(seg.type, SvgContourSegmentType.quadratic);
        // Control = current point = (10, 20)
        expect(seg.control1!.x, closeTo(10.0, 0.01));
        expect(seg.control1!.y, closeTo(20.0, 0.01));
      });

      test('chained T commands reflect previous T control', () {
        // Lines 411-413: _reflectedQuadraticControl with smoothQuadratic predecessor
        // T after T should reflect the implicit control
        final result = parser.parse('M0,0 Q25,50 50,0 T100,0 T150,50');

        expect(result.contours.first.segments, hasLength(3));
        final thirdSeg = result.contours.first.segments[2];
        expect(thirdSeg.type, SvgContourSegmentType.quadratic);
        expect(thirdSeg.end.x, closeTo(150.0, 0.01));
        expect(thirdSeg.end.y, closeTo(50.0, 0.01));
      });
    });

    group('error handling', () {
      test('throws FormatException for missing number after command', () {
        expect(() => parser.parse('M10'), throwsFormatException);
      });

      test('throws FormatException when non-number token encountered', () {
        // Lines 380-382: _nextNumber when value == null (non-parseable token)
        // 'M' followed by 'L' instead of a number triggers the error
        expect(() => parser.parse('M L 10 10'), throwsFormatException);
      });

      test('returns empty contours for empty path data', () {
        final result = parser.parse('');

        expect(result.contours, isEmpty);
      });
    });
  });
}
