import '../domain/config.dart';
import '../domain/naming.dart';
import '../domain/naming_diagnostics.dart';
import 'contracts/compile.dart';
import 'contracts/emit.dart';
import 'errors.dart';
import 'generation_orchestrator.dart';
import 'icon_scan.dart';
import 'pipeline.dart';
import 'step.dart';
import 'state.dart';

class GenerationPipelineBuilder {
  GenerationPipelineBuilder()
    : _steps = [const DiscoverStep(), const CompileStep(), const EmitStep()];

  final List<GenerationStep> _steps;

  GenerationPipelineRunner build() =>
      GenerationPipelineRunner(pipeline: GenerationPipeline(_steps));
}

class DiscoverStep implements GenerationStep {
  const DiscoverStep({
    this.scan = const FileIconScan(),
    this.symbolResolver = const SymbolResolver(),
  });

  final IconScan scan;
  final SymbolResolver symbolResolver;

  @override
  String get id => 'discover';

  @override
  Future<void> run(GenerationConfig config, GenerationState state) async {
    final files = scan.listSvgFiles(
      inputDir: config.inputDir,
      includeSubdirs: config.includeSubdirs,
    );

    if (files.isEmpty) {
      throw NoIconsFoundError(config.inputDir);
    }

    final resolution = symbolResolver.resolveWithDiagnostics(
      files: files,
      prefixWithSubdir: config.prefixWithSubdir,
      additionalReserved: config.generateIconMap ? const {'all'} : const {},
    );
    final errors = resolution.issues
        .where((issue) => issue.severity == NamingIssueSeverity.error)
        .map((issue) => issue.message)
        .toList(growable: false);
    if (errors.isNotEmpty) {
      throw NamingDiagnosticsError(errors);
    }
    state.namingWarnings = resolution.issues
        .where((issue) => issue.severity == NamingIssueSeverity.warning)
        .map((issue) => issue.message)
        .toList(growable: false);

    state.discoveredFiles = files;
    state.resolvedSymbols = resolution.symbols;
  }
}

class CompileStep implements GenerationStep {
  const CompileStep({this.compiler = const SvgFontCompiler()});

  final IconCompiler compiler;

  @override
  String get id => 'compile';

  @override
  Future<void> run(GenerationConfig config, GenerationState state) async {
    if (state.resolvedSymbols.isEmpty) {
      throw NoSymbolsToCompileError();
    }

    state.compileResult = compiler.compile(
      config: config,
      symbols: state.resolvedSymbols,
    );
  }
}

class EmitStep implements GenerationStep {
  const EmitStep({this.emitter = const FileIconEmitter()});

  final IconEmitter emitter;

  @override
  String get id => 'emit';

  @override
  Future<void> run(GenerationConfig config, GenerationState state) async {
    final compileResult = state.compileResult;
    if (compileResult == null) {
      throw NoCompileResultToEmitError();
    }

    state.emitResult = emitter.emit(
      config: config,
      symbols: state.resolvedSymbols,
      compileResult: compileResult,
    );
  }
}
