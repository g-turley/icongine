import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  group('GenerationConfigParser', () {
    const parser = GenerationConfigParser();

    test('supports runtime constructor usage', () {
      final runtimeParser = GenerationConfigParser();
      final config = runtimeParser.parsePubspec({'name': 'sample_pkg'});
      expect(config.packageName, 'sample_pkg');
    });

    test('parses pubspec icongine section with documented keys', () {
      final config = parser.parsePubspec({
        'name': 'sample_pkg',
        'icongine': {
          'input_dir': 'assets/custom_icons',
          'output_font': 'assets/fonts/custom.otf',
          'output_class': 'lib/custom_icons.dart',
          'name': 'CustomIcons',
          'font_format': 'otf',
          'normalize': false,
          'verbose': true,
          'static_icon_provider': false,
          'generate_icon_map': true,
        },
      });

      expect(config.packageName, 'sample_pkg');
      expect(config.inputDir, 'assets/custom_icons');
      expect(config.outFontFile, 'assets/fonts/custom.otf');
      expect(config.outClassFile, 'lib/custom_icons.dart');
      expect(config.className, 'CustomIcons');
      expect(config.fontFormat, FontFormat.otf);
      expect(config.normalize, isFalse);
      expect(config.verbose, isTrue);
      expect(config.staticIconProvider, isFalse);
      expect(config.generateIconMap, isTrue);
    });

    test('uses defaults when icongine section is absent', () {
      final config = parser.parsePubspec({'name': 'sample_pkg'});

      expect(config.packageName, 'sample_pkg');
      expect(config.fontFamily, 'AppIcons');
      expect(config.fontPackage, isNull);
      expect(config.inputDir, 'assets/icons');
      expect(config.outFontFile, 'assets/fonts/icons.otf');
      expect(config.outClassFile, 'lib/app_icons.dart');
      expect(config.fontFormat, FontFormat.otf);
      expect(config.normalize, isFalse);
      expect(config.verbose, isFalse);
      expect(config.staticIconProvider, isTrue);
      expect(config.generateIconMap, isFalse);
    });

    test('uses icongine name for font family', () {
      final config = parser.parsePubspec({
        'name': 'sample_pkg',
        'icongine': {'name': 'Example Icons'},
      });

      expect(config.fontFamily, 'Example Icons');
      expect(config.fontPackage, isNull);
    });

    test('reads explicit font package when configured', () {
      final config = parser.parsePubspec({
        'name': 'sample_pkg',
        'icongine': {'name': 'Example Icons', 'font_package': 'sample_pkg'},
      });

      expect(config.fontFamily, 'Example Icons');
      expect(config.fontPackage, 'sample_pkg');
    });

    test('accepts camelCase keys for supported fields', () {
      final config = parser.parsePubspec({
        'name': 'sample_pkg',
        'icongine': {
          'outFontFile': 'assets/fonts/icons.otf',
          'outClassFile': 'lib/generated/icons.dart',
          'className': 'GeneratedIcons',
          'fontFormat': 'otf',
          'normalize': false,
          'verbose': true,
          'staticIconProvider': false,
          'generateIconMap': true,
        },
      });

      expect(config.fontFormat, FontFormat.otf);
      expect(config.outFontFile, 'assets/fonts/icons.otf');
      expect(config.outClassFile, 'lib/generated/icons.dart');
      expect(config.className, 'GeneratedIcons');
      expect(config.normalize, isFalse);
      expect(config.verbose, isTrue);
      expect(config.staticIconProvider, isFalse);
      expect(config.generateIconMap, isTrue);
    });

    test('supports legacy key names for backwards compatibility', () {
      final config = parser.parsePubspec({
        'name': 'sample_pkg',
        'icongine': {
          'out_font_file': 'assets/fonts/legacy.otf',
          'out_class_file': 'lib/legacy_icons.dart',
          'class_name': 'LegacyIcons',
        },
      });

      expect(config.outFontFile, 'assets/fonts/legacy.otf');
      expect(config.outClassFile, 'lib/legacy_icons.dart');
      expect(config.className, 'LegacyIcons');
    });

    test('throws on invalid typed values', () {
      expect(
        () => parser.parsePubspec({
          'name': 'sample_pkg',
          'icongine': {'normalize': 'x'},
        }),
        throwsFormatException,
      );
    });

    test('throws on unsupported font format value', () {
      expect(
        () => parser.parsePubspec({
          'name': 'sample_pkg',
          'icongine': {'font_format': 'woff'},
        }),
        throwsFormatException,
      );
    });

    test('throws when icongine section is not a map', () {
      expect(
        () => parser.parsePubspec({'name': 'sample_pkg', 'icongine': 'bad'}),
        throwsFormatException,
      );
    });

    test('throws when package name is not a string', () {
      expect(() => parser.parsePubspec({'name': true}), throwsFormatException);
    });

    test('throws when bool fields are invalid type', () {
      expect(
        () => parser.parsePubspec({
          'name': 'sample_pkg',
          'icongine': {'include_subdirs': 'yes'},
        }),
        throwsFormatException,
      );
    });
  });
}
