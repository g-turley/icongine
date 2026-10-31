import 'package:icongine/icongine.dart';
import 'package:icongine/src/cli/init_options.dart';
import 'package:icongine/src/cli/init_pubspec.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const _app = '''
name: demo
dependencies:
  flutter:
    sdk: flutter
''';

InitArguments _args({String? font, String? name}) => InitArguments(
  pubspecPath: 'pubspec.yaml',
  showHelp: false,
  generate: true,
  outputFont: font,
  className: name,
);

void main() {
  test(
    'app setup enables smooth tracing and nested names without normalization',
    () {
      final setup = InitPubspec(_app, _args());
      expect(setup.config.pngTracing, PngTracingMode.smooth);
      expect(setup.config.includeSubdirs, isTrue);
      expect(setup.config.prefixWithSubdir, isTrue);
      expect(setup.config.staticIconProvider, isTrue);
      expect(setup.config.normalize, isFalse);
      expect(setup.config.generateIconMap, isFalse);
      expect(setup.config.fontPackage, isNull);
      expect(setup.contents, isNot(contains('normalize:')));
      final yaml = loadYaml(setup.contents) as YamlMap;
      final flutter = yaml['flutter'] as YamlMap;
      final fonts = flutter['fonts'] as YamlList;
      expect(fonts.single['family'], 'AppIcons');
      expect(fonts.single['fonts'][0]['asset'], 'assets/fonts/icons.otf');
      expect(InitPubspec(setup.contents, _args()).contents, setup.contents);
    },
  );

  test('preserves comments, dependencies, assets, and unrelated fonts', () {
    const source = '''$_app
# Keep our branding
flutter:
  uses-material-design: true # material icons
  assets:
    - assets/images/
  fonts:
    # Our text font
    - family: Brand
      fonts:
        - asset: assets/brand.ttf
          weight: 700
''';
    final setup = InitPubspec(source, _args(font: 'assets/custom.ttf'));
    expect(setup.config.fontFormat, FontFormat.ttf);
    for (final text in [
      '# Keep our branding',
      '# material icons',
      '# Our text font',
      'weight: 700',
      '- assets/images/',
      'sdk: flutter',
    ]) {
      expect(setup.contents, contains(text));
    }
    final yaml = loadYaml(setup.contents) as YamlMap;
    expect(yaml['flutter']['fonts'], hasLength(2));
    expect(
      yaml['flutter']['fonts'][1]['fonts'][0]['asset'],
      'assets/custom.ttf',
    );
  });

  test('keeps configured legacy aliases and explicit preferences', () {
    final setup = InitPubspec('''$_app
icongine:
  className: MyIcons
  inputDir: art
  outFontFile: assets/my.ttf
  fontFormat: ttf
  outClassFile: lib/my.dart
  pngTracing: pixel
  includeSubdirs: false
  normalize: true
  generate_icon_map: true
  custom_option: keep
''', _args());
    expect(setup.config.className, 'MyIcons');
    expect(setup.config.inputDir, 'art');
    expect(setup.config.fontFormat, FontFormat.ttf);
    expect(setup.config.pngTracing, PngTracingMode.pixel);
    expect(setup.config.includeSubdirs, isFalse);
    expect(setup.config.normalize, isTrue);
    expect(setup.config.generateIconMap, isTrue);
    expect(setup.contents, contains('custom_option: keep'));
    expect(setup.contents, isNot(contains('png_tracing:')));
  });

  test('explicit font and family overrides update owned registration once', () {
    final first = InitPubspec(_app, _args());
    final second = InitPubspec(
      first.contents,
      _args(font: 'assets/renamed.ttf', name: 'CustomIcons'),
    );
    final yaml = loadYaml(second.contents) as YamlMap;
    final fonts = yaml['flutter']['fonts'] as YamlList;
    expect(fonts, hasLength(1));
    expect(fonts.single['family'], 'CustomIcons');
    expect(fonts.single['fonts'][0]['asset'], 'assets/renamed.ttf');
    expect(second.config.fontFormat, FontFormat.ttf);
  });

  test(
    'rejects a conflicting family instead of replacing an unrelated font',
    () {
      expect(
        () => InitPubspec('''$_app
flutter:
  fonts:
    - family: AppIcons
      fonts:
        - asset: assets/important.ttf
''', _args()),
        throwsFormatException,
      );
    },
  );

  test('uses ttf default destination when an existing config requests ttf', () {
    final setup = InitPubspec(
      '$_app\nicongine:\n  font_format: ttf\n',
      _args(),
    );
    expect(setup.config.outFontFile, 'assets/fonts/icons.ttf');
  });

  test('supports inline YAML and null sections', () {
    for (final source in [
      '$_app\nflutter:\nicongine:\n',
      '$_app\nflutter: {uses-material-design: true, fonts: []}\n',
    ]) {
      final first = InitPubspec(source, _args());
      expect(InitPubspec(first.contents, _args()).contents, first.contents);
    }
  });

  test('rejects malformed sections and invalid paths with useful errors', () {
    for (final source in [
      '[]',
      'name: dart_only',
      '$_app\nflutter: []\n',
      '$_app\nflutter: {fonts: {}}\n',
      '$_app\nicongine: false\n',
    ]) {
      expect(() => InitPubspec(source, _args()), throwsFormatException);
    }
    for (final font in ['font', 'font.woff', '../outside.otf']) {
      expect(() => InitPubspec(_app, _args(font: font)), throwsFormatException);
    }
  });
}
