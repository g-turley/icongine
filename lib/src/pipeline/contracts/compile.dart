import 'dart:typed_data';

import '../../domain/config.dart';
import '../../domain/icon_symbol.dart';
import '../font/font_glyph.dart';
import '../font/font_writer.dart';
import '../font/font_writer_factory.dart';
import '../font/formats/otf/writer.dart';
import '../font/formats/ttf/writer.dart';
import 'glyph_compilation_facade.dart';

class IconCompileResult {
  const IconCompileResult({
    required this.fontBytes,
    required this.fontFamily,
    required this.compiledSymbolCount,
    required this.glyphs,
    this.normalizationWarnings = const [],
    this.normalizationModifiedGlyphNames = const [],
  });

  final Uint8List fontBytes;
  final String fontFamily;
  final int compiledSymbolCount;
  final List<FontGlyph> glyphs;
  final List<String> normalizationWarnings;
  final List<String> normalizationModifiedGlyphNames;
}

abstract interface class IconCompiler {
  IconCompileResult compile({
    required GenerationConfig config,
    required List<IconSymbol> symbols,
  });
}

class StubIconCompiler implements IconCompiler {
  const StubIconCompiler();

  @override
  IconCompileResult compile({
    required GenerationConfig config,
    required List<IconSymbol> symbols,
  }) {
    return IconCompileResult(
      fontBytes: Uint8List(0),
      fontFamily: config.fontFamily,
      compiledSymbolCount: symbols.length,
      glyphs: const [],
      normalizationWarnings: const [],
      normalizationModifiedGlyphNames: const [],
    );
  }
}

class SvgFontCompiler implements IconCompiler {
  const SvgFontCompiler({
    this.fontWriterFactory = const FontWriterFactory(),
    this.glyphCompilationFacade = const SvgGlyphCompilationFacade(),
  });

  static const _startCodePoint = 0xe001;
  final FontWriterFactory fontWriterFactory;
  final GlyphCompilationFacade glyphCompilationFacade;

  @override
  IconCompileResult compile({
    required GenerationConfig config,
    required List<IconSymbol> symbols,
  }) {
    final FontWriter fontWriter = fontWriterFactory.resolve(config.fontFormat);

    final targetUnitsPerEm = _resolveUnitsPerEm(fontWriter);
    final glyphs = glyphCompilationFacade.compileGlyphs(
      symbols: symbols,
      startCodePoint: _startCodePoint,
      targetUnitsPerEm: targetUnitsPerEm,
      normalize: config.normalize,
    );
    final normalizationDiagnostics = _buildNormalizationDiagnostics(
      glyphs: glyphs,
      normalize: config.normalize,
      targetUnitsPerEm: targetUnitsPerEm,
    );

    // Write font bytes using the resolved writer.
    final fontBytes = fontWriter.write(
      familyName: config.fontFamily,
      glyphs: glyphs,
    );

    return IconCompileResult(
      fontBytes: fontBytes,
      fontFamily: config.fontFamily,
      compiledSymbolCount: symbols.length,
      glyphs: glyphs,
      normalizationWarnings: normalizationDiagnostics.warnings,
      normalizationModifiedGlyphNames:
          normalizationDiagnostics.modifiedGlyphNames,
    );
  }

  _NormalizationDiagnostics _buildNormalizationDiagnostics({
    required List<FontGlyph> glyphs,
    required bool normalize,
    required int targetUnitsPerEm,
  }) {
    if (!normalize || glyphs.length < 2) {
      return const _NormalizationDiagnostics();
    }

    final groups = <String, int>{};
    for (final glyph in glyphs) {
      final key =
          '${glyph.sourceWidth.toStringAsFixed(2)}x${glyph.sourceHeight.toStringAsFixed(2)}';
      groups.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    if (groups.length <= 1) {
      return const _NormalizationDiagnostics();
    }

    final sortedSizes = groups.keys.toList()..sort();
    final chosenSize = _resolveChosenSize(
      groups: groups,
      totalGlyphCount: glyphs.length,
    );
    final modifiedGlyphNames = glyphs
        .where((glyph) => glyph.normalizationScaled)
        .map((glyph) => glyph.name)
        .toList(growable: false);
    return _NormalizationDiagnostics(
      warnings: [
        'normalize detected mixed source icon sizes: ${sortedSizes.join(', ')}; '
            'chosen source reference size: $chosenSize (SVG units); '
            'output coordinate system: $targetUnitsPerEm em units.',
      ],
      modifiedGlyphNames: modifiedGlyphNames,
    );
  }

  String _resolveChosenSize({
    required Map<String, int> groups,
    required int totalGlyphCount,
  }) {
    String? majorityKey;
    var majorityCount = 0;
    for (final entry in groups.entries) {
      if (entry.value > totalGlyphCount / 2 && entry.value > majorityCount) {
        majorityKey = entry.key;
        majorityCount = entry.value;
      }
    }
    if (majorityKey != null) {
      return majorityKey;
    }

    String? largestKey;
    var largestArea = -1.0;
    for (final key in groups.keys) {
      final parts = key.split('x');
      if (parts.length != 2) {
        continue;
      }
      final width = double.tryParse(parts[0]);
      final height = double.tryParse(parts[1]);
      if (width == null || height == null) {
        continue;
      }
      final area = width * height;
      if (area > largestArea) {
        largestArea = area;
        largestKey = key;
      }
    }
    return largestKey ?? groups.keys.first;
  }

  int _resolveUnitsPerEm(FontWriter writer) {
    if (writer is OtfWriter) {
      return writer.unitsPerEm;
    }
    if (writer is TtfWriter) {
      return writer.unitsPerEm;
    }
    return 512;
  }
}

class _NormalizationDiagnostics {
  const _NormalizationDiagnostics({
    this.warnings = const [],
    this.modifiedGlyphNames = const [],
  });

  final List<String> warnings;
  final List<String> modifiedGlyphNames;
}

class SvgBounds {
  const SvgBounds({required this.width, required this.height});

  final double width;
  final double height;
}

abstract interface class SvgBoundsExtractor {
  SvgBounds extract(String svgContent);
}

class DefaultSvgBoundsExtractor implements SvgBoundsExtractor {
  const DefaultSvgBoundsExtractor();

  static const SvgBounds _defaultBounds = SvgBounds(width: 24, height: 24);

  @override
  SvgBounds extract(String svgContent) {
    final viewBoxMatch = RegExp(
      "viewBox\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]",
      caseSensitive: false,
    ).firstMatch(svgContent);

    if (viewBoxMatch != null) {
      final parts = viewBoxMatch.group(1)!.split(RegExp(r'[\s,]+'));
      if (parts.length >= 4) {
        final width = double.tryParse(parts[2]);
        final height = double.tryParse(parts[3]);
        if (width != null && height != null && width > 0 && height > 0) {
          return SvgBounds(width: width, height: height);
        }
      }
    }

    final width = _extractDimension(svgContent, 'width');
    final height = _extractDimension(svgContent, 'height');
    if (width != null && height != null && width > 0 && height > 0) {
      return SvgBounds(width: width, height: height);
    }

    return _defaultBounds;
  }

  double? _extractDimension(String svgContent, String attr) {
    final match = RegExp(
      "$attr\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]",
      caseSensitive: false,
    ).firstMatch(svgContent);
    if (match == null) {
      return null;
    }
    final raw = match.group(1)!;
    final numeric = RegExp(r'[-+]?[0-9]*\.?[0-9]+').firstMatch(raw)?.group(0);
    if (numeric == null) {
      return null;
    }
    return double.tryParse(numeric);
  }
}
