import 'package:args/args.dart';

import '../domain/font_format.dart';
import 'generate_command.dart';

/// Parsed arguments for one generate invocation.
class GenerateArguments {
  const GenerateArguments({
    required this.pubspecPath,
    required this.showHelp,
    required this.overrides,
  });

  final String pubspecPath;
  final bool showHelp;
  final GenerateConfigOverrides overrides;
}

/// Parses raw generate arguments without performing file-system work.
GenerateArguments parseGenerateArguments(List<String> args) {
  final parser = buildGenerateParser();

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

  return GenerateArguments(
    pubspecPath: pubspecPath,
    showHelp: parsed['help'] as bool,
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
      fontFormat: _parseOptionalFontFormat(parsed),
      normalize: _readOptionalBool(parsed, 'normalize'),
      verbose: _readOptionalBool(parsed, 'verbose'),
      staticIconProvider: _readOptionalBool(parsed, 'static-icon-provider'),
      generateIconMap: _readOptionalBool(parsed, 'generate-icon-map'),
    ),
  );
}

/// Writes only explicitly supplied overrides for verbose diagnostics.
void writeEffectiveConfig(
  void Function(String line) writeln,
  GenerateArguments args,
) {
  writeln('  pubspec: ${args.pubspecPath}');

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
    if (entry.value != null) {
      writeln('  ${entry.key}: ${entry.value}');
    }
  }
}

/// Builds the parser shared by root dispatch and generate help.
ArgParser buildGenerateParser() {
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

String? _extractUnknownOption(
  String message,
  List<String> rawArgs,
  Set<String> knownOptions,
) {
  if (!message.toLowerCase().contains('option')) {
    return null;
  }
  for (final argument in rawArgs) {
    if (!argument.startsWith('-') || argument == '-h' || argument == '--help') {
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
  return parsed.wasParsed(name) ? parsed[name] as bool : null;
}

FontFormat? _parseOptionalFontFormat(ArgResults parsed) {
  const name = 'font-format';
  if (!parsed.wasParsed(name)) {
    return null;
  }
  final rawValue = (parsed[name] as String?)?.trim();
  if (rawValue == null || rawValue.isEmpty) {
    throw const FormatException('Missing value for --font-format option.');
  }
  return switch (rawValue.toLowerCase()) {
    'ttf' => FontFormat.ttf,
    'otf' => FontFormat.otf,
    _ => throw FormatException(
      'Unsupported value for --font-format: "$rawValue".',
    ),
  };
}
