import 'dart:io';

import '../../domain/config.dart';
import '../../domain/icon_symbol.dart';
import 'compile.dart';
import 'flutter_icon_class_generator.dart';

class IconEmitResult {
  const IconEmitResult({
    required this.fontOutputPath,
    required this.classOutputPath,
    required this.emittedSymbolCount,
  });

  final String? fontOutputPath;
  final String classOutputPath;
  final int emittedSymbolCount;
}

abstract interface class IconEmitter {
  IconEmitResult emit({
    required GenerationConfig config,
    required List<IconSymbol> symbols,
    required IconCompileResult compileResult,
  });
}

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

class FileIconEmitter implements IconEmitter {
  const FileIconEmitter({
    this.classGenerator = const FlutterIconClassGenerator(),
  });

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
