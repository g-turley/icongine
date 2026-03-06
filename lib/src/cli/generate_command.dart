import 'dart:io';

import 'package:yaml/yaml.dart';

import '../../icongine.dart';

class GenerateConfigOverrides {
  const GenerateConfigOverrides({
    this.inputDir,
    this.outFontFile,
    this.outClassFile,
    this.className,
    this.includeSubdirs,
    this.prefixWithSubdir,
    this.fontFormat,
    this.normalize,
    this.verbose,
    this.staticIconProvider,
    this.generateIconMap,
  });

  final String? inputDir;
  final String? outFontFile;
  final String? outClassFile;
  final String? className;
  final bool? includeSubdirs;
  final bool? prefixWithSubdir;
  final FontFormat? fontFormat;
  final bool? normalize;
  final bool? verbose;
  final bool? staticIconProvider;
  final bool? generateIconMap;

  bool get isEmpty =>
      inputDir == null &&
      outFontFile == null &&
      outClassFile == null &&
      className == null &&
      includeSubdirs == null &&
      prefixWithSubdir == null &&
      fontFormat == null &&
      normalize == null &&
      verbose == null &&
      staticIconProvider == null &&
      generateIconMap == null;

  GenerationConfig applyTo(GenerationConfig baseConfig) {
    return GenerationConfig(
      packageName: baseConfig.packageName,
      inputDir: inputDir ?? baseConfig.inputDir,
      outFontFile: outFontFile ?? baseConfig.outFontFile,
      outClassFile: outClassFile ?? baseConfig.outClassFile,
      className: className ?? baseConfig.className,
      includeSubdirs: includeSubdirs ?? baseConfig.includeSubdirs,
      prefixWithSubdir: prefixWithSubdir ?? baseConfig.prefixWithSubdir,
      fontFormat: fontFormat ?? baseConfig.fontFormat,
      glyphEmissionMode: baseConfig.glyphEmissionMode,
      normalize: normalize ?? baseConfig.normalize,
      verbose: verbose ?? baseConfig.verbose,
      staticIconProvider: staticIconProvider ?? baseConfig.staticIconProvider,
      generateIconMap: generateIconMap ?? baseConfig.generateIconMap,
    );
  }
}

abstract interface class GenerationRunner {
  Future<GenerationReport> run(GenerationConfig config);
}

class PipelineGenerationRunner implements GenerationRunner {
  const PipelineGenerationRunner();

  @override
  Future<GenerationReport> run(GenerationConfig config) {
    return GenerationPipelineBuilder().build().run(config);
  }
}

class GenerateIconsCommand {
  const GenerateIconsCommand({
    this.configParser = const GenerationConfigParser(),
    this.runner = const PipelineGenerationRunner(),
  });

  final GenerationConfigParser configParser;
  final GenerationRunner runner;

  Future<GenerationConfig> resolveConfig({
    String pubspecPath = 'pubspec.yaml',
    GenerateConfigOverrides overrides = const GenerateConfigOverrides(),
  }) async {
    final pubspecFile = File(pubspecPath);
    final raw = await pubspecFile.readAsString();
    final yamlRoot = loadYaml(raw);
    if (yamlRoot is! YamlMap) {
      throw FormatException('Expected pubspec root document to be a YAML map.');
    }

    final pubspecMap = <String, Object?>{};
    for (final entry in yamlRoot.entries) {
      pubspecMap[entry.key.toString()] = entry.value;
    }
    final parsedConfig = configParser.parsePubspec(pubspecMap);
    return overrides.applyTo(parsedConfig);
  }

  Future<GenerationReport> run({
    String pubspecPath = 'pubspec.yaml',
    GenerateConfigOverrides overrides = const GenerateConfigOverrides(),
  }) async {
    final config = await resolveConfig(
      pubspecPath: pubspecPath,
      overrides: overrides,
    );
    return runner.run(config);
  }
}
