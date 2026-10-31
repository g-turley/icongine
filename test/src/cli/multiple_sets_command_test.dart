import 'dart:io';

import 'package:icongine/icongine.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../support/png_tracing_fixtures.dart';

const _app = 'name: demo\ndependencies:\n  flutter:\n    sdk: flutter\n';
const _svg = '<svg viewBox="0 0 24 24"><path d="M2 2H22V22H2Z"/></svg>';

void main() {
  late Directory root;
  late File pubspec;
  late List<String> output;
  late List<String> errors;
  setUp(() {
    root = Directory.systemTemp.createTempSync('icongine_sets_');
    pubspec = File(path.join(root.path, 'pubspec.yaml'))
      ..writeAsStringSync(_app);
    output = [];
    errors = [];
  });
  tearDown(() => root.deleteSync(recursive: true));
  File file(String name) => File(path.join(root.path, name));
  void svg(String name) {
    final destination = file(name);
    destination.parent.createSync(recursive: true);
    destination.writeAsStringSync(_svg);
  }

  Future<int> run(List<String> args) => IcongineCli().run(
    [...args, '--config', pubspec.path],
    stdoutWriteln: output.add,
    stderrWriteln: errors.add,
  );
  Future<int> init(String set) => run([
    'init',
    '--set',
    set,
    '--input-dir',
    'art/$set',
    '--output-font',
    'fonts/$set.ttf',
  ]);

  test(
    'SVG and small PNG sets generate independent TTFs, classes, and registrations',
    () async {
      svg('art/ui/home.svg');
      expect(await init('ui'), 0);
      final uiFont = file('fonts/ui.ttf').readAsBytesSync();
      final uiClass = file('lib/ui_icons.dart').readAsStringSync();
      svg('art/ui/added.svg');
      final png = file('art/brands/home.png');
      png.parent.createSync(recursive: true);
      png.writeAsBytesSync(
        image.encodePng(samplePngFixture(pngTracingFixtures['circle']!)),
      );
      expect(await init('brands'), 0);
      // Adding a set must not regenerate any other set.
      expect(file('fonts/ui.ttf').readAsBytesSync(), uiFont);
      expect(file('lib/ui_icons.dart').readAsStringSync(), uiClass);
      for (final name in ['ui', 'brands']) {
        expect(file('fonts/$name.ttf').readAsBytesSync().take(4), [0, 1, 0, 0]);
        expect(
          file('lib/${name}_icons.dart').readAsStringSync(),
          contains('IconData home'),
        );
      }
      final yaml = loadYaml(pubspec.readAsStringSync()) as YamlMap;
      expect(yaml['flutter']['fonts'], hasLength(2));
      expect(await run([]), 0);
      expect(
        file('lib/ui_icons.dart').readAsStringSync(),
        contains('IconData added'),
      );
      final allUi = file('fonts/ui.ttf').readAsBytesSync();
      final allBrands = file('fonts/brands.ttf').readAsBytesSync();
      expect(await run([]), 0);
      expect(file('fonts/ui.ttf').readAsBytesSync(), allUi);
      expect(file('fonts/brands.ttf').readAsBytesSync(), allBrands);
      expect(errors, isEmpty);
      file('fonts/ui.ttf').deleteSync();
      expect(await run(['generate', '--set', 'brands']), 0);
      expect(file('fonts/ui.ttf').existsSync(), isFalse);
    },
  );

  test(
    'init generates its selected set even when another set has no sources',
    () async {
      expect(await init('ui'), 0);
      svg('art/brands/home.svg');
      expect(await init('brands'), 0);
      expect(file('fonts/brands.ttf').existsSync(), isTrue);
      expect(file('fonts/ui.ttf').existsSync(), isFalse);
      final before = pubspec.readAsStringSync();
      expect(await run(['init']), 65);
      expect(pubspec.readAsStringSync(), before);
    },
  );

  test(
    'unknown selectors and ambiguous output overrides fail before writing',
    () async {
      expect(await init('ui'), 0);
      expect(await init('brands'), 0);
      expect(await run(['--set', 'missing']), 65);
      expect(errors.join('\n'), contains('Available sets: brands, ui'));
      expect(await run(['--output-font', 'fonts/shared.ttf']), 65);
      expect(file('fonts/shared.ttf').existsSync(), isFalse);
      expect(await run(['--set', '']), 64);
    },
  );

  test('cross-set collisions are caught before any generation', () async {
    svg('art/ui/home.svg');
    svg('art/brands/home.svg');
    expect(await init('ui'), 0);
    expect(await init('brands'), 0);
    file('fonts/ui.ttf').deleteSync();
    final source = pubspec.readAsStringSync();
    expect(
      await run(['init', '--set', 'other', '--output-font', 'fonts/ui.ttf']),
      65,
    );
    expect(pubspec.readAsStringSync(), source);
    pubspec.writeAsStringSync(
      source.replaceAll('fonts/brands.ttf', 'fonts/ui.ttf'),
    );
    expect(await run([]), 65);
    expect(file('fonts/ui.ttf').existsSync(), isFalse);
    expect(errors.join('\n'), contains('share output file'));
  });

  test('completed sets are reported if a later source set fails', () async {
    svg('art/brands/home.svg');
    expect(await init('ui'), 0);
    expect(await init('brands'), 0);
    output.clear();
    expect(await run([]), 66);
    expect(output.join('\n'), contains('Set: brands'));
    expect(output.join('\n'), contains('Generation succeeded.'));
    expect(errors.join('\n'), contains('No SVG or PNG icons found'));
  });

  test(
    'programmatic batch generation validates, selects, and reports named sets',
    () async {
      pubspec.writeAsStringSync(
        'name: demo\nicongine:\n  sets:\n    ui: {}\n    brands: {}\n',
      );
      final runner = _Runner();
      final command = GenerateIconsCommand(runner: runner);
      final completed = <String>[];
      final reports = await command.runAll(
        pubspecPath: pubspec.path,
        onReport: (name, report) => completed.add(name),
      );
      expect(reports.keys, ['ui', 'brands']);
      expect(completed, ['ui', 'brands']);
      expect(runner.configs.map((c) => c.className), [
        'UiIcons',
        'BrandsIcons',
      ]);
      await expectLater(
        command.run(pubspecPath: pubspec.path),
        throwsFormatException,
      );
      await command.run(
        pubspecPath: pubspec.path,
        overrides: const GenerateConfigOverrides(setName: 'brands'),
      );
      expect(runner.configs.last.className, 'BrandsIcons');
      final calls = runner.configs.length;
      await expectLater(
        command.runAll(
          pubspecPath: pubspec.path,
          overrides: const GenerateConfigOverrides(
            setName: 'brands',
            className: 'UiIcons',
          ),
        ),
        throwsFormatException,
      );
      expect(runner.configs, hasLength(calls));
    },
  );
}

class _Runner implements GenerationRunner {
  final configs = <GenerationConfig>[];
  @override
  Future<GenerationReport> run(GenerationConfig config) async {
    configs.add(config);
    return const GenerationReport(
      verbose: false,
      stepIds: [],
      discoveredIconCount: 1,
      resolvedSymbolCount: 1,
      compiledSymbolCount: 1,
      emittedSymbolCount: 1,
      fontOutputPath: null,
      classOutputPath: null,
    );
  }
}
