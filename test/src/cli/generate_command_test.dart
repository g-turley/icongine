import 'dart:io';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';
import 'package:path/path.dart' as path;

void main() {
  group('GenerateIconsCommand', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('icongine_cli_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('parses pubspec config and forwards it to runner', () async {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      await pubspec.writeAsString('''
name: sample_pkg
icongine:
  input_dir: assets/custom_icons
  output_font: assets/fonts/custom.otf
  output_class: lib/custom_icons.dart
  name: Example Icons
  font_format: otf
  normalize: false
''');

      final runner = _CaptureRunner();
      final command = GenerateIconsCommand(runner: runner);
      final report = await command.run(pubspecPath: pubspec.path);

      expect(report.compiledSymbolCount, 1);
      expect(runner.capturedConfig, isNotNull);
      expect(runner.capturedConfig!.packageName, 'sample_pkg');
      expect(runner.capturedConfig!.fontFamily, 'Example Icons');
      expect(runner.capturedConfig!.fontPackage, 'Example Icons');
      expect(runner.capturedConfig!.fontFormat, FontFormat.otf);
      expect(runner.capturedConfig!.normalize, isFalse);
      expect(runner.capturedConfig!.verbose, isFalse);
    });

    test('uses parser defaults when icongine section is missing', () async {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      await pubspec.writeAsString('name: sample_pkg');

      final runner = _CaptureRunner();
      final command = GenerateIconsCommand(runner: runner);
      await command.run(pubspecPath: pubspec.path);

      expect(runner.capturedConfig!.inputDir, 'assets/icons');
      expect(runner.capturedConfig!.outFontFile, 'assets/fonts/icons.otf');
      expect(runner.capturedConfig!.normalize, isFalse);
      expect(runner.capturedConfig!.verbose, isFalse);
    });

    test('applies CLI overrides on top of pubspec values', () async {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      await pubspec.writeAsString('''
name: sample_pkg
icongine:
  input_dir: assets/pubspec_icons
  output_font: assets/fonts/pubspec.otf
  output_class: lib/pubspec_icons.dart
  name: PubspecIcons
  font_format: otf
  normalize: true
''');

      final runner = _CaptureRunner();
      final command = GenerateIconsCommand(runner: runner);
      await command.run(
        pubspecPath: pubspec.path,
        overrides: const GenerateConfigOverrides(
          inputDir: 'assets/cli_icons',
          fontFormat: FontFormat.ttf,
          outFontFile: 'assets/fonts/cli.ttf',
          normalize: false,
          verbose: true,
          includeSubdirs: true,
        ),
      );

      expect(runner.capturedConfig, isNotNull);
      expect(runner.capturedConfig!.inputDir, 'assets/cli_icons');
      expect(runner.capturedConfig!.fontFamily, 'PubspecIcons');
      expect(runner.capturedConfig!.fontPackage, 'PubspecIcons');
      expect(runner.capturedConfig!.fontFormat, FontFormat.ttf);
      expect(runner.capturedConfig!.outFontFile, 'assets/fonts/cli.ttf');
      expect(runner.capturedConfig!.normalize, isFalse);
      expect(runner.capturedConfig!.verbose, isTrue);
      expect(runner.capturedConfig!.includeSubdirs, true);
      // Value not overridden should still come from pubspec.
      expect(runner.capturedConfig!.className, 'PubspecIcons');
    });

    test('throws when pubspec root is not a YAML map', () async {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      await pubspec.writeAsString('- not a map');

      final command = GenerateIconsCommand(runner: _CaptureRunner());
      expect(
        () => command.run(pubspecPath: pubspec.path),
        throwsFormatException,
      );
    });

    test('pipeline runner executes generation pipeline end-to-end', () async {
      final inputDir = Directory(path.join(tempDir.path, 'assets', 'icons'))
        ..createSync(recursive: true);
      final outputDir = Directory(path.join(tempDir.path, 'out'))
        ..createSync(recursive: true);
      final svgFile = File(path.join(inputDir.path, 'home.svg'));
      await svgFile.writeAsString(
        '<svg viewBox="0 0 24 24"><path d="M0 0"/></svg>',
      );

      final report = await const PipelineGenerationRunner().run(
        GenerationConfig(
          packageName: 'sample_pkg',
          inputDir: inputDir.path,
          outFontFile: path.join(outputDir.path, 'icons.otf'),
          outClassFile: path.join(outputDir.path, 'icons.dart'),
        ),
      );

      expect(report.stepIds, ['discover', 'compile', 'emit']);
      expect(report.discoveredIconCount, 1);
      expect(report.compiledSymbolCount, 1);
      expect(report.fontOutputPath, path.join(outputDir.path, 'icons.otf'));
    });
  });
}

class _CaptureRunner implements GenerationRunner {
  GenerationConfig? capturedConfig;

  @override
  Future<GenerationReport> run(GenerationConfig config) async {
    capturedConfig = config;
    return const GenerationReport(
      verbose: false,
      stepIds: ['discover', 'compile', 'emit'],
      discoveredIconCount: 1,
      resolvedSymbolCount: 1,
      compiledSymbolCount: 1,
      emittedSymbolCount: 1,
      fontOutputPath: 'assets/fonts/icons.otf',
      classOutputPath: 'lib/app_icons.dart',
    );
  }
}
