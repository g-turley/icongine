import 'package:args/args.dart';

import '../../icongine.dart';

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
        const <String>[],
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
    try {
      final parsed = _parseGenerateArgs(args);
      if (parsed.showHelp) {
        _writeGenerateUsage(stdoutWriteln, _buildGenerateParser());
        return 0;
      }

      stdoutWriteln('Generating icons using ${parsed.pubspecPath}...');
      if (parsed.overrides.isEmpty) {
        if (parsed.overrides.verbose == true) {
          stdoutWriteln('Verbose output enabled.');
        }
      } else if (parsed.overrides.verbose == true) {
        stdoutWriteln('CLI overrides:');
        _writeEffectiveConfig(stdoutWriteln, parsed);
      }

      final report = await _runGenerate(
        pubspecPath: parsed.pubspecPath,
        overrides: parsed.overrides,
      );

      stdoutWriteln('Generation succeeded.');
      if (report.verbose) {
        stdoutWriteln('Pipeline: ${report.stepIds.join(' -> ')}');
        stdoutWriteln(
          'Counts: discovered ${report.discoveredIconCount}, '
          'resolved ${report.resolvedSymbolCount}, '
          'compiled ${report.compiledSymbolCount}, '
          'emitted ${report.emittedSymbolCount}',
        );
      }
      for (final warning in report.namingWarnings) {
        stdoutWriteln('Warning: $warning');
      }
      for (final warning in report.normalizationWarnings) {
        stdoutWriteln('Warning: $warning');
      }
      if (report.verbose && report.normalizationModifiedGlyphNames.isNotEmpty) {
        stdoutWriteln(
          'Normalized glyphs (${report.normalizationModifiedGlyphNames.length}): '
          '${report.normalizationModifiedGlyphNames.join(', ')}',
        );
      }
      if (report.fontOutputPath != null) {
        stdoutWriteln('Font: ${report.fontOutputPath}');
      }
      if (report.classOutputPath != null) {
        stdoutWriteln('Dart API: ${report.classOutputPath}');
      }
      return 0;
    } on FormatException catch (error) {
      stderrWriteln('icongine generation failed: ${error.message}');
      stderrWriteln('Run `icongine generate --help` for usage.');
      return 64;
    } catch (error, stackTrace) {
      stderrWriteln('icongine generation failed: $error');
      stderrWriteln(stackTrace.toString());
      return 1;
    }
  }

  void _writeRootUsage(
    void Function(String line) stdoutWriteln,
    ArgParser parser,
  ) {
    stdoutWriteln('icongine CLI v$icongineVersion');
    stdoutWriteln('Usage: icongine <command> [arguments]');
    stdoutWriteln('       icongine [generate options] [<pubspec_path>]');
    stdoutWriteln('');
    stdoutWriteln('Commands:');
    stdoutWriteln(
      '  generate       Generate icon fonts and the Dart IconData API.',
    );
    stdoutWriteln(
      '  debug-shape    Inspect a single SVG or test shape and print diagnostics.',
    );
    stdoutWriteln('');
    stdoutWriteln('Global options:');
    stdoutWriteln(parser.usage);
    stdoutWriteln('');
    stdoutWriteln(
      'Generate options can be used with or without the `generate` command.',
    );
    stdoutWriteln('Examples:');
    stdoutWriteln('  icongine generate --config path/to/pubspec.yaml');
    stdoutWriteln('  icongine debug-shape walk-outline');
    stdoutWriteln('  icongine debug-shape path/to/problem_icon.svg');
    stdoutWriteln('');
    stdoutWriteln('Run `icongine generate --help` for generation options.');
    stdoutWriteln('Run `icongine debug-shape --help` for shape diagnostics.');
    stdoutWriteln('Run `icongine version` to print the installed version.');
  }

  void _writeGenerateUsage(
    void Function(String line) stdoutWriteln,
    ArgParser parser,
  ) {
    stdoutWriteln('icongine generate v$icongineVersion');
    stdoutWriteln('Usage: icongine generate [options] [<pubspec_path>]');
    stdoutWriteln('       icongine [generate options] [<pubspec_path>]');
    stdoutWriteln('');
    stdoutWriteln(parser.usage);
    stdoutWriteln('');
    stdoutWriteln('Values come from pubspec first; CLI options override them.');
  }
}

