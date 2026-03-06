import 'dart:io';

import '../../domain/config.dart';
import '../../domain/icon_symbol.dart';
import 'compile.dart';
import 'flutter_icon_class_generator.dart';

/// Summary of files written by the emit step.
class IconEmitResult {
  const IconEmitResult({
    required this.fontOutputPath,
    required this.classOutputPath,
    required this.emittedSymbolCount,
  });

  /// Output path for the generated font file, if one was written.
  final String? fontOutputPath;

  /// Output path for the generated Dart icon class.
  final String classOutputPath;

  /// Number of symbols emitted into the output artifacts.
  final int emittedSymbolCount;
}

/// Persists compile output into files or other targets.
abstract interface class IconEmitter {
  /// Emits [compileResult] for [symbols] using [config].
  IconEmitResult emit({
    required GenerationConfig config,
    required List<IconSymbol> symbols,
    required IconCompileResult compileResult,
  });
}

/// Lightweight emitter used by tests when file output is unnecessary.
class StubIconEmitter implements IconEmitter {
  const StubIconEmitter();

  @override
  IconEmitResult emit({
    required GenerationConfig config,
    required List<IconSymbol> symbols,
    required IconCompileResult compileResult,
  }) {
    return IconEmitResult(
      fontOutputPath: config.outFontFile,
      classOutputPath: config.outClassFile,
      emittedSymbolCount: symbols.length,
    );
  }
}

/// File-based emitter that writes the font file and generated icon class.
class FileIconEmitter implements IconEmitter {
  const FileIconEmitter({
    this.classGenerator = const FlutterIconClassGenerator(),
  });

  /// Code generator used for the Dart icon class output.
  final FlutterIconClassGenerator classGenerator;

  @override
  IconEmitResult emit({
    required GenerationConfig config,
    required List<IconSymbol> symbols,
    required IconCompileResult compileResult,
  }) {
    _writeBytes(config.outFontFile!, compileResult.fontBytes);

    final generatedClassFileContent = classGenerator.generate(
      className: config.normalizedClassName,
      fontFamily: compileResult.fontFamily,
      fontPackage: config.fontPackage,
      outFontFile: config.outFontFile!,
      glyphs: compileResult.glyphs,
      staticIconProvider: config.staticIconProvider,
      generateIconMap: config.generateIconMap,
    );
    _writeText(config.outClassFile, generatedClassFileContent);

    return IconEmitResult(
      fontOutputPath: config.outFontFile,
      classOutputPath: config.outClassFile,
      emittedSymbolCount: symbols.length,
    );
  }

  void _writeBytes(String outputPath, List<int> bytes) {
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  }

  void _writeText(String outputPath, String content) {
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }
}
