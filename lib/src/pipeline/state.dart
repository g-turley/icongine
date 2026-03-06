import '../domain/icon_file.dart';
import '../domain/icon_symbol.dart';
import 'contracts/compile.dart';
import 'contracts/emit.dart';

class GenerationState {
  List<IconFile> discoveredFiles = const [];
  List<IconSymbol> resolvedSymbols = const [];
  List<String> namingWarnings = const [];
  IconCompileResult? compileResult;
  IconEmitResult? emitResult;
}
