import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  group('ContourCffGlyphProgramStrategy', () {
    test('builds notdef program as single endchar byte', () {
      final strategy = ContourCffGlyphProgramStrategy(contourPaths: const []);

      final program = strategy.buildNotdefProgram();

      expect(program, [Type2CharstringEncoder.operatorEndchar]);
    });

    test('builds glyph program with rmoveto and rrcurveto for circle', () {
      // A simple closed contour with one cubic segment.
      final contourPath = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.cubic(
                start: const SvgPoint(100, 200),
                control1: const SvgPoint(150, 200),
                control2: const SvgPoint(200, 250),
                end: const SvgPoint(200, 300),
              ),
            ],
            isClosed: true,
          ),
        ],
      );

      final strategy = ContourCffGlyphProgramStrategy(
        contourPaths: [contourPath],
        advanceWidth: 1024,
      );

      final program = strategy.buildGlyphProgram(
        glyphIndex: 0,
        glyph: const CffGlyphMetrics(xMax: 200, yMax: 300),
      );

      // Program should not be empty and should end with endchar (14).
      expect(program.isNotEmpty, isTrue);
      expect(program.last, Type2CharstringEncoder.operatorEndchar);

      // Check for the expected operators in the byte stream.
      expect(program.contains(Type2CharstringEncoder.operatorRmoveto), isTrue);
      expect(
        program.contains(Type2CharstringEncoder.operatorRrcurveto),
        isTrue,
      );
    });

    test('builds glyph program with rlineto for line segments', () {
      final contourPath = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.line(
                start: const SvgPoint(0, 0),
                end: const SvgPoint(100, 0),
              ),
              SvgContourSegment.line(
                start: const SvgPoint(100, 0),
                end: const SvgPoint(100, 100),
              ),
            ],
            isClosed: true,
          ),
        ],
      );

      final strategy = ContourCffGlyphProgramStrategy(
        contourPaths: [contourPath],
        advanceWidth: 0,
      );

      final program = strategy.buildGlyphProgram(
        glyphIndex: 0,
        glyph: const CffGlyphMetrics(xMax: 100, yMax: 100),
      );

      expect(program.last, Type2CharstringEncoder.operatorEndchar);
      expect(program.contains(Type2CharstringEncoder.operatorRlineto), isTrue);
    });

    test('handles multiple contours with separate rmoveto', () {
      // Two contours — a donut shape.
      final contourPath = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.line(
                start: const SvgPoint(0, 0),
                end: const SvgPoint(100, 0),
              ),
            ],
            isClosed: true,
          ),
          SvgContour(
            segments: [
              SvgContourSegment.line(
                start: const SvgPoint(25, 25),
                end: const SvgPoint(75, 25),
              ),
            ],
            isClosed: true,
          ),
        ],
      );

      final strategy = ContourCffGlyphProgramStrategy(
        contourPaths: [contourPath],
        advanceWidth: 0,
      );

      final program = strategy.buildGlyphProgram(
        glyphIndex: 0,
        glyph: const CffGlyphMetrics(xMax: 100, yMax: 100),
      );

      // Should contain two rmoveto operators (one per contour).
      final rmovetoCount = program
          .where((byte) => byte == Type2CharstringEncoder.operatorRmoveto)
          .length;
      expect(rmovetoCount, 2);
    });

    test('skips contours with no segments', () {
      final contourPath = SvgContourPath(
        contours: [
          const SvgContour(segments: [], isClosed: false),
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

      final strategy = ContourCffGlyphProgramStrategy(
        contourPaths: [contourPath],
        advanceWidth: 0,
      );

      final program = strategy.buildGlyphProgram(
        glyphIndex: 0,
        glyph: const CffGlyphMetrics(xMax: 10, yMax: 10),
      );

      // Only one rmoveto (the empty contour is skipped).
      final rmovetoCount = program
          .where((byte) => byte == Type2CharstringEncoder.operatorRmoveto)
          .length;
      expect(rmovetoCount, 1);
    });

    test('emits line operators for arc segments instead of dropping them', () {
      final contourPath = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.arc(
                start: const SvgPoint(100, 100),
                end: const SvgPoint(200, 100),
                rx: 50,
                ry: 50,
                xAxisRotation: 0,
                largeArc: false,
                sweep: true,
              ),
            ],
            isClosed: true,
          ),
        ],
      );

      final strategy = ContourCffGlyphProgramStrategy(
        contourPaths: [contourPath],
        advanceWidth: 0,
      );

      final program = strategy.buildGlyphProgram(
        glyphIndex: 0,
        glyph: const CffGlyphMetrics(xMax: 200, yMax: 100),
      );

      expect(program.last, Type2CharstringEncoder.operatorEndchar);
      expect(program.contains(Type2CharstringEncoder.operatorRlineto), isTrue);
    });

    test(
      'handles degenerate arc (coincident endpoints) in _flattenArcSegment',
      () {
        // Line 262: _flattenArcSegment returns [segment.end] when params==null
        // A degenerate arc has coincident start and end → _arcCenterParams returns null
        final contourPath = SvgContourPath(
          contours: [
            SvgContour(
              segments: [
                SvgContourSegment.arc(
                  start: const SvgPoint(100, 100),
                  end: const SvgPoint(100, 100), // coincident = degenerate
                  rx: 50,
                  ry: 50,
                  xAxisRotation: 0,
                  largeArc: false,
                  sweep: true,
                ),
                SvgContourSegment.line(
                  start: const SvgPoint(100, 100),
                  end: const SvgPoint(200, 100),
                ),
              ],
              isClosed: true,
            ),
          ],
        );

        final strategy = ContourCffGlyphProgramStrategy(
          contourPaths: [contourPath],
          advanceWidth: 0,
        );

        // Should not throw; degenerate arc returns single endpoint
        final program = strategy.buildGlyphProgram(
          glyphIndex: 0,
          glyph: const CffGlyphMetrics(xMax: 200, yMax: 100),
        );

        expect(program.last, Type2CharstringEncoder.operatorEndchar);
      },
    );

    test(
      'handles undersized arc radius (lambda > 1) scaling in _arcCenterParams',
      () {
        // Lines 310-312: lambda > 1 → scale rx and ry
        // This happens when the arc radius is too small for the distance between endpoints.
        // For rx=ry=5 and distance=100 between endpoints, lambda >> 1.
        final contourPath = SvgContourPath(
          contours: [
            SvgContour(
              segments: [
                SvgContourSegment.arc(
                  start: const SvgPoint(0, 0),
                  end: const SvgPoint(100, 0), // distance=100
                  rx: 5, // too small for this distance → lambda > 1
                  ry: 5,
                  xAxisRotation: 0,
                  largeArc: false,
                  sweep: true,
                ),
              ],
              isClosed: false,
            ),
          ],
        );

        final strategy = ContourCffGlyphProgramStrategy(
          contourPaths: [contourPath],
          advanceWidth: 0,
        );

        final program = strategy.buildGlyphProgram(
          glyphIndex: 0,
          glyph: const CffGlyphMetrics(xMax: 100, yMax: 100),
        );

        expect(program.last, Type2CharstringEncoder.operatorEndchar);
        // The arc should produce at least one rlineto point
        expect(
          program.contains(Type2CharstringEncoder.operatorRlineto),
          isTrue,
        );
      },
    );

    test('quantizes deltas against emitted pen position to avoid drift', () {
      final contourPath = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.line(
                start: const SvgPoint(0, 0),
                end: const SvgPoint(0.6, 0),
              ),
              SvgContourSegment.line(
                start: const SvgPoint(0.6, 0),
                end: const SvgPoint(1.6, 0),
              ),
              SvgContourSegment.line(
                start: const SvgPoint(1.6, 0),
                end: const SvgPoint(2.2, 0),
              ),
            ],
            isClosed: true,
          ),
        ],
      );

      final recordingEncoder = _RecordingEncoder();
      final strategy = ContourCffGlyphProgramStrategy(
        contourPaths: [contourPath],
        advanceWidth: 0,
        encoder: recordingEncoder,
      );

      strategy.buildGlyphProgram(
        glyphIndex: 0,
        glyph: const CffGlyphMetrics(xMax: 3, yMax: 0),
      );

      // [advanceWidth, rmoveto dx, rmoveto dy, line1 dx/dy, line2 dx/dy, line3 dx/dy]
      expect(recordingEncoder.values, [0, 0, 0, 1, 0, 1, 0, 0, 0]);
    });
  });
}

class _RecordingEncoder extends Type2CharstringEncoder {
  _RecordingEncoder();

  final values = <int>[];

  @override
  void writeNumber(BytesBuilder builder, int value) {
    values.add(value);
    super.writeNumber(builder, value);
  }
}
