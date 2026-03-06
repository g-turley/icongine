import '../domain/config.dart';
import 'pipeline.dart';

/// High-level runner that executes a [GenerationPipeline] and builds a report.
class GenerationPipelineRunner {
  GenerationPipelineRunner({required GenerationPipeline pipeline})
    : _pipeline = pipeline;

  final GenerationPipeline _pipeline;

  /// Runs the pipeline and summarizes the result as a [GenerationReport].
  Future<GenerationReport> run(GenerationConfig config) async {
    final state = await _pipeline.run(config);
    return GenerationReport(
      verbose: config.verbose,
      stepIds: _pipeline.stepIds,
      discoveredIconCount: state.discoveredFiles.length,
      resolvedSymbolCount: state.resolvedSymbols.length,
      compiledSymbolCount: state.compileResult?.compiledSymbolCount ?? 0,
      emittedSymbolCount: state.emitResult?.emittedSymbolCount ?? 0,
      namingWarnings: state.namingWarnings,
      normalizationWarnings:
          state.compileResult?.normalizationWarnings ?? const [],
      normalizationModifiedGlyphNames:
          state.compileResult?.normalizationModifiedGlyphNames ?? const [],
      fontOutputPath: state.emitResult?.fontOutputPath,
      classOutputPath: state.emitResult?.classOutputPath,
    );
  }
}

/// Structured summary of a generation run.
class GenerationReport {
  const GenerationReport({
    required this.verbose,
    required this.stepIds,
    required this.discoveredIconCount,
    required this.resolvedSymbolCount,
    required this.compiledSymbolCount,
    required this.emittedSymbolCount,
    this.namingWarnings = const [],
    this.normalizationWarnings = const [],
    this.normalizationModifiedGlyphNames = const [],
    required this.fontOutputPath,
    required this.classOutputPath,
  });

  /// Whether verbose output was enabled for this run.
  final bool verbose;

  /// Ordered pipeline step identifiers that were executed.
  final List<String> stepIds;

  /// Number of SVG files discovered during scanning.
  final int discoveredIconCount;

  /// Number of symbols resolved after naming.
  final int resolvedSymbolCount;

  /// Number of symbols compiled into glyph data.
  final int compiledSymbolCount;

  /// Number of symbols emitted into output artifacts.
  final int emittedSymbolCount;

  /// Non-fatal naming warnings emitted during resolution.
  final List<String> namingWarnings;

  /// Warnings emitted while normalizing mixed-size glyphs.
  final List<String> normalizationWarnings;

  /// Glyph names whose geometry changed during normalization.
  final List<String> normalizationModifiedGlyphNames;

  /// Output path for the generated font file, if any.
  final String? fontOutputPath;

  /// Output path for the generated Dart API.
  final String? classOutputPath;
}
