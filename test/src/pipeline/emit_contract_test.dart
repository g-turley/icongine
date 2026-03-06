import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  test('StubIconEmitter mirrors configured output paths and symbol count', () {
    final emitter = StubIconEmitter();

    final result = emitter.emit(
      config: GenerationConfig(
        packageName: 'sample',
        inputDir: 'assets/icons',
        outFontFile: 'assets/fonts/icons.otf',
        outClassFile: 'lib/icons.dart',
      ),
      symbols: const [
        IconSymbol(
          file: IconFile(absolutePath: '/tmp/a.svg', relativePath: 'a.svg'),
          name: 'a',
        ),
        IconSymbol(
          file: IconFile(absolutePath: '/tmp/b.svg', relativePath: 'b.svg'),
          name: 'b',
        ),
      ],
      compileResult: IconCompileResult(
        fontBytes: Uint8List(0),
        fontFamily: 'sample',
        compiledSymbolCount: 2,
        glyphs: const [],
      ),
    );

    expect(result.fontOutputPath, 'assets/fonts/icons.otf');
    expect(result.classOutputPath, 'lib/icons.dart');
    expect(result.emittedSymbolCount, 2);
  });
}
