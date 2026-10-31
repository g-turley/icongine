import 'dart:io';

import 'package:icongine/icongine.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const _app = '''
name: demo
dependencies:
  flutter:
    sdk: flutter
''';
const _svg =
    '<svg viewBox="0 0 24 24">'
    '<path d="M2 2H22V22H2Z"/></svg>';

void main() {
  late Directory root;
  late File pubspec;
  late List<String> output;
  late List<String> errors;
  setUp(() {
    root = Directory.systemTemp.createTempSync('icongine_init_test_');
    pubspec = File(path.join(root.path, 'pubspec.yaml'))
      ..writeAsStringSync(_app);
    output = [];
    errors = [];
  });
  tearDown(() => root.deleteSync(recursive: true));
  Future<int> run(List<String> args) => IcongineCli().run(
    ['init', '--config', pubspec.path, ...args],
    stdoutWriteln: output.add,
    stderrWriteln: errors.add,
  );
  void icon(String relative) {
    final file = File(path.join(root.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(_svg);
  }

  test(
    'two path options generate a usable app font and nested Dart API',
    () async {
      icon('art/home.svg');
      icon('art/navigation/back.svg');
      expect(
        await run(['--input-dir', 'art', '--output-font', 'fonts/custom.ttf']),
        0,
      );
      expect(errors, isEmpty);
      final font = File(path.join(root.path, 'fonts/custom.ttf'));
      expect(font.readAsBytesSync().take(4), [0, 1, 0, 0]);
      final dart = File(
        path.join(root.path, 'lib/app_icons.dart'),
      ).readAsStringSync();
      expect(dart, contains('static const IconData home'));
      expect(dart, contains('static const IconData navigationBack'));
      expect(dart, contains('@staticIconProvider'));
      expect(dart, contains('fontPackage = null'));
      expect(dart, isNot(contains('Map<String, IconData> all')));
      final yaml = loadYaml(pubspec.readAsStringSync()) as YamlMap;
      expect(
        yaml['flutter']['fonts'][0]['fonts'][0]['asset'],
        'fonts/custom.ttf',
      );
      final firstPubspec = pubspec.readAsStringSync();
      final firstFont = font.readAsBytesSync();
      expect(await run([]), 0);
      expect(pubspec.readAsStringSync(), firstPubspec);
      expect(font.readAsBytesSync(), firstFont);
    },
  );

  test(
    'an empty project gets a source folder and actionable next step',
    () async {
      expect(await run([]), 0);
      expect(errors, isEmpty);
      expect(
        Directory(path.join(root.path, 'assets/icons')).existsSync(),
        isTrue,
      );
      expect(
        File(path.join(root.path, 'assets/fonts/icons.otf')).existsSync(),
        isFalse,
      );
      expect(output.join('\n'), contains('Add SVG or transparent PNG icons'));
      expect(
        output.join('\n'),
        contains('dart run icongine generate --config'),
      );
    },
  );

  test('no-generate saves setup without compiling existing icons', () async {
    icon('assets/icons/home.svg');
    expect(await run(['--no-generate']), 0);
    expect(
      File(path.join(root.path, 'assets/fonts/icons.otf')).existsSync(),
      isFalse,
    );
    expect(pubspec.readAsStringSync(), contains('png_tracing: smooth'));
  });

  test(
    'refuses to overwrite an unrelated output before editing pubspec',
    () async {
      icon('lib/app_icons.dart');
      final before = pubspec.readAsStringSync();
      expect(await run([]), 65);
      expect(pubspec.readAsStringSync(), before);
      expect(
        File(path.join(root.path, 'lib/app_icons.dart')).readAsStringSync(),
        _svg,
      );
      expect(errors.join('\n'), contains('Refusing to replace existing'));
    },
  );

  test('rejects a source file path without leaving partial setup', () async {
    icon('art.svg');
    expect(await run(['--input-dir', 'art.svg']), 65);
    expect(pubspec.readAsStringSync(), _app);
  });

  test(
    'partial config does not claim ownership of existing default outputs',
    () async {
      icon('lib/app_icons.dart');
      pubspec.writeAsStringSync('$_app\nicongine:\n  normalize: false\n');
      final before = pubspec.readAsStringSync();
      expect(await run([]), 65);
      expect(pubspec.readAsStringSync(), before);
      expect(
        File(path.join(root.path, 'lib/app_icons.dart')).readAsStringSync(),
        _svg,
      );
    },
  );

  test(
    'uses relative Flutter paths for absolute destinations within the app',
    () async {
      final font = path.join(root.path, 'custom fonts', 'icons.otf');
      expect(await run(['--output-font', font]), 0);
      final yaml = loadYaml(pubspec.readAsStringSync()) as YamlMap;
      expect(yaml['icongine']['output_font'], 'custom fonts/icons.otf');
      expect(
        yaml['flutter']['fonts'][0]['fonts'][0]['asset'],
        'custom fonts/icons.otf',
      );
    },
  );

  test(
    'invalid source generation fails with setup saved and recovery advice',
    () async {
      icon('assets/icons/home.svg');
      File(
        path.join(root.path, 'assets/icons/home.svg'),
      ).writeAsStringSync('<svg');
      expect(await run([]), isNot(0));
      expect(pubspec.readAsStringSync(), contains('icongine:'));
      expect(
        errors.join('\n'),
        contains('Setup is saved. Fix the source icons'),
      );
    },
  );

  test('help and invalid options never touch pubspec', () async {
    expect(await run(['--help']), 0);
    expect(output.join('\n'), contains('Usage: icongine init'));
    expect(pubspec.readAsStringSync(), _app);
    expect(await run(['--unknown']), 64);
    expect(await run(['--input-dir', '']), 64);
    expect(await run(['extra.yaml']), 64);
    expect(pubspec.readAsStringSync(), _app);
  });

  test('missing and malformed pubspecs return actionable failures', () async {
    pubspec.deleteSync();
    expect(await run([]), 66);
    expect(errors.join('\n'), contains('No pubspec found'));
    pubspec.writeAsStringSync('name: [unclosed');
    expect(await run([]), 65);
    expect(errors.join('\n'), contains('Invalid pubspec YAML'));
  });
}
