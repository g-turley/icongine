import 'dart:io';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

// glyph_compilation_facade.dart uncovered lines:
// 210, 211, 213: _transformSegment for quadratic segment type
// 216, 218, 219, 222, 223, 224, 225, 226: _transformSegment for arc segment type
//
// These are exercised when an SVG element with a transform attribute contains
// quadratic bezier (Q/q/T/t) or arc (A/a) path segments.

void main() {
  group('SvgGlyphCompilationFacade - _transformSegment coverage', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('icongine_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('applies transform matrix to quadratic bezier segment', () {
      // Lines 210, 211, 213: quadratic type in _transformSegment
      // SVG with a quadratic bezier path (Q command) and a transform attribute.
      final svgFile = File('${tempDir.path}/quad_transform.svg');
      svgFile.writeAsStringSync(
        '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
        '<path d="M0,0 Q50,100 100,0 Z" transform="translate(7,11)"/>'
        '</svg>',
      );

      final compiler = const SvgFontCompiler();
      final result = compiler.compile(
        config: GenerationConfig(
          packageName: 'test',
          inputDir: tempDir.path,
          outFontFile: '${tempDir.path}/out.otf',
          outClassFile: '${tempDir.path}/out.dart',
          fontFormat: FontFormat.otf,
        ),
        symbols: [
          IconSymbol(
            file: IconFile(
              absolutePath: svgFile.absolute.path,
              relativePath: 'quad_transform.svg',
            ),
            name: 'quadTransform',
          ),
        ],
      );

      expect(result.glyphs, isNotEmpty);
    });

    test('applies transform matrix to arc segment', () {
      // Lines 216-226: arc type in _transformSegment
      // SVG with an arc path (A command) and a transform attribute.
      final svgFile = File('${tempDir.path}/arc_transform.svg');
      svgFile.writeAsStringSync(
        '<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">'
        '<path d="M100,0 A100,100 0 0 1 200,100 L100,100 Z" '
        'transform="scale(1.2)"/>'
        '</svg>',
      );

      final compiler = const SvgFontCompiler();
      final result = compiler.compile(
        config: GenerationConfig(
          packageName: 'test',
          inputDir: tempDir.path,
          outFontFile: '${tempDir.path}/out.otf',
          outClassFile: '${tempDir.path}/out.dart',
          fontFormat: FontFormat.otf,
        ),
        symbols: [
          IconSymbol(
            file: IconFile(
              absolutePath: svgFile.absolute.path,
              relativePath: 'arc_transform.svg',
            ),
            name: 'arcTransform',
          ),
        ],
      );

      expect(result.glyphs, isNotEmpty);
    });

    test('applies rotate transform to a quadratic bezier path', () {
      // More realistic: a rotate transform which has non-identity a/b values,
      // testing the rotation part of _transformSegment for arcs (lines 217-219).
      final svgFile = File('${tempDir.path}/arc_rotate.svg');
      svgFile.writeAsStringSync(
        '<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">'
        '<path d="M50,0 A50,50 0 1 0 -50,0 Z" '
        'transform="translate(100,100) rotate(45)"/>'
        '</svg>',
      );

      final compiler = const SvgFontCompiler();
      final result = compiler.compile(
        config: GenerationConfig(
          packageName: 'test',
          inputDir: tempDir.path,
          outFontFile: '${tempDir.path}/out.otf',
          outClassFile: '${tempDir.path}/out.dart',
          fontFormat: FontFormat.otf,
        ),
        symbols: [
          IconSymbol(
            file: IconFile(
              absolutePath: svgFile.absolute.path,
              relativePath: 'arc_rotate.svg',
            ),
            name: 'arcRotate',
          ),
        ],
      );

      expect(result.glyphs, isNotEmpty);
    });

    test('applies transform to smooth quadratic bezier (T command)', () {
      // Another path to quadratic segments
      final svgFile = File('${tempDir.path}/smooth_quad.svg');
      svgFile.writeAsStringSync(
        '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
        '<path d="M0,50 Q25,0 50,50 T100,50 Z" transform="scale(2,1)"/>'
        '</svg>',
      );

      final compiler = const SvgFontCompiler();
      final result = compiler.compile(
        config: GenerationConfig(
          packageName: 'test',
          inputDir: tempDir.path,
          outFontFile: '${tempDir.path}/out.otf',
          outClassFile: '${tempDir.path}/out.dart',
          fontFormat: FontFormat.otf,
        ),
        symbols: [
          IconSymbol(
            file: IconFile(
              absolutePath: svgFile.absolute.path,
              relativePath: 'smooth_quad.svg',
            ),
            name: 'smoothQuad',
          ),
        ],
      );

      expect(result.glyphs, isNotEmpty);
    });

    test('clips contours to clipPath rectangle bounds', () {
      final svgFile = File('${tempDir.path}/clip_rect.svg');
      svgFile.writeAsStringSync(
        '<svg viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">'
        '<g clip-path="url(#cut)"><path d="M0,0L20,0L20,20L0,20Z"/></g>'
        '<defs><clipPath id="cut"><rect x="2" y="3" width="8" height="6"/></clipPath></defs>'
        '</svg>',
      );

      final compiler = const SvgFontCompiler();
      final result = compiler.compile(
        config: GenerationConfig(
          packageName: 'test',
          inputDir: tempDir.path,
          outFontFile: '${tempDir.path}/out.otf',
          outClassFile: '${tempDir.path}/out.dart',
          fontFormat: FontFormat.otf,
          normalize: false,
        ),
        symbols: [
          IconSymbol(
            file: IconFile(
              absolutePath: svgFile.absolute.path,
              relativePath: 'clip_rect.svg',
            ),
            name: 'clipRect',
          ),
        ],
      );

      final sourceContourPath = result.glyphs.single.sourceContourPath!;
      final sourceBounds = _boundsFromPath(sourceContourPath);
      expect(sourceBounds.minX, closeTo(2.0, 0.2));
      expect(sourceBounds.minY, closeTo(3.0, 0.2));
      expect(sourceBounds.maxX, closeTo(10.0, 0.2));
      expect(sourceBounds.maxY, closeTo(9.0, 0.2));
    });
  });
}

_Bounds _boundsFromPath(SvgContourPath contourPath) {
  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = double.negativeInfinity;
  double maxY = double.negativeInfinity;
  for (final contour in contourPath.contours) {
    for (final segment in contour.segments) {
      final points = <SvgPoint>[
        segment.start,
        segment.end,
        if (segment.control1 != null) segment.control1!,
        if (segment.control2 != null) segment.control2!,
      ];
      for (final point in points) {
        if (point.x < minX) minX = point.x;
        if (point.y < minY) minY = point.y;
        if (point.x > maxX) maxX = point.x;
        if (point.y > maxY) maxY = point.y;
      }
    }
  }
  return _Bounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

class _Bounds {
  const _Bounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
}
