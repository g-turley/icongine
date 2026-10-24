import 'dart:io';
import 'dart:math' as math;

import 'package:icongine/icongine.dart';
import 'package:icongine/src/pipeline/contour/alpha_contour_tracer.dart';
import 'package:icongine/src/pipeline/contour/contour_flattener.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

import '../../support/png_tracing_fixtures.dart';

void main() {
  test('smooth tracing is the programmatic and direct-facade default', () {
    final temp = Directory.systemTemp.createTempSync('png_default_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final file = File('${temp.path}/circle.png')
      ..writeAsBytesSync(
        image.encodePng(samplePngFixture(pngTracingFixtures['circle']!)),
      );
    final config = GenerationConfig(
      packageName: 'test',
      inputDir: temp.path,
      outClassFile: '${temp.path}/icons.dart',
      outFontFile: '${temp.path}/icons.otf',
    );
    expect(config.pngTracing, PngTracingMode.smooth);
    final glyphs = const SvgGlyphCompilationFacade().compileGlyphs(
      symbols: [
        IconSymbol(
          file: IconFile(absolutePath: file.path, relativePath: 'circle.png'),
          name: 'circle',
        ),
      ],
      startCodePoint: 0xe001,
      targetUnitsPerEm: 512,
      normalize: false,
    );
    expect(
      glyphs.single.sourceContourPath!.contours.single.segments.any(
        (s) => s.type.isCurve,
      ),
      isTrue,
    );
  });

  test(
    'curve fitting stays accurate across small and large source canvases',
    () {
      final counts = <int, int>{};
      for (final size in [16, 32, 64, 128, 512]) {
        final raster = samplePngFixture(
          pngTracingFixtures['circle']!,
          size: size,
        );
        final path = const AlphaContourTracer().trace(raster);
        expect(path.contours, hasLength(1));
        final contour = path.contours.single;
        expect(
          contour.segments.any((s) => s.type.isCurve),
          isTrue,
          reason: '$size px should retain actual curves',
        );
        counts[size] = contour.segments.length;
        final points = flattenContourToPolyline(contour, curveSteps: 16);
        final error =
            points
                .map((p) {
                  final x = p.x / size - 0.5;
                  final y = p.y / size - 0.5;
                  return (math.sqrt(x * x + y * y) - 5.5 / 16).abs();
                })
                .reduce((a, b) => a + b) /
            points.length;
        expect(
          error,
          lessThan(0.025),
          reason: '$size px should retain normalized shape',
        );
      }
      expect(
        counts[512]!,
        lessThanOrEqualTo(counts[64]! * 4),
        reason:
            '8x more source pixels should not cause 8x as many curve segments',
      );
    },
  );

  test('diagonal stroke continuity does not join two thick nearby regions', () {
    final raster = image.Image(width: 4, height: 4, numChannels: 4);
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 4; x++) {
        raster.setPixelRgba(
          x,
          y,
          0,
          0,
          0,
          (x < 2 && y < 2) || (x >= 2 && y >= 2) ? 255 : 0,
        );
      }
    }
    final path = const AlphaContourTracer().trace(raster);
    expect(path.contours, hasLength(2));
  });
}
