import 'dart:convert';
import 'dart:io';

import 'package:icongine/icongine.dart';
import 'package:path/path.dart' as path;

/// Builds actual fonts for the README placement comparison.
void main(List<String> args) {
  final root = args.firstOrNull ?? 'build/normalization';
  Directory(root).createSync(recursive: true);
  const fixtures = [
    {'name': 'centered', 'x': 12, 'y': 12, 'r': 5},
    {'name': 'offset', 'x': 7, 'y': 7, 'r': 5},
    {'name': 'corner', 'x': 20, 'y': 20, 'r': 2},
  ];
  final symbols = <IconSymbol>[];
  for (final item in fixtures) {
    final name = item['name']! as String;
    final source = path.join(root, '$name.svg');
    File(source).writeAsStringSync(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<circle cx="${item['x']}" cy="${item['y']}" r="${item['r']}"/>'
      '</svg>',
    );
    symbols.add(
      IconSymbol(
        name: name,
        file: IconFile(
          absolutePath: path.absolute(source),
          relativePath: '$name.svg',
        ),
      ),
    );
  }
  for (final normalize in [false, true]) {
    final result = const SvgFontCompiler().compile(
      config: GenerationConfig(
        packageName: 'normalization_example',
        inputDir: root,
        outFontFile: path.join(root, '$normalize.otf'),
        outClassFile: path.join(root, 'unused.dart'),
        normalize: normalize,
      ),
      symbols: symbols,
    );
    File(path.join(root, '$normalize.otf')).writeAsBytesSync(result.fontBytes);
  }
  File(
    path.join(root, 'fixtures.json'),
  ).writeAsStringSync(jsonEncode(fixtures));
  stdout.writeln('Built normalization comparison fonts in $root.');
}
