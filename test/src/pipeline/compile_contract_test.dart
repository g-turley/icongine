import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  group('DefaultSvgBoundsExtractor', () {
    const extractor = DefaultSvgBoundsExtractor();

    // Lines 118-131: extract() with viewBox attribute
    test('extracts width and height from viewBox attribute', () {
      const svg =
          '<svg viewBox="0 0 48 32" xmlns="http://www.w3.org/2000/svg"></svg>';
      final bounds = extractor.extract(svg);
      expect(bounds.width, 48.0);
      expect(bounds.height, 32.0);
    });

    test(
      'extracts width and height from viewBox with comma-separated values',
      () {
        const svg =
            '<svg viewBox="0,0,64,64" xmlns="http://www.w3.org/2000/svg"></svg>';
        final bounds = extractor.extract(svg);
        expect(bounds.width, 64.0);
        expect(bounds.height, 64.0);
      },
    );

    test('ignores viewBox when parsed dimensions are non-positive', () {
      // viewBox with width=0 should fall through to width/height attributes
      const svg =
          '<svg viewBox="0 0 0 0" width="100" height="80" '
          'xmlns="http://www.w3.org/2000/svg"></svg>';
      final bounds = extractor.extract(svg);
      // Falls through to _extractDimension (lines 136-139)
      expect(bounds.width, 100.0);
      expect(bounds.height, 80.0);
    });

    // Lines 136-139: width/height attribute fallback
    test('extracts width and height from width and height attributes', () {
      // Line 136-139
      const svg =
          '<svg width="200" height="150" xmlns="http://www.w3.org/2000/svg"></svg>';
      final bounds = extractor.extract(svg);
      expect(bounds.width, 200.0);
      expect(bounds.height, 150.0);
    });

    test('extracts dimensions with px suffix via _extractDimension', () {
      // Lines 145-158: _extractDimension with unit suffix
      const svg =
          '<svg width="300px" height="200px" xmlns="http://www.w3.org/2000/svg"></svg>';
      final bounds = extractor.extract(svg);
      expect(bounds.width, 300.0);
      expect(bounds.height, 200.0);
    });

    test('returns default 24x24 bounds when no valid dimensions found', () {
      const svg = '<svg xmlns="http://www.w3.org/2000/svg"></svg>';
      final bounds = extractor.extract(svg);
      expect(bounds.width, 24.0);
      expect(bounds.height, 24.0);
    });

    test('returns default bounds when width/height values are non-numeric', () {
      // Line 155-156: numeric is null
      const svg =
          '<svg width="auto" height="auto" xmlns="http://www.w3.org/2000/svg"></svg>';
      final bounds = extractor.extract(svg);
      expect(bounds.width, 24.0);
      expect(bounds.height, 24.0);
    });

    test('returns default bounds when viewBox has fewer than 4 parts', () {
      // Line 127: parts.length < 4
      const svg =
          '<svg viewBox="0 0 48" xmlns="http://www.w3.org/2000/svg"></svg>';
      final bounds = extractor.extract(svg);
      // Falls through to width/height then default
      expect(bounds.width, 24.0);
      expect(bounds.height, 24.0);
    });
  });

  group('SvgFontCompiler _resolveUnitsPerEm', () {
    test('forwards PNG tracing to glyph compilation', () {
      final facade = _RecordingGlyphCompilationFacade();
      SvgFontCompiler(glyphCompilationFacade: facade).compile(
        config: GenerationConfig(
          packageName: 'sample',
          inputDir: 'icons',
          outClassFile: 'icons.dart',
          outFontFile: 'icons.otf',
          pngTracing: PngTracingMode.smooth,
        ),
        symbols: const [],
      );
      expect(facade.receivedPngTracing, PngTracingMode.smooth);
    });
    test('uses TtfWriter unitsPerEm when format is ttf', () {
      // Line 96: TtfWriter branch in _resolveUnitsPerEm
      final facade = _RecordingGlyphCompilationFacade();
      final compiler = SvgFontCompiler(
        fontWriterFactory: const _TtfResolvingFactory(),
        glyphCompilationFacade: facade,
      );
      compiler.compile(
        config: GenerationConfig(
          packageName: 'sample',
          inputDir: 'assets/icons',
          outFontFile: 'assets/fonts/icons.ttf',
          outClassFile: 'lib/icons.dart',
          fontFormat: FontFormat.ttf,
        ),
        symbols: const [],
      );
      expect(facade.receivedTargetUnitsPerEm, 512);
    });
  });

  test('StubIconCompiler reports package name and symbol count', () {
    final compiler = StubIconCompiler();

    final result = compiler.compile(
      config: GenerationConfig(
        packageName: 'sample',
        inputDir: 'assets/icons',
        outFontFile: 'assets/fonts/icons.otf',
        outClassFile: 'lib/icons.dart',
      ),
      symbols: const [
        IconSymbol(
          file: IconFile(absolutePath: '/tmp/a.svg', relativePath: 'a.svg'),
          name: 'a',
        ),
      ],
    );

    expect(result.fontFamily, 'AppIcons');
    expect(result.compiledSymbolCount, 1);
    expect(result.fontBytes, isEmpty);
    expect(result.glyphs, isEmpty);
  });

  test('SvgFontCompiler delegates glyph compilation to facade', () {
    final facade = _RecordingGlyphCompilationFacade();
    final writer = _RecordingFontWriter();
    final compiler = SvgFontCompiler(
      fontWriterFactory: FontWriterFactory(
        registeredFormatWriters: {
          FontFormat.otf: writer,
          FontFormat.ttf: writer,
        },
      ),
      glyphCompilationFacade: facade,
    );

    final symbols = const [
      IconSymbol(
        file: IconFile(
          absolutePath: '/tmp/does-not-need-to-exist.svg',
          relativePath: 'icon.svg',
        ),
        name: 'icon',
      ),
    ];
    final result = compiler.compile(
      config: GenerationConfig(
        packageName: 'sample',
        inputDir: 'assets/icons',
        outFontFile: 'assets/fonts/icons.otf',
        outClassFile: 'lib/icons.dart',
      ),
      symbols: symbols,
    );

    expect(facade.receivedSymbols, symbols);
    expect(facade.receivedStartCodePoint, 0xe001);
    expect(facade.receivedTargetUnitsPerEm, 512);
    expect(facade.receivedNormalize, isFalse);
    expect(writer.lastFamilyName, 'AppIcons');
    expect(writer.lastGlyphs, facade.returnedGlyphs);
    expect(result.glyphs, facade.returnedGlyphs);
  });

  test('SvgFontCompiler uses class name as font family with spaces', () {
    final facade = _RecordingGlyphCompilationFacade();
    final writer = _RecordingFontWriter();
    final compiler = SvgFontCompiler(
      fontWriterFactory: FontWriterFactory(
        registeredFormatWriters: {
          FontFormat.otf: writer,
          FontFormat.ttf: writer,
        },
      ),
      glyphCompilationFacade: facade,
    );

    final result = compiler.compile(
      config: GenerationConfig(
        packageName: 'sample',
        className: 'Example Icons',
        inputDir: 'assets/icons',
        outFontFile: 'assets/fonts/icons.otf',
        outClassFile: 'lib/icons.dart',
      ),
      symbols: const [],
    );

    expect(writer.lastFamilyName, 'Example Icons');
    expect(result.fontFamily, 'Example Icons');
  });

  test(
    'SvgFontCompiler reports normalization warning for mixed source sizes',
    () {
      final facade = _RecordingGlyphCompilationFacade(
        returnedGlyphs: const [
          FontGlyph(
            name: 'small',
            codePoint: 0xe001,
            glyphId: 1,
            sourceWidth: 24,
            sourceHeight: 24,
          ),
          FontGlyph(
            name: 'large',
            codePoint: 0xe002,
            glyphId: 2,
            sourceWidth: 512,
            sourceHeight: 512,
          ),
        ],
      );
      final writer = _RecordingFontWriter();
      final compiler = SvgFontCompiler(
        fontWriterFactory: FontWriterFactory(
          registeredFormatWriters: {
            FontFormat.otf: writer,
            FontFormat.ttf: writer,
          },
        ),
        glyphCompilationFacade: facade,
      );

      final result = compiler.compile(
        config: GenerationConfig(
          packageName: 'sample',
          inputDir: 'assets/icons',
          outFontFile: 'assets/fonts/icons.otf',
          outClassFile: 'lib/icons.dart',
          normalize: true,
        ),
        symbols: const [
          IconSymbol(
            file: IconFile(absolutePath: '/tmp/a.svg', relativePath: 'a.svg'),
            name: 'a',
          ),
          IconSymbol(
            file: IconFile(absolutePath: '/tmp/b.svg', relativePath: 'b.svg'),
            name: 'b',
          ),
        ],
      );

      expect(result.normalizationWarnings, hasLength(1));
      expect(result.normalizationWarnings.single, contains('24.00x24.00'));
      expect(result.normalizationWarnings.single, contains('512.00x512.00'));
      expect(
        result.normalizationWarnings.single,
        contains('output coordinate system: 512 em units'),
      );
    },
  );
}

