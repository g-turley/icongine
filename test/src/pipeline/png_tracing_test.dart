import 'dart:io';
import 'dart:math' as math;

import 'package:icongine/icongine.dart';
import 'package:icongine/src/pipeline/contour/alpha_contour_tracer.dart';
import 'package:icongine/src/pipeline/contour/contour_flattener.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

import '../../support/png_tracing_fixtures.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('png_tracing_'));
  tearDown(() => temp.deleteSync(recursive: true));

  SvgContourPath compile(
    image.Image raster,
    PngTracingMode mode, {
    FontFormat format = FontFormat.otf,
  }) {
    final source = File('${temp.path}/input.png')
      ..writeAsBytesSync(image.encodePng(raster));
    final result = const SvgFontCompiler().compile(
      config: GenerationConfig(
        packageName: 'tracing',
        inputDir: temp.path,
        outClassFile: '${temp.path}/icons.dart',
        outFontFile: '${temp.path}/icons.${format.name}',
        fontFormat: format,
        pngTracing: mode,
      ),
      symbols: [
        IconSymbol(
          file: IconFile(absolutePath: source.path, relativePath: 'input.png'),
          name: 'icon',
        ),
      ],
    );
    expect(result.fontBytes, isNotEmpty);
    return result.glyphs.single.sourceContourPath!;
  }

  test('uses partial alpha that the legacy threshold discards', () {
    image.Image raster(int edgeAlpha) {
      final result = image.Image(width: 3, height: 3, numChannels: 4);
      result.setPixelRgba(1, 1, 0, 0, 0, 255);
      result.setPixelRgba(0, 1, 0, 0, 0, edgeAlpha);
      return result;
    }

    double left(SvgContourPath path) =>
        _points(path).map((p) => p.x).reduce(math.min);
    expect(
      left(compile(raster(64), PngTracingMode.legacy)),
      left(compile(raster(100), PngTracingMode.legacy)),
    );
    expect(
      left(compile(raster(100), PngTracingMode.smooth)),
      lessThan(left(compile(raster(64), PngTracingMode.smooth)) - 0.1),
    );
  });

  test(
    '16x16 circle has curves and lower radial error than legacy tracing',
    () {
      final raster = samplePngFixture(pngTracingFixtures['circle']!);
      final legacy = compile(raster, PngTracingMode.legacy);
      final smooth = compile(raster, PngTracingMode.smooth);
      expect(
        smooth.contours.single.segments.any((s) => s.type.isCurve),
        isTrue,
      );
      double radialError(SvgContourPath path) {
        final points = _points(path);
        return points
                .map((p) {
                  final radius = math.sqrt(
                    (p.x - 8) * (p.x - 8) + (p.y - 8) * (p.y - 8),
                  );
                  return (radius - 5.5) * (radius - 5.5);
                })
                .reduce((a, b) => a + b) /
            points.length;
      }

      expect(radialError(smooth), lessThan(radialError(legacy) * 0.6));
    },
  );

  test('binary 16x16 circles also produce curved outlines', () {
    final path = compile(
      samplePngFixture(pngTracingFixtures['circle']!, antialias: false),
      PngTracingMode.smooth,
    );
    expect(path.contours.single.segments.any((s) => s.type.isCurve), isTrue);
  });

  test(
    'many disconnected pixels retain every island without expensive fitting',
    () {
      final raster = image.Image(width: 32, height: 32, numChannels: 4);
      for (var y = 0; y < 32; y += 2) {
        for (var x = 0; x < 32; x += 2) {
          raster.setPixelRgba(x, y, 0, 0, 0, 255);
        }
      }
      final path = const AlphaContourTracer().trace(raster);
      expect(path.contours, hasLength(256));
      expect(
        path.contours.every((c) => c.segments.every((s) => !s.type.isCurve)),
        isTrue,
      );
      _expectCoverage(raster, path);
    },
  );

  test('ring keeps its hole with opposite winding in both font formats', () {
    for (final format in FontFormat.values) {
      final path = compile(
        samplePngFixture(pngTracingFixtures['ring']!),
        PngTracingMode.smooth,
        format: format,
      );
      expect(path.contours, hasLength(2));
      final areas = path.contours.map(_area).toList();
      expect(areas[0] * areas[1], lessThan(0));
      expect(_filledAt(path, const SvgPoint(8, 8)), isFalse);
    }
  });

  test('binary square retains four exact sharp corners', () {
    final path = compile(
      samplePngFixture(pngTracingFixtures['square']!, antialias: false),
      PngTracingMode.smooth,
    );
    expect(path.contours.single.segments, hasLength(4));
    expect(path.contours.single.segments.every((s) => !s.type.isCurve), isTrue);
    expect(_points(path).map((p) => p.x).toSet(), {3.0, 13.0});
    expect(_points(path).map((p) => p.y).toSet(), {3.0, 13.0});
  });

  test('pixel mode preserves exact pixels and separates diagonal islands', () {
    final raster = image.Image(width: 2, height: 2, numChannels: 4);
    raster.setPixelRgba(0, 0, 0, 0, 0, 255);
    raster.setPixelRgba(1, 1, 0, 0, 0, 255);
    final path = compile(raster, PngTracingMode.pixel);
    expect(path.contours, hasLength(2));
    expect(path.contours.map(_area).reduce((a, b) => a + b), closeTo(2, 1e-8));
    for (final p in _points(path)) {
      expect(p.x, p.x.roundToDouble());
      expect(p.y, p.y.roundToDouble());
    }
  });

  test(
    'smooth mode joins diagonal strokes and retains one-pixel holes and gaps',
    () {
      final raster = image.Image(width: 8, height: 6, numChannels: 4);
      for (var y = 0; y < 5; y++) {
        for (var x = 0; x < 5; x++) {
          if (!(x == 2 && y == 2)) raster.setPixelRgba(x, y, 0, 0, 0, 255);
        }
      }
      for (var y = 0; y < 5; y++) {
        raster.setPixelRgba(6, y, 0, 0, 0, 255);
      }
      final path = compile(raster, PngTracingMode.smooth);
      expect(path.contours, hasLength(3));
      _expectCoverage(raster, path);
      final diagonal = image.Image(width: 2, height: 2, numChannels: 4);
      diagonal.setPixelRgba(0, 0, 0, 0, 0, 255);
      diagonal.setPixelRgba(1, 1, 0, 0, 0, 255);
      expect(compile(diagonal, PngTracingMode.smooth).contours, hasLength(1));
      final thinStroke = samplePngFixture(pngTracingFixtures['diagonal']!);
      final strokePath = compile(thinStroke, PngTracingMode.smooth);
      expect(strokePath.contours, hasLength(1));
      _expectCoverage(thinStroke, strokePath, confidentOnly: true);
    },
  );

  test('empty, fully filled and 1x1 PNGs produce closed, finite outlines', () {
    for (final size in [1, 3, 16]) {
      final empty = image.Image(width: size, height: size, numChannels: 4);
      expect(compile(empty, PngTracingMode.smooth).contours, isEmpty);
      final filled = samplePngFixture((x, y) => true, size: size);
      final path = compile(filled, PngTracingMode.smooth);
      expect(path.contours, hasLength(1));
      _expectCoverage(filled, path);
      for (final contour in path.contours) {
        expect(contour.isClosed, isTrue);
        expect(contour.segments.last.end.x, contour.segments.first.start.x);
        expect(contour.segments.last.end.y, contour.segments.first.start.y);
      }
      for (final p in _points(path)) {
        expect(p.x.isFinite && p.y.isFinite, isTrue);
        expect(p.x, inInclusiveRange(0, size));
        expect(p.y, inInclusiveRange(0, size));
      }
    }
  });

  test('all 2x2 masks keep connectivity and pixel-center coverage', () {
    for (var mask = 0; mask < 16; mask++) {
      final raster = image.Image(width: 2, height: 2, numChannels: 4);
      for (var bit = 0; bit < 4; bit++) {
        raster.setPixelRgba(
          bit % 2,
          bit ~/ 2,
          0,
          0,
          0,
          mask & (1 << bit) == 0 ? 0 : 255,
        );
      }
      final path = const AlphaContourTracer().trace(raster);
      _expectCoverage(raster, path);
      if (mask == 6 || mask == 9) {
        expect(path.contours, hasLength(1));
      }
    }
  });

  test(
    'noisy alpha fixtures retain confident pixel-center classifications',
    () {
      final random = math.Random(42);
      for (var fixture = 0; fixture < 50; fixture++) {
        final raster = image.Image(width: 16, height: 16, numChannels: 4);
        for (var y = 0; y < 16; y++) {
          for (var x = 0; x < 16; x++) {
            raster.setPixelRgba(x, y, 0, 0, 0, random.nextInt(256));
          }
        }
        _expectCoverage(
          raster,
          const AlphaContourTracer().trace(raster),
          confidentOnly: true,
        );
      }
    },
  );
}