class _GenerateArgs {
  const _GenerateArgs({
    required this.pubspecPath,
    required this.showHelp,
    required this.overrides,
  });

  final String pubspecPath;
  final bool showHelp;
  final GenerateConfigOverrides overrides;
}

_GenerateArgs _parseGenerateArgs(List<String> args) {
  final parser = _buildGenerateParser();

  late ArgResults parsed;
  try {
    parsed = parser.parse(args);
  } on FormatException catch (error) {
    final unknownOption = _extractUnknownOption(
      error.message,
      args,
      parser.options.keys.toSet(),
    );
    if (unknownOption != null) {
      throw FormatException('Unknown option: $unknownOption');
    }
    rethrow;
  }

  final showHelp = parsed['help'] as bool;
  final configPath = (parsed['config'] as String?)?.trim();
  final positional = parsed.rest;

  if (configPath != null && configPath.isEmpty) {
    throw const FormatException('Missing value for --config option.');
  }

  if ((configPath != null && positional.isNotEmpty) || positional.length > 1) {
    throw const FormatException(
      'Config path already provided; use only one pubspec path.',
    );
  }

  final pubspecPath =
      configPath ?? (positional.isEmpty ? 'pubspec.yaml' : positional.single);

  final fontFormat = _parseOptionalFontFormat(
    parsed: parsed,
    name: 'font-format',
    label: '--font-format',
  );

  return _GenerateArgs(
    pubspecPath: pubspecPath,
    showHelp: showHelp,
    overrides: GenerateConfigOverrides(
      inputDir: _readOptionalString(parsed, 'input-dir', '--input-dir'),
      outFontFile: _readOptionalString(parsed, 'output-font', '--output-font'),
      outClassFile: _readOptionalString(
        parsed,
        'output-class',
        '--output-class',
      ),
      className: _readOptionalString(parsed, 'class-name', '--class-name'),
      includeSubdirs: _readOptionalBool(parsed, 'include-subdirs'),
      prefixWithSubdir: _readOptionalBool(parsed, 'prefix-with-subdir'),
      fontFormat: fontFormat,
      normalize: _readOptionalBool(parsed, 'normalize'),
      verbose: _readOptionalBool(parsed, 'verbose'),
      staticIconProvider: _readOptionalBool(parsed, 'static-icon-provider'),
      generateIconMap: _readOptionalBool(parsed, 'generate-icon-map'),
    ),
  );
}

String? _extractUnknownOption(
  String message,
  List<String> rawArgs,
  Set<String> knownOptions,
) {
  if (!message.toLowerCase().contains('option')) {
    return null;
  }
  for (final argument in rawArgs) {
    if (!argument.startsWith('-')) {
      continue;
    }
    if (argument == '-h' || argument == '--help') {
      continue;
    }
    if (argument.startsWith('--')) {
      final normalized = argument.split('=').first.substring(2);
      final canonicalName = normalized.startsWith('no-')
          ? normalized.substring(3)
          : normalized;
      if (!knownOptions.contains(canonicalName)) {
        return argument.split('=').first;
      }
    } else {
      // Preserve a clear error when shorthand options are unknown.
      return argument.split('=').first;
    }
  }
  return null;
}

String? _readOptionalString(ArgResults parsed, String name, String label) {
  if (!parsed.wasParsed(name)) {
    return null;
  }
  final value = (parsed[name] as String?)?.trim();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing value for $label option.');
  }
  return value;
}