class _RecordingGlyphCompilationFacade
    implements PngTracingGlyphCompilationFacade {
  _RecordingGlyphCompilationFacade({List<FontGlyph>? returnedGlyphs})
    : returnedGlyphs = returnedGlyphs ?? _defaultReturnedGlyphs;

  List<IconSymbol>? receivedSymbols;
  int? receivedStartCodePoint;
  int? receivedTargetUnitsPerEm;
  bool? receivedNormalize;
  PngTracingMode? receivedPngTracing;

  static const _defaultReturnedGlyphs = [
    FontGlyph(
      name: 'icon',
      codePoint: 0xe001,
      glyphId: 1,
      sourceWidth: 24,
      sourceHeight: 24,
    ),
  ];
  final List<FontGlyph> returnedGlyphs;

  @override
  List<FontGlyph> compileGlyphs({
    required List<IconSymbol> symbols,
    required int startCodePoint,
    required int targetUnitsPerEm,
    required bool normalize,
    PngTracingMode pngTracing = PngTracingMode.smooth,
  }) {
    receivedSymbols = symbols;
    receivedStartCodePoint = startCodePoint;
    receivedTargetUnitsPerEm = targetUnitsPerEm;
    receivedNormalize = normalize;
    receivedPngTracing = pngTracing;
    return returnedGlyphs;
  }
}

class _RecordingFontWriter implements FontWriter {
  String? lastFamilyName;
  List<FontGlyph>? lastGlyphs;

  @override
  Uint8List write({
    required String familyName,
    required List<FontGlyph> glyphs,
  }) {
    lastFamilyName = familyName;
    lastGlyphs = glyphs;
    return Uint8List.fromList(const [1, 2, 3]);
  }
}

/// A FontWriter that IS a TtfWriter (for _resolveUnitsPerEm type check)
/// but overrides write() to not throw.
class _SafeTtfWriter extends TtfWriter {
  const _SafeTtfWriter();

  @override
  Uint8List write({
    required String familyName,
    required List<FontGlyph> glyphs,
  }) {
    return Uint8List.fromList(const [1, 2, 3]);
  }
}

/// A factory subclass that returns a _SafeTtfWriter to exercise the TtfWriter
/// branch in SvgFontCompiler._resolveUnitsPerEm.
class _TtfResolvingFactory extends FontWriterFactory {
  const _TtfResolvingFactory();

  @override
  FontWriter resolve(FontFormat format) {
    return const _SafeTtfWriter();
  }
}
