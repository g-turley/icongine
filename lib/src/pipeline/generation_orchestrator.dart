import '../domain/config.dart';
import 'pipeline.dart';

class GenerationPipelineRunner {
  GenerationPipelineRunner({required GenerationPipeline pipeline})
    : _pipeline = pipeline;

  final GenerationPipeline _pipeline;

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

  final bool verbose;
  final List<String> stepIds;
  final int discoveredIconCount;
  final int resolvedSymbolCount;
  final int compiledSymbolCount;
  final int emittedSymbolCount;
  final List<String> namingWarnings;
  final List<String> normalizationWarnings;
  final List<String> normalizationModifiedGlyphNames;
  final String? fontOutputPath;
  final String? classOutputPath;
}
