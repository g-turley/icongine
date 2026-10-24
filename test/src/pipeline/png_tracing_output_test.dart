import 'dart:io';

import 'package:icongine/icongine.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

import '../../support/png_tracing_fixtures.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('png_output_'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('existing custom compilation facades keep their original interface', () {
    final facade = _CustomFacade();
    SvgFontCompiler(glyphCompilationFacade: facade).compile(
      config: GenerationConfig(
        packageName: 'test',
        inputDir: temp.path,
        outClassFile: '${temp.path}/icons.dart',
        outFontFile: '${temp.path}/icons.otf',
      ),
      symbols: const [],
    );
    expect(facade.called, isTrue);
  });

  test(
    'PNG fonts are deterministic across formats and normalization modes',
    () {
      final source = File('${temp.path}/circle.png')
        ..writeAsBytesSync(
          image.encodePng(samplePngFixture(pngTracingFixtures['circle']!)),
        );
      final symbols = [
        IconSymbol(
          file: IconFile(absolutePath: source.path, relativePath: 'circle.png'),
          name: 'circle',
        ),
      ];
      for (final format in FontFormat.values) {
        for (final normalize in [false, true]) {
          final config = GenerationConfig(
            packageName: 'test',
            inputDir: temp.path,
            outClassFile: '${temp.path}/icons.dart',
            outFontFile: '${temp.path}/icons.${format.name}',
            fontFormat: format,
            pngTracing: PngTracingMode.smooth,
            normalize: normalize,
          );
          final first = const SvgFontCompiler().compile(
            config: config,
            symbols: symbols,
          );
          final second = const SvgFontCompiler().compile(
            config: config,
            symbols: symbols,
          );
          expect(first.fontBytes, second.fontBytes);
          expect(
            first.glyphs.single.compiledContourPath!.contours.single.segments,
            isNotEmpty,
          );
        }
      }
    },
  );

  test('PNG tracing options do not change SVG font output', () {
    final source = File('${temp.path}/square.svg')
      ..writeAsStringSync(
        '<svg viewBox="0 0 16 16"><path d="M2 2H14V14H2Z"/></svg>',
      );
    final symbols = [
      IconSymbol(
        file: IconFile(absolutePath: source.path, relativePath: 'square.svg'),
        name: 'square',
      ),
    ];
    final outputs = [
      for (final mode in PngTracingMode.values)
        const SvgFontCompiler()
            .compile(
              config: GenerationConfig(
                packageName: 'test',
                inputDir: temp.path,
                outClassFile: '${temp.path}/icons.dart',
                outFontFile: '${temp.path}/icons.otf',
                pngTracing: mode,
              ),
              symbols: symbols,
            )
            .fontBytes,
    ];
    expect(outputs[0], outputs[1]);
    expect(outputs[0], outputs[2]);
  });
}

class _CustomFacade implements GlyphCompilationFacade {
  bool called = false;

  @override
  List<FontGlyph> compileGlyphs({
    required List<IconSymbol> symbols,
    required int startCodePoint,
    required int targetUnitsPerEm,
    required bool normalize,
  }) {
    called = true;
    return const [];
  }
}
