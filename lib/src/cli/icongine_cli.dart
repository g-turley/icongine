import 'dart:io';

import 'package:args/args.dart';

import '../package_info.dart';
import '../pipeline/errors.dart';
import '../pipeline/generation_orchestrator.dart';
import 'generate_command.dart';
import 'generate_options.dart';
import 'shape_debug_command.dart';

/// Function signature used to invoke the generate command.
typedef GenerateRunner =
    Future<GenerationReport> Function({
      required String pubspecPath,
      required GenerateConfigOverrides overrides,
    });

/// Function signature used to invoke the shape debug command.
typedef ShapeDebugRunner =
    int Function(
      List<String> args, {
      required void Function(String line) stdoutWriteln,
      required void Function(String line) stderrWriteln,
    });

/// Top-level CLI facade for generation and debug commands.
class IcongineCli {
  IcongineCli({GenerateRunner? runGenerate, ShapeDebugRunner? runShapeDebug})
    : _runGenerate = runGenerate ?? _defaultRunGenerate,
      _runShapeDebug = runShapeDebug ?? _defaultRunShapeDebug;

  final GenerateRunner _runGenerate;
  final ShapeDebugRunner _runShapeDebug;

  static Future<GenerationReport> _defaultRunGenerate({
    required String pubspecPath,
    required GenerateConfigOverrides overrides,
  }) {
    return GenerateIconsCommand().run(
      pubspecPath: pubspecPath,
      overrides: overrides,
    );
  }

  static int _defaultRunShapeDebug(
    List<String> args, {
    required void Function(String line) stdoutWriteln,
    required void Function(String line) stderrWriteln,
  }) {
    return const ShapeDebugCommand().run(
      args,
      stdoutWriteln: stdoutWriteln,
      stderrWriteln: stderrWriteln,
    );
  }

  /// Runs the CLI for the provided raw [args].
  Future<int> run(
    List<String> args, {
    required void Function(String line) stdoutWriteln,
    required void Function(String line) stderrWriteln,
  }) async {
    final rootParser = _buildRootParser();
    if (args.isEmpty) {
      return _runGenerateCommand(
        const [],
        stdoutWriteln: stdoutWriteln,
        stderrWriteln: stderrWriteln,
      );
    }

    final firstArg = args.first;
    if (firstArg == '-h' || firstArg == '--help') {
      _writeRootUsage(stdoutWriteln, rootParser);
      return 0;
    }
    if (firstArg == '-v' || firstArg == '--version' || firstArg == 'version') {
      stdoutWriteln('icongine $icongineVersion');
      return 0;
    }
    if (firstArg == 'generate') {
      return _runGenerateCommand(
        args.sublist(1),
        stdoutWriteln: stdoutWriteln,
        stderrWriteln: stderrWriteln,
      );
    }
    if (firstArg == 'debug-shape') {
      return _runShapeDebug(
        args.sublist(1),
        stdoutWriteln: stdoutWriteln,
        stderrWriteln: stderrWriteln,
      );
    }

    // Retain the original shorthand: options without a command mean generate.
    return _runGenerateCommand(
      args,
      stdoutWriteln: stdoutWriteln,
      stderrWriteln: stderrWriteln,
    );
  }

