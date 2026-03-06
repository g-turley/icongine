// Integration script: processes SVG test shapes through the full pipeline
// and writes .otf files to build/ for manual inspection.
//
// Usage:
//   dart run tool/generate_test_report.dart                    # all test_shapes
//   dart run tool/generate_test_report.dart path/to/shape.svg  # single file
//
// Run this from the repository root. If you see a package resolution error,
// first run `dart pub get`, then retry this script.
import 'dart:io';
import 'dart:typed_data';

import 'package:icongine/icongine.dart';

void main(List<String> args) {
  final svgFiles = _resolveSvgFiles(args);
  if (svgFiles.isEmpty) {
    _exitWithError(
      'No SVG files found. Pass one or more .svg paths or run from the repo root.',
      1,
    );
  }

  final outputDir = Directory('build');
  outputDir.createSync(recursive: true);

  final symbols = <IconSymbol>[];
  for (final svgFile in svgFiles) {
    final baseName = svgFile.uri.pathSegments.last;
    final nameWithoutExtension = baseName.replaceFirst(
      RegExp(r'\.svg$', caseSensitive: false),
      '',
    );
    final glyphName = nameWithoutExtension.toLowerCamel();
    if (glyphName.isEmpty) {
      _exitWithError(
        'Unable to derive a valid glyph name from: ${svgFile.path}',
        2,
      );
    }
    symbols.add(
      IconSymbol(
        file: IconFile(
          absolutePath: svgFile.absolute.path,
          relativePath: baseName,
        ),
        name: glyphName,
      ),
    );
  }

  print('Processing ${symbols.length} SVG file(s):\n');

  // Print per-file extraction summary.
  const extractor = SvgDocumentPathExtractor();
  const parser = SvgPathDataParser();
  for (final symbol in symbols) {
    final svgContent = File(symbol.file.absolutePath).readAsStringSync();
    final documentData = extractor.extract(svgContent);
    final pathCount = documentData.pathEntries.length;

    var totalContours = 0;
    var totalSegments = 0;
    for (final entry in documentData.pathEntries) {
      final contourPath = parser.parse(entry.pathData);
      totalContours += contourPath.contours.length;
      for (final contour in contourPath.contours) {
        totalSegments += contour.segments.length;
      }
    }

    final viewport = documentData.viewport;
    final viewportLabel = viewport != null
        ? '${viewport.width.toStringAsFixed(0)}x${viewport.height.toStringAsFixed(0)}'
        : 'none';
    print(
      '  ${symbol.name.padRight(30)} '
      'viewport=$viewportLabel  '
      'paths=$pathCount  '
      'contours=$totalContours  '
      'segments=$totalSegments',
    );
  }

  _compileAndReport(
    symbols: symbols,
    normalize: true,
    outputFontFile: 'build/test_icons_normalized.otf',
    label: 'normalized',
  );
  _compileAndReport(
    symbols: symbols,
    normalize: false,
    outputFontFile: 'build/test_icons_non_normalized.otf',
    label: 'non-normalized',
  );
}

void _compileAndReport({
  required List<IconSymbol> symbols,
  required bool normalize,
  required String outputFontFile,
  required String label,
}) {
  print('\nCompiling font ($label)...');
  final config = GenerationConfig(
    packageName: 'test_icons',
    inputDir: 'test/test_shapes',
    outClassFile: 'build/test_icons.dart',
    outFontFile: outputFontFile,
    fontFormat: FontFormat.otf,
    normalize: normalize,
  );

  final result = const SvgFontCompiler().compile(
    config: config,
    symbols: symbols,
  );

  if (result.fontBytes.isEmpty) {
    _exitWithError('Font bytes are empty for $label.', 1);
  }

  if (result.fontBytes.length < 12) {
    _exitWithError(
      'Font bytes are too short to be a valid SFNT container for $label.',
      1,
    );
  }

  final sfntData = ByteData.sublistView(result.fontBytes);
  final scalerType = sfntData.getUint32(0);
  final numTables = sfntData.getUint16(4);
  final scalerLabel = scalerType == 0x4F54544F
      ? 'OTTO'
      : '0x${scalerType.toRadixString(16)}';

  print('\nResults ($label):');
  print('  Normalize: $normalize');
  print('  Scaler type: $scalerLabel');
  print('  Tables: $numTables');
  print('  Glyphs: ${result.glyphs.length} (+ .notdef)');
  print('  Font bytes: ${result.fontBytes.length}');

  for (var index = 0; index < numTables; index += 1) {
    final recordOffset = 12 + index * 16;
    if (recordOffset + 16 > result.fontBytes.length) {
      print('  [invalid-table-record] index=$index');
      continue;
    }
    final tagBytes = result.fontBytes.sublist(recordOffset, recordOffset + 4);
    if (tagBytes.length < 4) {
      print('  [invalid-tag] index=$index');
      continue;
    }
    final tag = String.fromCharCodes(tagBytes);
    final length = sfntData.getUint32(recordOffset + 12);
    print('    [$tag] $length bytes');
  }

  print('\nGlyph map ($label):');
  for (final glyph in result.glyphs) {
    final contourCount = glyph.compiledContourPath?.contours.length ?? 0;
    var segmentCount = 0;
    if (glyph.compiledContourPath != null) {
      for (final contour in glyph.compiledContourPath!.contours) {
        segmentCount += contour.segments.length;
      }
    }
    print(
      '  U+${glyph.codePoint.toRadixString(16).toUpperCase().padLeft(4, '0')} '
      '${glyph.name.padRight(30)} '
      'contours=$contourCount  segments=$segmentCount',
    );
  }

  final outputFile = File(outputFontFile);
  outputFile.writeAsBytesSync(result.fontBytes);
  print(
    '\nOutput ($label): ${outputFile.path} (${result.fontBytes.length} bytes)',
  );
  print('Open with: open ${outputFile.path}');
}

List<File> _resolveSvgFiles(List<String> args) {
  if (args.isNotEmpty) {
    final directPaths = <File>[];
    for (final inputPath in args) {
      final file = File(inputPath);
      if (!file.existsSync()) {
        _exitWithError('Missing path: $inputPath', 1);
      }
      directPaths.add(file);
    }
    return directPaths;
  }

  final shapesDir = Directory('test/test_shapes');
  if (!shapesDir.existsSync()) {
    return const [];
  }

  return shapesDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.svg'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

void _exitWithError(String message, int code) {
  stderr.writeln('ERROR: $message');
  exit(code);
}
