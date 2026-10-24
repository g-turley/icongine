import 'dart:convert';
import 'dart:io';

import 'package:icongine/icongine.dart';
import 'package:path/path.dart' as path;

/// Compiles the prepared scale sweep into real OTF/TTF fonts and records cost.
void main(List<String> args) {
  final root = args.isEmpty ? 'build/png_study' : args.first;
  final manifest =
      jsonDecode(File(path.join(root, 'manifest.json')).readAsStringSync())
          as Map<String, dynamic>;
  final cases = (manifest['cases'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final symbols = [
    for (final item in cases)
      IconSymbol(
        file: IconFile(
          absolutePath: path.absolute(root, item['source'] as String),
          relativePath: item['source'] as String,
        ),
        name: item['name'] as String,
      ),
  ];
  final records = <Map<String, Object?>>[];
  for (final mode in [PngTracingMode.legacy, PngTracingMode.smooth]) {
    for (final format in FontFormat.values) {
      final timer = Stopwatch()..start();
      final fontPath = path.join(root, '${mode.name}.${format.name}');
      final result = const SvgFontCompiler().compile(
        config: GenerationConfig(
          packageName: 'study',
          inputDir: path.join(root, 'inputs'),
          outClassFile: path.join(root, 'icons.dart'),
          outFontFile: fontPath,
          className: 'TracingStudy',
          fontFormat: format,
          pngTracing: mode,
        ),
        symbols: symbols,
      );
      File(fontPath).writeAsBytesSync(result.fontBytes);
      for (var i = 0; i < cases.length; i++) {
        final glyph = result.glyphs[i];
        records.add({
          ...cases[i],
          'mode': mode.name,
          'format': format.name,
          'codepoint': glyph.codePoint,
          'contours': glyph.sourceContourPath!.contours.length,
          'segments': glyph.sourceContourPath!.contours.fold<int>(
            0,
            (count, c) => count + c.segments.length,
          ),
          'curves': glyph.sourceContourPath!.contours.fold<int>(
            0,
            (count, c) =>
                count + c.segments.where((s) => s.type.isCurve).length,
          ),
        });
      }
      stdout.writeln(
        '${mode.name}.${format.name}: ${result.fontBytes.length} bytes, ${timer.elapsedMilliseconds}ms',
      );
    }
  }
  File(path.join(root, 'compiled.json')).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(records)}\n',
  );
}
