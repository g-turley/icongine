import 'package:icongine/icongine.dart';
import 'package:test/test.dart';

void main() {
  const parser = GenerationConfigParser();
  Map<String, GenerationConfig> parse(Object? section) =>
      parser.parseSets({'name': 'demo', 'icongine': section});

  test(
    'single-set configuration remains the default without changing options',
    () {
      final configs = parse({'input_dir': 'art', 'normalize': true});
      expect(configs.keys, ['default']);
      expect(configs.values.single.className, 'AppIcons');
      expect(configs.values.single.inputDir, 'art');
      expect(configs.values.single.normalize, isTrue);
      expect(configs.values.single.includeSubdirs, isFalse);
    },
  );

  test(
    'named sets get distinct paths and classes and infer TTF from output',
    () {
      final configs = parse({
        'sets': {
          'ui': {'output_font': 'fonts/ui.ttf'},
          'brands': <String, Object>{},
        },
      });
      expect(configs.keys, ['ui', 'brands']);
      expect(configs['ui']!.fontFormat, FontFormat.ttf);
      expect(configs['ui']!.className, 'UiIcons');
      expect(configs['ui']!.outClassFile, 'lib/ui_icons.dart');
      expect(configs['brands']!.inputDir, 'assets/icons/brands');
      expect(configs['brands']!.outFontFile, 'assets/fonts/brands.otf');
      expect(configs['brands']!.pngTracing, PngTracingMode.smooth);
      expect(configs['brands']!.normalize, isFalse);
      expect(
        () => parser.parsePubspec({
          'icongine': {
            'sets': {'ui': <String, Object?>{}},
          },
        }),
        throwsFormatException,
      );
    },
  );

  test('named defaults respect aliases and existing class suffixes', () {
    final configs = parse({
      'sets': {
        'brand-icons': {
          'className': 'CustomIcons',
          'outFontFile': 'custom.ttf',
          'outClassFile': 'custom.dart',
          'inputDir': 'art',
          'pngTracing': 'pixel',
        },
        'other_icons': <String, Object?>{},
      },
    });
    expect(configs['brand-icons']!.className, 'CustomIcons');
    expect(configs['brand-icons']!.fontFormat, FontFormat.ttf);
    expect(configs['brand-icons']!.outClassFile, 'custom.dart');
    expect(configs['brand-icons']!.inputDir, 'art');
    expect(configs['brand-icons']!.pngTracing, PngTracingMode.pixel);
    expect(configs['other_icons']!.className, 'OtherIcons');
    expect(configs['other_icons']!.outClassFile, 'lib/other_icons.dart');
  });

  test('an explicit format selects the matching default named font path', () {
    final configs = parse({
      'sets': {
        'ui': {'font_format': 'ttf'},
      },
    });
    expect(configs['ui']!.outFontFile, 'assets/fonts/ui.ttf');
    expect(configs['ui']!.fontFormat, FontFormat.ttf);
  });

  test('rejects malformed, ambiguous, and unsafe named-set configuration', () {
    for (final section in <Object?>[
      {'sets': null},
      {'sets': <Object?>[]},
      {'sets': <String, Object?>{}},
      {
        'sets': {'ui': null},
      },
      {
        'sets': {'ui': <Object?>[]},
      },
      {
        'sets': {'../ui': <String, Object?>{}},
      },
      {
        'sets': {'UI': <String, Object?>{}},
      },
      {
        'sets': {null: <String, Object?>{}},
      },
      {
        'sets': {
          'ui': {'sets': <String, Object?>{}},
        },
      },
      {
        'sets': {'ui': <String, Object?>{}},
        'input_dir': 'art',
      },
    ]) {
      expect(() => parse(section), throwsFormatException, reason: '$section');
    }
  });
}
