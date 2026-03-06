import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  group('EmitStep', () {
    test('stores emit result in state', () async {
      final step = EmitStep(emitter: _FakeEmitter());
      final state = GenerationState()
        ..resolvedSymbols = const [
          IconSymbol(
            file: IconFile(
              absolutePath: '/tmp/home.svg',
              relativePath: 'home.svg',
            ),
            name: 'home',
          ),
        ]
        ..compileResult = IconCompileResult(
          fontBytes: Uint8List(0),
          fontFamily: 'sample',
          compiledSymbolCount: 1,
          glyphs: const [],
        );

      await step.run(
        GenerationConfig(
          packageName: 'sample',
          inputDir: 'assets/icons',
          outFontFile: 'assets/fonts/icons.otf',
          outClassFile: 'lib/icons.dart',
        ),
        state,
      );

      expect(state.emitResult, isNotNull);
      expect(state.emitResult!.emittedSymbolCount, 1);
      expect(state.emitResult!.fontOutputPath, 'out/font.otf');
    });

    test('throws when compile result is missing', () async {
      const step = EmitStep();

      try {
        await step.run(
          GenerationConfig(
            packageName: 'sample',
            inputDir: 'assets/icons',
            outFontFile: 'assets/fonts/icons.otf',
            outClassFile: 'lib/icons.dart',
          ),
          GenerationState(),
        );
        fail('Expected NoCompileResultToEmitError');
      } on NoCompileResultToEmitError catch (error) {
        expect(error.toString(), contains('No compile result'));
      }
    });
  });
}

class _FakeEmitter implements IconEmitter {
  @override
  IconEmitResult emit({
    required GenerationConfig config,
    required List<IconSymbol> symbols,
    required IconCompileResult compileResult,
  }) {
    return IconEmitResult(
      fontOutputPath: 'out/font.otf',
      classOutputPath: 'out/icons.dart',
      emittedSymbolCount: symbols.length,
    );
  }
}