bool? _readOptionalBool(ArgResults parsed, String name) {
  if (!parsed.wasParsed(name)) {
    return null;
  }
  return parsed[name] as bool;
}

FontFormat? _parseOptionalFontFormat({
  required ArgResults parsed,
  required String name,
  required String label,
}) {
  if (!parsed.wasParsed(name)) {
    return null;
  }
  final rawValue = (parsed[name] as String?)?.trim();
  if (rawValue == null || rawValue.isEmpty) {
    throw FormatException('Missing value for $label option.');
  }
  return switch (rawValue.toLowerCase()) {
    'ttf' => FontFormat.ttf,
    'otf' => FontFormat.otf,
    _ => throw FormatException('Unsupported value for $label: "$rawValue".'),
  };
}

void _writeEffectiveConfig(
  void Function(String line) stdoutWriteln,
  _GenerateArgs args,
) {
  stdoutWriteln('  pubspec: ${args.pubspecPath}');

  final overrides = <String, Object?>{
    'input_dir': args.overrides.inputDir,
    'output_font': args.overrides.outFontFile,
    'output_class': args.overrides.outClassFile,
    'name': args.overrides.className,
    'font_format': args.overrides.fontFormat?.name,
    'include_subdirs': args.overrides.includeSubdirs,
    'prefix_with_subdir': args.overrides.prefixWithSubdir,
    'normalize': args.overrides.normalize,
    'verbose': args.overrides.verbose,
    'static_icon_provider': args.overrides.staticIconProvider,
    'generate_icon_map': args.overrides.generateIconMap,
  };

  for (final entry in overrides.entries) {
    if (entry.value == null) {
      continue;
    }
    stdoutWriteln('  ${entry.key}: ${entry.value}');
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
  parser.addCommand('generate', _buildGenerateParser());
  parser.addCommand('debug-shape');
  return parser;
}

ArgParser _buildGenerateParser() {
  return ArgParser(allowTrailingOptions: true)
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show help for generate command.',
    )
    ..addOption(
      'config',
      valueHelp: 'path',
      help: 'Path to pubspec yaml file. Default: pubspec.yaml.',
    )
    ..addOption(
      'input-dir',
      valueHelp: 'path',
      help:
          'Icon input directory (pubspec: input_dir). Fallback: assets/icons.',
    )
    ..addOption(
      'output-font',
      valueHelp: 'path',
      help:
          'Output font file (pubspec: output_font). Fallback: assets/fonts/icons.otf.',
    )
    ..addOption(
      'output-class',
      valueHelp: 'path',
      help:
          'Output Dart class file (pubspec: output_class). Fallback: lib/app_icons.dart.',
    )
    ..addOption(
      'class-name',
      valueHelp: 'name',
      help: 'Generated class name (pubspec: name). Fallback: AppIcons.',
    )
    ..addOption(
      'font-format',
      valueHelp: 'otf|ttf',
      allowed: ['otf', 'ttf'],
      help: 'Font format (pubspec: font_format). Fallback: otf.',
    )
    ..addFlag(
      'include-subdirs',
      negatable: true,
      help: 'Recurse into nested icon directories.',
    )
    ..addFlag(
      'prefix-with-subdir',
      negatable: true,
      help: 'Prefix icon names with relative subdirectory.',
    )
    ..addFlag(
      'normalize',
      negatable: true,
      help:
          'Normalize glyph contours to a shared source box before fitting into the output em square. Default: false.',
    )
    ..addFlag(
      'verbose',
      negatable: true,
      help: 'Print pipeline details and applied CLI overrides.',
    )
    ..addFlag(
      'static-icon-provider',
      negatable: true,
      help: 'Add Flutter tree-shaking annotation to the generated icon class.',
    )
    ..addFlag(
      'generate-icon-map',
      negatable: true,
      help: 'Generate a static icon-name map for catalog-style UIs.',
    );
}
