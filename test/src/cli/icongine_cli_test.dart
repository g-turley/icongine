import 'package:icongine/icongine.dart';
import 'package:test/test.dart';

void main() {
  group('IcongineCli', () {
    test('uses default generate runner wiring when none is provided', () async {
      final stdoutLines = <String>[];
      final stderrLines = <String>[];
      final cli = IcongineCli();

      final exitCode = await cli.run(
        const ['--help'],
        stdoutWriteln: stdoutLines.add,
        stderrWriteln: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(stdoutLines.join('\n'), contains('Usage: icongine'));
      expect(stdoutLines.join('\n'), contains('v$icongineVersion'));
      expect(stderrLines, isEmpty);
    });

    test('prints version for version command', () async {
      final stdoutLines = <String>[];
      final cli = IcongineCli();

      final exitCode = await cli.run(
        const ['version'],
        stdoutWriteln: stdoutLines.add,
        stderrWriteln: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines, ['icongine $icongineVersion']);
    });

    test('prints version for --version flag', () async {
      final stdoutLines = <String>[];
      final cli = IcongineCli();

      final exitCode = await cli.run(
        const ['--version'],
        stdoutWriteln: stdoutLines.add,
        stderrWriteln: (_) {},
      );

      expect(exitCode, 0);
      expect(stdoutLines, ['icongine $icongineVersion']);
    });

    test('runs generate command when args are empty', () async {
      String? capturedPubspecPath;
      final cli = IcongineCli(
        runGenerate: ({required pubspecPath, required overrides}) {
          capturedPubspecPath = pubspecPath;
          return Future.value(_report);
        },
      );

      final exitCode = await cli.run(
        const [],
        stdoutWriteln: (_) {},
        stderrWriteln: (_) {},
      );

      expect(exitCode, 0);
      expect(capturedPubspecPath, 'pubspec.yaml');
    });

    test('prints root help for --help', () async {
      final stdoutLines = <String>[];
      final stderrLines = <String>[];
      final cli = IcongineCli(
        runGenerate: ({required pubspecPath, required overrides}) =>
            Future.value(_report),
      );

      final exitCode = await cli.run(
        const ['--help'],
        stdoutWriteln: stdoutLines.add,
        stderrWriteln: stderrLines.add,
      );

      expect(exitCode, 0);
      final helpOutput = stdoutLines.join('\n');
      expect(helpOutput, contains('Usage: icongine'));
      expect(helpOutput, contains('Commands:'));
      expect(helpOutput, contains('generate'));
      expect(helpOutput, contains('debug-shape'));
      expect(helpOutput, contains('icongine generate --help'));
      expect(helpOutput, contains('icongine debug-shape --help'));
      expect(stderrLines, isEmpty);
    });

    test('runs generate subcommand with --config path', () async {
      final stdoutLines = <String>[];
      final stderrLines = <String>[];
      String? capturedPubspecPath;
      final cli = IcongineCli(
        runGenerate: ({required pubspecPath, required overrides}) {
          capturedPubspecPath = pubspecPath;
          return Future.value(_report);
        },
      );

      final exitCode = await cli.run(
        const ['generate', '--config', '/tmp/custom_pubspec.yaml'],
        stdoutWriteln: stdoutLines.add,
        stderrWriteln: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(capturedPubspecPath, '/tmp/custom_pubspec.yaml');
      expect(stdoutLines.join('\n'), contains('Generation succeeded.'));
      expect(stdoutLines.join('\n'), isNot(contains('Pipeline: ')));
      expect(stderrLines, isEmpty);
    });

    test('prints step counters only when verbose report is enabled', () async {
      final stdoutLines = <String>[];
      final cli = IcongineCli(
        runGenerate: ({required pubspecPath, required overrides}) {
          return Future.value(
            const GenerationReport(
              verbose: true,
              stepIds: ['discover', 'compile', 'emit'],
              discoveredIconCount: 3,
              resolvedSymbolCount: 3,
              compiledSymbolCount: 3,
              emittedSymbolCount: 3,
              fontOutputPath: 'a.otf',
              classOutputPath: 'a.dart',
            ),
          );
        },
      );

      final exitCode = await cli.run(
        const ['generate'],
        stdoutWriteln: stdoutLines.add,
        stderrWriteln: (_) {},
      );

      expect(exitCode, 0);
      expect(
        stdoutLines.join('\n'),
        contains('Pipeline: discover -> compile -> emit'),
      );
      expect(
        stdoutLines.join('\n'),
        contains('Counts: discovered 3, resolved 3, compiled 3, emitted 3'),
      );
    });

    test(
      'accepts positional pubspec path for backward compatibility',
      () async {
        String? capturedPubspecPath;
        final cli = IcongineCli(
          runGenerate: ({required pubspecPath, required overrides}) {
            capturedPubspecPath = pubspecPath;
            return Future.value(_report);
          },
        );

        final exitCode = await cli.run(
          const ['/tmp/pubspec_alt.yaml'],
          stdoutWriteln: (_) {},
          stderrWriteln: (_) {},
        );

        expect(exitCode, 0);
        expect(capturedPubspecPath, '/tmp/pubspec_alt.yaml');
      },
    );

    test('returns usage error for duplicate config paths', () async {
      final stderrLines = <String>[];
      final cli = IcongineCli(
        runGenerate: ({required pubspecPath, required overrides}) =>
            Future.value(_report),
      );

      final exitCode = await cli.run(
        const ['generate', '--config', '/tmp/a.yaml', '/tmp/b.yaml'],
        stdoutWriteln: (_) {},
        stderrWriteln: stderrLines.add,
      );

      expect(exitCode, 64);
      expect(
        stderrLines.join('\n'),
        contains('Config path already provided; use only one pubspec path.'),
      );
    });

    test('returns usage error for unknown option', () async {
      final stderrLines = <String>[];
      final cli = IcongineCli(
        runGenerate: ({required pubspecPath, required overrides}) =>
            Future.value(_report),
      );

      final exitCode = await cli.run(
        const ['generate', '--nope'],
        stdoutWriteln: (_) {},
        stderrWriteln: stderrLines.add,
      );

      expect(exitCode, 64);
      expect(stderrLines.join('\n'), contains('Unknown option: --nope'));
    });

    test('prints generate help for generate --help', () async {
      final stdoutLines = <String>[];
      final stderrLines = <String>[];
      final cli = IcongineCli(
        runGenerate: ({required pubspecPath, required overrides}) =>
            Future.value(_report),
      );

      final exitCode = await cli.run(
        const ['generate', '--help'],
        stdoutWriteln: stdoutLines.add,
        stderrWriteln: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(stdoutLines.join('\n'), contains('icongine generate'));
      expect(stdoutLines.join('\n'), contains('v$icongineVersion'));
      expect(stderrLines, isEmpty);
    });

    test('dispatches debug-shape command', () async {
      final stdoutLines = <String>[];
      final stderrLines = <String>[];
      List<String>? capturedArgs;
      final cli = IcongineCli(
        runShapeDebug:
            (args, {required stdoutWriteln, required stderrWriteln}) {
              capturedArgs = args;
              stdoutWriteln('debug output');
              return 0;
            },
      );

      final exitCode = await cli.run(
        const ['debug-shape', 'walk-outline'],
        stdoutWriteln: stdoutLines.add,
        stderrWriteln: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(capturedArgs, ['walk-outline']);
      expect(stdoutLines, ['debug output']);
      expect(stderrLines, isEmpty);
    });

    test('returns command failure when generate runner throws', () async {
      final stderrLines = <String>[];
      final cli = IcongineCli(
        runGenerate: ({required pubspecPath, required overrides}) =>
            Future<GenerationReport>.error(StateError('boom')),
      );

      final exitCode = await cli.run(
        const ['generate'],
        stdoutWriteln: (_) {},
        stderrWriteln: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.first, contains('icongine generation failed'));
      expect(stderrLines.join('\n'), isNot(contains('#0')));
      expect(stderrLines.last, contains('Re-run with `--verbose`'));
    });

    test('prints an actionable message when no icons are found', () async {
      final stderrLines = <String>[];
      final cli = IcongineCli(
        runGenerate: ({required pubspecPath, required overrides}) =>
            Future<GenerationReport>.error(NoIconsFoundError('assets/missing')),
      );

      final exitCode = await cli.run(
        const ['generate'],
        stdoutWriteln: (_) {},
        stderrWriteln: stderrLines.add,
      );

      expect(exitCode, 66);
      expect(stderrLines.first, contains('No SVG or PNG icons found'));
      expect(stderrLines.last, contains('icongine.input_dir'));
    });

    test(
      'prints CLI overrides only when verbose output is requested',
      () async {
        final stdoutLines = <String>[];
        final cli = IcongineCli(
          runGenerate: ({required pubspecPath, required overrides}) {
            return Future.value(
              const GenerationReport(
                verbose: true,
                stepIds: ['discover', 'compile', 'emit'],
                discoveredIconCount: 1,
                resolvedSymbolCount: 1,
                compiledSymbolCount: 1,
                emittedSymbolCount: 1,
                fontOutputPath: 'a.otf',
                classOutputPath: 'a.dart',
              ),
            );
          },
        );

        final exitCode = await cli.run(
          const ['generate', '--input-dir', 'assets/custom', '--verbose'],
          stdoutWriteln: stdoutLines.add,
          stderrWriteln: (_) {},
        );

        expect(exitCode, 0);
        expect(stdoutLines.join('\n'), contains('CLI overrides:'));
        expect(stdoutLines.join('\n'), contains('input_dir: assets/custom'));
        expect(stdoutLines.join('\n'), contains('verbose: true'));
      },
    );

    test('forwards CLI overrides to generator', () async {
      GenerateConfigOverrides? capturedOverrides;
      final cli = IcongineCli(
        runGenerate: ({required pubspecPath, required overrides}) {
          capturedOverrides = overrides;
          return Future.value(_report);
        },
      );

      final exitCode = await cli.run(
        const [
          'generate',
          '--input-dir',
          'assets/custom',
          '--font-format',
          'ttf',
          '--no-normalize',
          '--no-include-subdirs',
        ],
        stdoutWriteln: (_) {},
        stderrWriteln: (_) {},
      );

      expect(exitCode, 0);
      expect(capturedOverrides, isNotNull);
      expect(capturedOverrides!.inputDir, 'assets/custom');
      expect(capturedOverrides!.fontFormat, FontFormat.ttf);
      expect(capturedOverrides!.normalize, false);
      expect(capturedOverrides!.verbose, isNull);
      expect(capturedOverrides!.includeSubdirs, false);
    });
  });
}

const _report = GenerationReport(
  verbose: false,
  stepIds: ['discover', 'compile', 'emit'],
  discoveredIconCount: 1,
  resolvedSymbolCount: 1,
  compiledSymbolCount: 1,
  emittedSymbolCount: 1,
  fontOutputPath: 'assets/fonts/icons.ttf',
  classOutputPath: 'lib/app_icons.dart',
);
