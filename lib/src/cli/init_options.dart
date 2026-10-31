import 'package:args/args.dart';

/// App setup options; relative paths are resolved from the selected pubspec.
class InitArguments {
  const InitArguments({
    required this.pubspecPath,
    required this.showHelp,
    required this.generate,
    this.inputDir,
    this.outputFont,
    this.outputClass,
    this.className,
    this.setName,
  });

  final String pubspecPath;
  final bool showHelp;
  final bool generate;
  final String? inputDir;
  final String? outputFont;
  final String? outputClass;
  final String? className;
  final String? setName;
}

InitArguments parseInitArguments(List<String> args) {
  final parsed = buildInitParser().parse(args);
  String? read(String key) {
    final value = parsed[key] as String?;
    if (value != null && value.trim().isEmpty) {
      throw FormatException('Missing value for --$key.');
    }
    return value;
  }

  final config = read('config');
  if (parsed.rest.length > 1 || (config != null && parsed.rest.isNotEmpty)) {
    throw const FormatException('Use only one pubspec path.');
  }
  return InitArguments(
    pubspecPath: config ?? parsed.rest.firstOrNull ?? 'pubspec.yaml',
    showHelp: parsed['help'] as bool,
    generate: parsed['generate'] as bool,
    inputDir: read('input-dir'),
    outputFont: read('output-font'),
    outputClass: read('output-class'),
    className: read('class-name'),
    setName: read('set'),
  );
}

ArgParser buildInitParser() => ArgParser(allowTrailingOptions: true)
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show setup help.')
  ..addOption('config', valueHelp: 'path', help: 'Pubspec to update.')
  ..addOption(
    'set',
    valueHelp: 'name',
    help: 'Add or update one named icon set.',
  )
  ..addOption(
    'input-dir',
    valueHelp: 'path',
    help: 'SVG/PNG source folder. Default: assets/icons.',
  )
  ..addOption(
    'output-font',
    valueHelp: 'path',
    help: 'Font destination (.otf or .ttf). Default: assets/fonts/icons.otf.',
  )
  ..addOption(
    'output-class',
    valueHelp: 'path',
    help: 'Dart API destination. Default: lib/app_icons.dart.',
  )
  ..addOption(
    'class-name',
    valueHelp: 'name',
    help: 'Dart class and Flutter font family. Default: AppIcons.',
  )
  ..addFlag(
    'generate',
    defaultsTo: true,
    help: 'Generate immediately when source icons exist.',
  );
