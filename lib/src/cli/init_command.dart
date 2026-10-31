import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import '../domain/config.dart';
import '../pipeline/icon_scan.dart';
import 'init_options.dart';
import 'init_pubspec.dart';

/// Saves app setup, then generates if requested and source icons exist.
Future<int> runInitCommand(
  List<String> args, {
  required Future<int> Function(String pubspecPath, String? setName)
  runGenerate,
  required void Function(String line) stdoutWriteln,
  required void Function(String line) stderrWriteln,
}) async {
  late InitArguments parsed;
  try {
    parsed = parseInitArguments(args);
  } on FormatException catch (error) {
    stderrWriteln('Invalid arguments: ${error.message}');
    stderrWriteln('Run `icongine init --help` for usage.');
    return 64;
  }
  if (parsed.showHelp) {
    stdoutWriteln('Usage: icongine init [options] [<pubspec_path>]');
    stdoutWriteln('');
    stdoutWriteln(buildInitParser().usage);
    stdoutWriteln('');
    stdoutWriteln(
      'Saves app defaults, registers the font, and generates icons.',
    );
    stdoutWriteln(
      'Existing configuration is kept unless explicitly overridden.',
    );
    stdoutWriteln('Paths are relative to the selected pubspec.');
    stdoutWriteln(
      'Named sets derive default paths and class names from --set.',
    );
    return 0;
  }

  try {
    final pubspec = File(parsed.pubspecPath);
    if (!pubspec.existsSync()) {
      stderrWriteln('No pubspec found at ${parsed.pubspecPath}.');
      stderrWriteln('Run init from your Flutter project or pass --config.');
      return 66;
    }
    final source = pubspec.readAsStringSync();
    final setup = InitPubspec(source, parsed);
    final directory = pubspec.absolute.parent.path;
    String resolve(String file) => path.normalize(path.join(directory, file));
    final input = resolve(setup.config.inputDir);
    if (FileSystemEntity.typeSync(input) != FileSystemEntityType.notFound &&
        !Directory(input).existsSync()) {
      throw const FormatException('The icon input path must be a directory.');
    }
    _checkOutputs(setup.config, setup.previousOutputs, resolve);
    // Check discovery permissions before writing any configuration.
    final icons = const FileIconScan().listSvgFiles(
      inputDir: input,
      includeSubdirs: setup.config.includeSubdirs,
    );
    if (pubspec.readAsStringSync() != source) {
      throw const FileSystemException(
        'Pubspec changed during init; run it again.',
      );
    }
    if (setup.contents != source) {
      _savePubspec(pubspec, setup.contents);
    }
    Directory(input).createSync(recursive: true);
    stdoutWriteln('Icon setup saved in ${parsed.pubspecPath}.');
    stdoutWriteln(
      'Flutter font: ${setup.config.fontFamily} '
      '(${setup.config.outFontFile}).',
    );
    if (parsed.generate && icons.isNotEmpty) {
      final result = await runGenerate(parsed.pubspecPath, setup.setName);
      if (result != 0) {
        stderrWriteln(
          'Setup is saved. Fix the source icons and run generation again.',
        );
      } else {
        stdoutWriteln(
          'Import ${setup.config.outClassFile} and use '
          'Icon(${setup.config.normalizedClassName}.<iconName>).',
        );
        stdoutWriteln('Run Flutter again to bundle the new font.');
      }
      return result;
    }
    if (icons.isEmpty) {
      stdoutWriteln(
        'Add SVG or transparent PNG icons to ${setup.config.inputDir}.',
      );
    }
    final configArg = parsed.pubspecPath == 'pubspec.yaml'
        ? ''
        : ' --config "${parsed.pubspecPath}"';
    final setArg = setup.setName == null ? '' : ' --set ${setup.setName}';
    stdoutWriteln('Next: dart run icongine generate$configArg$setArg');
    return 0;
  } on YamlException catch (error) {
    stderrWriteln('Invalid pubspec YAML: ${error.message}');
    return 65;
  } on FormatException catch (error) {
    stderrWriteln('Could not initialize icons: ${error.message}');
    return 65;
  } on ArgumentError catch (error) {
    stderrWriteln('Invalid icon configuration: $error');
    return 65;
  } on FileSystemException catch (error) {
    stderrWriteln(
      'Could not save icon setup: ${error.message} '
      '${error.path ?? ''}',
    );
    return 74;
  }
}

void _checkOutputs(
  GenerationConfig config,
  Set<String> previousOutputs,
  String Function(String) resolve,
) {
  if (path.extension(config.outClassFile).toLowerCase() != '.dart') {
    throw const FormatException('The Dart API destination must end in .dart.');
  }
  for (final output in [config.outFontFile!, config.outClassFile]) {
    final destination = resolve(output);
    final type = FileSystemEntity.typeSync(destination);
    if (type == FileSystemEntityType.notFound) continue;
    if (type != FileSystemEntityType.file ||
        !previousOutputs.any((old) => path.equals(destination, resolve(old)))) {
      throw FormatException(
        'Refusing to replace existing $output. '
        'Choose a different output path.',
      );
    }
  }
}

void _savePubspec(File destination, String contents) {
  final staged = File('${destination.path}.icongine.$pid.tmp');
  try {
    staged.writeAsStringSync(contents, flush: true);
    staged.renameSync(destination.path);
  } finally {
    if (staged.existsSync()) staged.deleteSync();
  }
}
