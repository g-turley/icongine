import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import '../../icongine.dart';

/// CLI or programmatic overrides applied on top of pubspec configuration.
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

  /// Whether no override values were provided.
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

  /// Returns a new config with override values applied to [baseConfig].
  GenerationConfig applyTo(GenerationConfig baseConfig) {
    return GenerationConfig(
      packageName: baseConfig.packageName,
      inputDir: inputDir ?? baseConfig.inputDir,
      outFontFile: outFontFile ?? baseConfig.outFontFile,
      outClassFile: outClassFile ?? baseConfig.outClassFile,
      className: className ?? baseConfig.className,
      fontPackage: baseConfig.fontPackage,
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

/// Abstraction for running icon generation from a resolved config.
abstract interface class GenerationRunner {
  Future<GenerationReport> run(GenerationConfig config);
}

/// Production runner that executes the default generation pipeline.
class PipelineGenerationRunner implements GenerationRunner {
  const PipelineGenerationRunner();

  @override
  Future<GenerationReport> run(GenerationConfig config) {
    return GenerationPipelineBuilder().build().run(config);
  }
}

/// Command entry point for loading configuration and invoking generation.
class GenerateIconsCommand {
  const GenerateIconsCommand({
    this.configParser = const GenerationConfigParser(),
    this.runner = const PipelineGenerationRunner(),
  });

  final GenerationConfigParser configParser;
  final GenerationRunner runner;

  /// Resolves configuration from [pubspecPath] and optional [overrides].
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
    final resolvedConfig = overrides.applyTo(parsedConfig);
    final pubspecDirectory = pubspecFile.parent.path;
    return GenerationConfig(
      packageName: resolvedConfig.packageName,
      inputDir: _resolvePathFromConfigDirectory(
        configuredPath: resolvedConfig.inputDir,
        configDirectory: pubspecDirectory,
      ),
      outFontFile: resolvedConfig.outFontFile == null
          ? null
          : _resolvePathFromConfigDirectory(
              configuredPath: resolvedConfig.outFontFile!,
              configDirectory: pubspecDirectory,
            ),
      outClassFile: _resolvePathFromConfigDirectory(
        configuredPath: resolvedConfig.outClassFile,
        configDirectory: pubspecDirectory,
      ),
      className: resolvedConfig.className,
      fontPackage: resolvedConfig.fontPackage,
      includeSubdirs: resolvedConfig.includeSubdirs,
      prefixWithSubdir: resolvedConfig.prefixWithSubdir,
      fontFormat: resolvedConfig.fontFormat,
      glyphEmissionMode: resolvedConfig.glyphEmissionMode,
      normalize: resolvedConfig.normalize,
      verbose: resolvedConfig.verbose,
      staticIconProvider: resolvedConfig.staticIconProvider,
      generateIconMap: resolvedConfig.generateIconMap,
    );
  }

  /// Runs icon generation using the resolved configuration.
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

  String _resolvePathFromConfigDirectory({
    required String configuredPath,
    required String configDirectory,
  }) {
    if (configuredPath.trim().isEmpty || path.isAbsolute(configuredPath)) {
      return configuredPath;
    }
    return path.normalize(path.join(configDirectory, configuredPath));
  }
}