  Future<int> _runGenerateCommand(
    List<String> args, {
    required void Function(String line) stdoutWriteln,
    required void Function(String line) stderrWriteln,
  }) async {
    late GenerateArguments parsed;
    try {
      parsed = parseGenerateArguments(args);
    } on FormatException catch (error) {
      stderrWriteln('Invalid arguments: ${error.message}');
      stderrWriteln('Run `icongine generate --help` for usage.');
      return 64;
    }

    if (parsed.showHelp) {
      _writeGenerateUsage(stdoutWriteln, buildGenerateParser());
      return 0;
    }

    stdoutWriteln('Generating icons using ${parsed.pubspecPath}...');
    if (parsed.overrides.verbose == true) {
      stdoutWriteln('CLI overrides:');
      writeEffectiveConfig(stdoutWriteln, parsed);
    }

    try {
      final report = await _runGenerate(
        pubspecPath: parsed.pubspecPath,
        overrides: parsed.overrides,
      );
      _writeReport(stdoutWriteln, report);
      return 0;
    } on NoIconsFoundError catch (error) {
      stderrWriteln('No SVG or PNG icons found in ${error.inputDir}.');
      stderrWriteln(
        'Add source icons there or update `icongine.input_dir` in '
        '${parsed.pubspecPath}.',
      );
      return 66;
    } on NamingDiagnosticsError catch (error) {
      stderrWriteln('Icon names could not be generated:');
      for (final message in error.messages) {
        stderrWriteln('  - $message');
      }
      return 65;
    } on FormatException catch (error) {
      stderrWriteln('Invalid configuration or icon source: ${error.message}');
      return 65;
    } on ArgumentError catch (error) {
      stderrWriteln('Invalid configuration: $error');
      return 65;
    } on FileSystemException catch (error) {
      final location = error.path == null ? '' : ' (${error.path})';
      stderrWriteln(
        'Could not read or write a required file: '
        '${error.message}$location',
      );
      return 74;
    } catch (error, stackTrace) {
      stderrWriteln('icongine generation failed: $error');
      if (parsed.overrides.verbose == true) {
        stderrWriteln(stackTrace.toString());
      } else {
        stderrWriteln('Re-run with `--verbose` for diagnostic details.');
      }
      return 1;
    }
  }

  void _writeReport(
    void Function(String line) writeln,
    GenerationReport report,
  ) {
    writeln('Generation succeeded.');
    if (report.verbose) {
      writeln('Pipeline: ${report.stepIds.join(' -> ')}');
      writeln(
        'Counts: discovered ${report.discoveredIconCount}, '
        'resolved ${report.resolvedSymbolCount}, '
        'compiled ${report.compiledSymbolCount}, '
        'emitted ${report.emittedSymbolCount}',
      );
    }
    for (final warning in report.namingWarnings) {
      writeln('Warning: $warning');
    }
    for (final warning in report.normalizationWarnings) {
      writeln('Warning: $warning');
    }
    if (report.verbose && report.normalizationModifiedGlyphNames.isNotEmpty) {
      writeln(
        'Normalized glyphs (${report.normalizationModifiedGlyphNames.length}): '
        '${report.normalizationModifiedGlyphNames.join(', ')}',
      );
    }
    if (report.fontOutputPath != null) {
      writeln('Font: ${report.fontOutputPath}');
    }
    if (report.classOutputPath != null) {
      writeln('Dart API: ${report.classOutputPath}');
    }
  }

  void _writeRootUsage(void Function(String line) writeln, ArgParser parser) {
    writeln('icongine CLI v$icongineVersion');
    writeln('Usage: icongine <command> [arguments]');
    writeln('       icongine [generate options] [<pubspec_path>]');
    writeln('');
    writeln('Commands:');
    writeln('  generate       Generate icon fonts and the Dart IconData API.');
    writeln(
      '  debug-shape    Inspect a single SVG or test shape and print diagnostics.',
    );
    writeln('');
    writeln('Global options:');
    writeln(parser.usage);
    writeln('');
    writeln(
      'Generate options can be used with or without the `generate` command.',
    );
    writeln('Examples:');
    writeln('  icongine generate --config path/to/pubspec.yaml');
    writeln('  icongine debug-shape walk-outline');
    writeln('  icongine debug-shape path/to/problem_icon.svg');
    writeln('');
    writeln('Run `icongine generate --help` for generation options.');
    writeln('Run `icongine debug-shape --help` for shape diagnostics.');
    writeln('Run `icongine version` to print the installed version.');
  }

  void _writeGenerateUsage(
    void Function(String line) writeln,
    ArgParser parser,
  ) {
    writeln('icongine generate v$icongineVersion');
    writeln('Usage: icongine generate [options] [<pubspec_path>]');
    writeln('       icongine [generate options] [<pubspec_path>]');
    writeln('');
    writeln(parser.usage);
    writeln('');
    writeln('Values come from pubspec first; CLI options override them.');
  }
}

ArgParser _buildRootParser() {
  final parser = ArgParser(allowTrailingOptions: true)
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message.',
    )
    ..addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the installed icongine version.',
    );
  parser.addCommand('generate', buildGenerateParser());
  parser.addCommand('debug-shape');
  return parser;
}
