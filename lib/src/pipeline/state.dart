import '../domain/icon_file.dart';
import '../domain/icon_symbol.dart';
import 'contracts/compile.dart';
import 'contracts/emit.dart';

/// Mutable state passed between pipeline steps.
class GenerationState {
  /// SVG files discovered during the scan step.
  List<IconFile> discoveredFiles = const [];

  /// Symbols resolved from the discovered SVG files.
  List<IconSymbol> resolvedSymbols = const [];

  /// Non-fatal naming warnings collected during resolution.
  List<String> namingWarnings = const [];

  /// Compile output produced by the compile step.
  IconCompileResult? compileResult;

  /// Emit output produced by the emit step.
  IconEmitResult? emitResult;
}
