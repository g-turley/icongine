import 'dart:io';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';
import 'package:path/path.dart' as path;

void main() {
  group('DiscoverStep', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('icongine_discover_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('populates discovered files and resolved symbols', () async {
      final inputDir = Directory(path.join(tempDir.path, 'icons'));
      await inputDir.create(recursive: true);
      await File(
        path.join(inputDir.path, 'food-home.svg'),
      ).writeAsString('<svg/>');
      await File(
        path.join(inputDir.path, 'food_home.svg'),
      ).writeAsString('<svg/>');

      const step = DiscoverStep();
      final state = GenerationState();

      await step.run(
        GenerationConfig(
          packageName: 'sample',
          inputDir: inputDir.path,
          outFontFile: 'assets/fonts/icons.otf',
          outClassFile: 'lib/icons.dart',
        ),
        state,
      );

      expect(state.discoveredFiles, hasLength(2));
      expect(state.resolvedSymbols.map((item) => item.name).toList(), [
        'foodHome',
        'foodHome2',
      ]);
    });

    test('throws when no svg files are found', () async {
      final inputDir = Directory(path.join(tempDir.path, 'icons'));
      await inputDir.create(recursive: true);

      const step = DiscoverStep();

      try {
        await step.run(
          GenerationConfig(
            packageName: 'sample',
            inputDir: inputDir.path,
            outFontFile: 'assets/fonts/icons.otf',
            outClassFile: 'lib/icons.dart',
          ),
          GenerationState(),
        );
        fail('Expected NoIconsFoundError');
      } on NoIconsFoundError catch (error) {
        expect(error.inputDir, inputDir.path);
        expect(error.toString(), contains('No SVG icons found'));
        expect(error.toString(), contains(inputDir.path));
      }
    });

    test('throws naming diagnostics error for reserved identifiers', () async {
      final inputDir = Directory(path.join(tempDir.path, 'icons'));
      await inputDir.create(recursive: true);
      await File(
        path.join(inputDir.path, 'font-family.svg'),
      ).writeAsString('<svg/>');

      const step = DiscoverStep();

      expect(
        () => step.run(
          GenerationConfig(
            packageName: 'sample',
            inputDir: inputDir.path,
            outFontFile: 'assets/fonts/icons.otf',
            outClassFile: 'lib/icons.dart',
          ),
          GenerationState(),
        ),
        throwsA(
          isA<NamingDiagnosticsError>().having(
            (error) => error.messages.single,
            'message',
            contains('reserved name "fontFamily"'),
          ),
        ),
      );
    });
  });
}
