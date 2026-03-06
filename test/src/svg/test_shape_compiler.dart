import 'dart:io';

import 'package:icongine/icongine.dart';

/// Compiles a single SVG test shape and returns intermediate contour paths.
class TestShapeCompileResult {
  const TestShapeCompileResult({
    required this.sourceContourPath,
    required this.compiledContourPath,
    required this.glyph,
  });

  /// Contours after winding correction and stroke expansion, before coordinate transform.
  final SvgContourPath sourceContourPath;

  /// Contours after SVG-to-font coordinate transform.
  final SvgContourPath compiledContourPath;

  /// Final font glyph emitted by the full compile pipeline.
  final FontGlyph glyph;
}

TestShapeCompileResult compileTestShape(String shapeName) {
  final shapeFile = File('test/test_shapes/$shapeName.svg');
  if (!shapeFile.existsSync()) {
    throw StateError('Missing test shape: ${shapeFile.path}');
  }

  final compiler = const SvgFontCompiler();
  final result = compiler.compile(
    config: GenerationConfig(
      packageName: 'test_shapes',
      inputDir: 'test/test_shapes',
      outClassFile: 'build/test_shapes.dart',
      outFontFile: 'build/test_shapes.otf',
      fontFormat: FontFormat.otf,
    ),
    symbols: [
      IconSymbol(
        file: IconFile(
          absolutePath: shapeFile.absolute.path,
          relativePath: shapeFile.uri.pathSegments.last,
        ),
        name: shapeName.toLowerCamel(),
      ),
    ],
  );

  if (result.glyphs.isEmpty) {
    throw StateError('No glyph emitted for $shapeName');
  }

  final glyph = result.glyphs.single;
  final sourceContourPath = glyph.sourceContourPath;
  if (sourceContourPath == null) {
    throw StateError('Missing source contour path for $shapeName');
  }

  final compiledContourPath = glyph.compiledContourPath;
  if (compiledContourPath == null) {
    throw StateError('Missing compiled contour path for $shapeName');
  }

  return TestShapeCompileResult(
    sourceContourPath: sourceContourPath,
    compiledContourPath: compiledContourPath,
    glyph: glyph,
  );
}
