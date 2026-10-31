import 'package:icongine/icongine.dart';
import 'package:icongine/src/cli/init_options.dart';
import 'package:icongine/src/cli/init_pubspec.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const _app = 'name: demo\ndependencies:\n  flutter:\n    sdk: flutter\n';
InitArguments _args(String? set, {String? font, String? name}) => InitArguments(
  pubspecPath: 'pubspec.yaml',
  showHelp: false,
  generate: false,
  setName: set,
  outputFont: font,
  className: name,
);

void main() {
  test(
    'creates independent named sets and registers each family exactly once',
    () {
      final ui = InitPubspec(_app, _args('ui', font: 'fonts/ui.ttf'));
      final brands = InitPubspec(
        ui.contents,
        _args('brands', font: 'fonts/brands.ttf'),
      );
      final repeated = InitPubspec(brands.contents, _args('brands'));
      expect(repeated.contents, brands.contents);
      expect(repeated.config.className, 'BrandsIcons');
      final yaml = loadYaml(repeated.contents) as YamlMap;
      expect(yaml['icongine']['sets'].keys, unorderedEquals(['ui', 'brands']));
      expect(yaml['flutter']['fonts'], hasLength(2));
      expect(yaml['flutter']['fonts'][0]['family'], 'UiIcons');
      expect(yaml['flutter']['fonts'][1]['family'], 'BrandsIcons');
      expect(
        () => InitPubspec(repeated.contents, _args(null)),
        throwsFormatException,
      );
    },
  );

  test('single named set can be reinitialized without choosing it again', () {
    final first = InitPubspec(_app, _args('ui'));
    final again = InitPubspec(first.contents, _args(null));
    expect(again.setName, 'ui');
    expect(again.contents, first.contents);
  });

  test('init can fill a null named-set placeholder', () {
    final setup = InitPubspec(
      '${_app}icongine:\n  sets:\n    ui:\n',
      _args('ui'),
    );
    expect(setup.config.className, 'UiIcons');
    expect(setup.config.inputDir, 'assets/icons/ui');
  });

  test(
    'updating one set leaves the other configuration and registration intact',
    () {
      final ui = InitPubspec(_app, _args('ui'));
      final brands = InitPubspec(ui.contents, _args('brands'));
      final updated = InitPubspec(
        brands.contents,
        _args('brands', font: 'fonts/new.ttf', name: 'BrandMarks'),
      );
      final before = loadYaml(brands.contents) as YamlMap;
      final after = loadYaml(updated.contents) as YamlMap;
      expect(after['icongine']['sets']['ui'], before['icongine']['sets']['ui']);
      expect(after['flutter']['fonts'][0], before['flutter']['fonts'][0]);
      expect(after['flutter']['fonts'], hasLength(2));
      expect(after['flutter']['fonts'][1]['family'], 'BrandMarks');
      expect(
        after['flutter']['fonts'][1]['fonts'][0]['asset'],
        'fonts/new.ttf',
      );
    },
  );

  test(
    'migration keeps single-set semantics, comments, and multiline metadata',
    () {
      const source = '''${_app}icongine:
  # Keep original art and placement
  input_dir: original # relative source
  name: ExistingIcons
  normalize: true
  custom_metadata: |+
    An intentional multiline note.
    With another line.

flutter:
  uses-material-design: true
''';
      for (final text in [source, source.replaceAll('\n', '\r\n')]) {
        final oldYaml = loadYaml(text) as YamlMap;
        final result = InitPubspec(text, _args('brands'));
        final yaml = loadYaml(result.contents) as YamlMap;
        expect(yaml['icongine']['sets']['default'], oldYaml['icongine']);
        expect(result.contents, contains('# Keep original art and placement'));
        expect(result.contents, contains('# relative source'));
        expect(yaml['flutter']['uses-material-design'], isTrue);
        final configs = const GenerationConfigParser().parseSets(
          yaml.map((key, value) => MapEntry(key.toString(), value)),
        );
        expect(configs['default']!.className, 'ExistingIcons');
        expect(configs['default']!.inputDir, 'original');
        expect(configs['default']!.normalize, isTrue);
        expect(configs['default']!.includeSubdirs, isFalse);
        expect(configs['default']!.outClassFile, 'lib/app_icons.dart');
      }
    },
  );

  test('migration supports inline maps and an end-of-file block', () {
    for (final source in [
      '${_app}icongine: {name: ExistingIcons, input_dir: original} # keep this\n',
      '${_app}icongine:\n    input_dir: original\n    name: ExistingIcons',
      '{name: demo, dependencies: {flutter: {sdk: flutter}}, icongine: {name: ExistingIcons}}',
    ]) {
      final old = loadYaml(source) as YamlMap;
      final result = InitPubspec(source, _args('brands'));
      final yaml = loadYaml(result.contents) as YamlMap;
      expect(yaml['icongine']['sets']['default'], old['icongine']);
      if (source.contains('# keep this')) {
        expect(result.contents, contains('# keep this'));
      }
    }
  });

  test(
    'rejects cross-set families, classes, outputs, and invalid selectors',
    () {
      final ui = InitPubspec(_app, _args('ui'));
      for (final args in [
        _args('brands', name: 'UiIcons'),
        _args('brands', name: 'ui icons'),
        _args('brands', font: 'assets/fonts/ui.otf'),
        _args('../brands'),
      ]) {
        expect(() => InitPubspec(ui.contents, args), throwsFormatException);
      }
    },
  );

  test(
    'migration refuses aliases rather than changing unrelated shared values',
    () {
      const source =
          '${_app}shared: &icons {name: ExistingIcons}\nicongine: *icons\n';
      expect(() => InitPubspec(source, _args('brands')), throwsFormatException);
    },
  );
}
