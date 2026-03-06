import 'dart:io';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';
import 'package:path/path.dart' as path;

void main() {
  group('Generation pipeline', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('icongine_pipeline_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'GenerationPipelineBuilder includes discover/compile/emit steps by default',
      () async {
        final inputDir = Directory(path.join(tempDir.path, 'icons'));
        final outputDir = Directory(path.join(tempDir.path, 'out'));
        await inputDir.create(recursive: true);
        await outputDir.create(recursive: true);
        await File(
          path.join(inputDir.path, 'home.svg'),
        ).writeAsString('<svg viewBox="0 0 24 24"></svg>');

        final runner = GenerationPipelineBuilder().build();

        final report = await runner.run(
          GenerationConfig(
            packageName: 'sample',
            inputDir: inputDir.path,
            outFontFile: path.join(outputDir.path, 'icons.otf'),
            outClassFile: path.join(outputDir.path, 'icons.dart'),
          ),
        );

        expect(report.stepIds, ['discover', 'compile', 'emit']);
        expect(report.discoveredIconCount, 1);
        expect(report.resolvedSymbolCount, 1);
        expect(report.compiledSymbolCount, 1);
        expect(report.emittedSymbolCount, 1);
        expect(report.namingWarnings, isEmpty);
        expect(report.fontOutputPath, path.join(outputDir.path, 'icons.otf'));
        expect(report.classOutputPath, path.join(outputDir.path, 'icons.dart'));
      },
    );

    test('pipeline runs steps in order', () async {
      final seen = <String>[];
      final pipeline = GenerationPipeline([
        _Step('discover', seen),
        _Step('compile', seen),
        _Step('emit', seen),
      ]);

      final runner = GenerationPipelineRunner(pipeline: pipeline);

      final report = await runner.run(
        GenerationConfig(
          packageName: 'sample',
          inputDir: 'assets/icons',
          outFontFile: 'assets/fonts/icons.otf',
          outClassFile: 'lib/icons.dart',
        ),
      );

      expect(seen, ['discover', 'compile', 'emit']);
      expect(report.discoveredIconCount, 0);
      expect(report.resolvedSymbolCount, 0);
      expect(report.compiledSymbolCount, 0);
      expect(report.emittedSymbolCount, 0);
      expect(report.namingWarnings, isEmpty);
      expect(report.fontOutputPath, isNull);
      expect(report.classOutputPath, isNull);
    });

    test('surfaces naming warnings in generation report', () async {
      final inputDir = Directory(path.join(tempDir.path, 'icons'));
      final outputDir = Directory(path.join(tempDir.path, 'out'));
      await inputDir.create(recursive: true);
      await outputDir.create(recursive: true);
      await File(
        path.join(inputDir.path, 'food-home.svg'),
      ).writeAsString('<svg viewBox="0 0 24 24"></svg>');
      await File(
        path.join(inputDir.path, 'food_home.svg'),
      ).writeAsString('<svg viewBox="0 0 24 24"></svg>');

      final runner = GenerationPipelineBuilder().build();

      final report = await runner.run(
        GenerationConfig(
          packageName: 'sample',
          inputDir: inputDir.path,
          outFontFile: path.join(outputDir.path, 'icons.otf'),
          outClassFile: path.join(outputDir.path, 'icons.dart'),
        ),
      );

      expect(report.namingWarnings, hasLength(1));
      expect(report.namingWarnings.single, contains('collided on symbol'));
    });
  });
}

class _Step implements GenerationStep {
  _Step(this._id, this._seen);

  final String _id;
  final List<String> _seen;

  @override
  String get id => _id;

  @override
  Future<void> run(GenerationConfig config, GenerationState state) async {
    _seen.add(_id);
  }
}
