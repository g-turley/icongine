import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  group('CompileStep', () {
    test('stores compile result in state', () async {
      final step = CompileStep(compiler: _FakeCompiler());
      final state = GenerationState()
        ..resolvedSymbols = const [
          IconSymbol(
            file: IconFile(
              absolutePath: '/tmp/home.svg',
              relativePath: 'home.svg',
            ),
            name: 'home',
          ),
        ];

      await step.run(
        GenerationConfig(
          packageName: 'sample',
          inputDir: 'assets/icons',
          outFontFile: 'assets/fonts/icons.otf',
          outClassFile: 'lib/icons.dart',
        ),
        state,
      );

      expect(state.compileResult, isNotNull);
      expect(state.compileResult!.compiledSymbolCount, 1);
      expect(state.compileResult!.fontFamily, 'sample_family');
    });

    test('throws when resolvedSymbols is empty', () async {
      const step = CompileStep();

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
        fail('Expected NoSymbolsToCompileError');
      } on NoSymbolsToCompileError catch (error) {
        expect(error.toString(), contains('No resolved symbols'));
      }
    });
  });
}

class _FakeCompiler implements IconCompiler {
  @override
  IconCompileResult compile({
    required GenerationConfig config,
    required List<IconSymbol> symbols,
  }) {
    return IconCompileResult(
      fontBytes: Uint8List.fromList([1, 2, 3]),
      fontFamily: '${config.packageName}_family',
      compiledSymbolCount: symbols.length,
      glyphs: const [],
    );
  }
}