List<SvgPoint> _points(SvgContourPath path) => [
  for (final c in path.contours) ...flattenContourToPolyline(c, curveSteps: 32),
];

double _area(SvgContour contour) {
  final points = flattenContourToPolyline(contour, curveSteps: 32);
  var area = 0.0;
  for (var i = 0; i < points.length - 1; i++) {
    area += points[i].x * points[i + 1].y - points[i + 1].x * points[i].y;
  }
  return area / 2;
}

bool _filledAt(SvgContourPath path, SvgPoint p) {
  var winding = 0;
  for (final contour in path.contours) {
    final points = flattenContourToPolyline(contour, curveSteps: 32);
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if ((a.y > p.y) != (b.y > p.y) &&
          p.x < a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y)) {
        winding += b.y > a.y ? 1 : -1;
      }
    }
  }
  return winding != 0;
}

void _expectCoverage(
  image.Image raster,
  SvgContourPath path, {
  bool confidentOnly = false,
}) {
  for (var y = 0; y < raster.height; y++) {
    for (var x = 0; x < raster.width; x++) {
      final alpha = raster.getPixel(x, y).aNormalized;
      if (confidentOnly && alpha > 0.25 && alpha < 0.75) continue;
      expect(
        _filledAt(path, SvgPoint(x + 0.5, y + 0.5)),
        raster.getPixel(x, y).aNormalized >= 0.5,
        reason:
            'Source pixel ($x, $y) must retain its inside/outside classification.',
      );
    }
  }
}
