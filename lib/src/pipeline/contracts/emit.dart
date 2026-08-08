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
    final generatedClassFileContent = classGenerator.generate(
      className: config.normalizedClassName,
      fontFamily: compileResult.fontFamily,
      fontPackage: config.fontPackage,
      outFontFile: config.fontAssetPath,
      glyphs: compileResult.glyphs,
      staticIconProvider: config.staticIconProvider,
      generateIconMap: config.generateIconMap,
    );
    _writeAtomically(
      config.outFontFile!,
      (file) => file.writeAsBytesSync(compileResult.fontBytes, flush: true),
    );
    _writeAtomically(
      config.outClassFile,
      (file) => file.writeAsStringSync(generatedClassFileContent, flush: true),
    );

    return IconEmitResult(
      fontOutputPath: config.outFontFile,
      classOutputPath: config.outClassFile,
      emittedSymbolCount: symbols.length,
    );
  }

  void _writeAtomically(String outputPath, void Function(File file) write) {
    final destination = File(outputPath);
    destination.parent.createSync(recursive: true);
    final staged = File(
      '$outputPath.icongine.$pid.${_nextTemporaryFileId++}.tmp',
    );
    try {
      write(staged);
      staged.renameSync(destination.path);
    } finally {
      if (staged.existsSync()) {
        staged.deleteSync();
      }
    }
  }

  static int _nextTemporaryFileId = 0;
}
