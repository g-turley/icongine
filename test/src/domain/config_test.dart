import 'package:test/test.dart';
import 'package:icongine/icongine.dart';
import 'package:path/path.dart' as path;

void main() {
  group('GenerationConfig', () {
    test('normalizes class names to upper camel', () {
      final config = GenerationConfig(
        packageName: 'sample',
        inputDir: 'assets/icons',
        outFontFile: 'assets/fonts/icons.otf',
        outClassFile: 'lib/app_icons.dart',
        className: 'app_icons',
      );

      expect(config.normalizedClassName, 'AppIcons');
    });

    test('throws for empty packageName', () {
      expect(
        () => GenerationConfig(
          packageName: '   ',
          inputDir: 'assets/icons',
          outFontFile: 'assets/fonts/icons.otf',
          outClassFile: 'lib/app_icons.dart',
        ),
        throwsArgumentError,
      );
    });

    test('uses className for fontFamily', () {
      final config = GenerationConfig(
        packageName: 'sample_pkg',
        inputDir: 'assets/icons',
        outFontFile: 'assets/fonts/icons.otf',
        outClassFile: 'lib/app_icons.dart',
      );

      expect(config.fontFamily, 'AppIcons');
    });

    test('preserves spaces in name when deriving fontFamily', () {
      final config = GenerationConfig(
        packageName: 'sample_pkg',
        className: 'Example Icons',
        inputDir: 'assets/icons',
        outFontFile: 'assets/fonts/icons.otf',
        outClassFile: 'lib/app_icons.dart',
      );

      expect(config.fontFamily, 'Example Icons');
    });

    test('defaults fontPackage to fontFamily (className)', () {
      final config = GenerationConfig(
        packageName: 'sample_pkg',
        inputDir: 'assets/icons',
        outFontFile: 'assets/fonts/icons.otf',
        outClassFile: 'lib/app_icons.dart',
      );

      expect(config.fontPackage, 'AppIcons');
    });

    test('throws for empty inputDir', () {
      expect(
        () => GenerationConfig(
          packageName: 'sample',
          inputDir: '',
          outFontFile: 'assets/fonts/icons.otf',
          outClassFile: 'lib/app_icons.dart',
        ),
        throwsArgumentError,
      );
    });

    test('creates relative asset path from inputDir', () {
      final config = GenerationConfig(
        packageName: 'sample',
        inputDir: path.join('/tmp', 'project', 'assets', 'icons'),
        outFontFile: 'assets/fonts/icons.otf',
        outClassFile: 'lib/app_icons.dart',
      );

      final relPath = config.relAssetPath(
        path.join('/tmp', 'project', 'assets', 'icons', 'social', 'home.svg'),
      );

      expect(relPath, path.join('social', 'home.svg'));
    });

    test('uses otf as default font format', () {
      final config = GenerationConfig(
        packageName: 'sample',
        inputDir: 'assets/icons',
        outFontFile: 'assets/fonts/icons.otf',
        outClassFile: 'lib/app_icons.dart',
      );

      expect(config.fontFormat, FontFormat.otf);
      expect(config.generatesFontFile, isTrue);
    });

    test('allows overriding font format', () {
      final config = GenerationConfig(
        packageName: 'sample',
        inputDir: 'assets/icons',
        outFontFile: 'assets/fonts/icons.otf',
        outClassFile: 'lib/app_icons.dart',
        fontFormat: FontFormat.otf,
      );

      expect(config.fontFormat, FontFormat.otf);
      expect(config.generatesFontFile, isTrue);
    });

    test('requires outFontFile when font output is enabled', () {
      expect(
        () => GenerationConfig(
          packageName: 'sample',
          inputDir: 'assets/icons',
          outClassFile: 'lib/app_icons.dart',
          fontFormat: FontFormat.ttf,
        ),
        throwsArgumentError,
      );
    });
    test('supports rendering knobs', () {
      final config = GenerationConfig(
        packageName: 'sample',
        inputDir: 'assets/icons',
        outFontFile: 'assets/fonts/icons.otf',
        outClassFile: 'lib/app_icons.dart',
        normalize: false,
        staticIconProvider: false,
        generateIconMap: true,
      );

      expect(config.normalize, isFalse);
      expect(config.verbose, isFalse);
      expect(config.staticIconProvider, isFalse);
      expect(config.generateIconMap, isTrue);
    });

    test('throws when font file extension does not match font format', () {
      expect(
        () => GenerationConfig(
          packageName: 'sample',
          inputDir: 'assets/icons',
          outFontFile: 'assets/fonts/icons.ttf',
          outClassFile: 'lib/app_icons.dart',
          fontFormat: FontFormat.otf,
        ),
        throwsArgumentError,
      );
    });

    test('throws when font file extension is unsupported', () {
      expect(
        () => GenerationConfig(
          packageName: 'sample',
          inputDir: 'assets/icons',
          outFontFile: 'assets/fonts/icons.woff',
          outClassFile: 'lib/app_icons.dart',
          fontFormat: FontFormat.otf,
        ),
        throwsArgumentError,
      );
    });
  });
}
