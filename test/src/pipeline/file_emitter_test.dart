import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';
import 'package:path/path.dart' as path;

void main() {
  group('FileIconEmitter', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('icongine_emit_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes font bytes and font icon class when format is ttf/otf', () {
      const emitter = FileIconEmitter();

      final config = GenerationConfig(
        packageName: 'sample',
        inputDir: path.join(tempDir.path, 'icons'),
        outFontFile: path.join(tempDir.path, 'out', 'icons.otf'),
        outClassFile: path.join(tempDir.path, 'out', 'icons.dart'),
      );

      final result = emitter.emit(
        config: config,
        symbols: const [
          IconSymbol(
            file: IconFile(
              absolutePath: '/tmp/home.svg',
              relativePath: 'home.svg',
            ),
            name: 'home',
          ),
        ],
        compileResult: IconCompileResult(
          fontBytes: Uint8List.fromList([1, 2, 3]),
          fontFamily: 'sample',
          compiledSymbolCount: 1,
          glyphs: const [
            FontGlyph(
              name: 'home',
              codePoint: 0xe001,
              sourceSvgDocument:
                  '<svg viewBox="0 0 24 24"><path d="M0 0"/></svg>',
            ),
          ],
        ),
      );

      final fontFile = File(config.outFontFile!);
      final classFile = File(config.outClassFile);

      expect(fontFile.existsSync(), isTrue);
      expect(classFile.readAsStringSync(), contains('class AppIcons'));
      expect(
        classFile.readAsStringSync(),
        contains('// ignore_for_file: unintended_html_in_doc_comment'),
      );
      expect(
        classFile.readAsStringSync(),
        contains('static const String? fontPackage = null;'),
      );
      expect(
        classFile.readAsStringSync(),
        contains('static const IconData home'),
      );
      expect(
        classFile.readAsStringSync(),
        contains('fontPackage: fontPackage'),
      );
      expect(classFile.readAsStringSync(), contains('@staticIconProvider'));
      expect(
        classFile.readAsStringSync(),
        isNot(contains('static const Map<String, IconData> all =')),
      );
      expect(
        classFile.readAsStringSync(),
        contains(
          'data:image/svg+xml;base64,PHN2ZyB2aWV3Qm94PSIwIDAgMjQgMjQiPjxwYXRoIGQ9Ik0wIDAiLz48L3N2Zz4=',
        ),
      );
      expect(
        classFile.readAsStringSync(),
        contains('<image width="24" src="data:image/svg+xml;base64,'),
      );
      expect(result.emittedSymbolCount, 1);
      expect(result.fontOutputPath, config.outFontFile);
      expect(result.classOutputPath, config.outClassFile);
    });

    test('emits null font package for app-local fonts by default', () {
      const emitter = FileIconEmitter();

      final config = GenerationConfig(
        packageName: 'sample',
        inputDir: path.join(tempDir.path, 'icons'),
        outFontFile: path.join(tempDir.path, 'out', 'icons.otf'),
        outClassFile: path.join(tempDir.path, 'out', 'icons.dart'),
      );

      emitter.emit(
        config: config,
        symbols: const [
          IconSymbol(
            file: IconFile(
              absolutePath: '/tmp/home.svg',
              relativePath: 'home.svg',
            ),
            name: 'home',
          ),
        ],
        compileResult: IconCompileResult(
          fontBytes: Uint8List.fromList([1, 2, 3]),
          fontFamily: 'sample',
          compiledSymbolCount: 1,
          glyphs: const [FontGlyph(name: 'home', codePoint: 0xe001)],
        ),
      );

      final classFile = File(config.outClassFile);
      expect(
        classFile.readAsStringSync(),
        contains('static const String? fontPackage = null;'),
      );
    });

    test('uses configured font package for package-distributed fonts', () {
      const emitter = FileIconEmitter();

      final config = GenerationConfig(
        packageName: 'sample',
        inputDir: path.join(tempDir.path, 'icons'),
        outFontFile: path.join(tempDir.path, 'out', 'icons.otf'),
        outClassFile: path.join(tempDir.path, 'out', 'icons.dart'),
        fontPackage: 'sample',
      );

      emitter.emit(
        config: config,
        symbols: const [
          IconSymbol(
            file: IconFile(
              absolutePath: '/tmp/home.svg',
              relativePath: 'home.svg',
            ),
            name: 'home',
          ),
        ],
        compileResult: IconCompileResult(
          fontBytes: Uint8List.fromList([1, 2, 3]),
          fontFamily: 'sample',
          compiledSymbolCount: 1,
          glyphs: const [FontGlyph(name: 'home', codePoint: 0xe001)],
        ),
      );

      final classFile = File(config.outClassFile);
      expect(
        classFile.readAsStringSync(),
        contains("static const String? fontPackage = 'sample';"),
      );
    });

    test('escapes configured strings in generated Dart source', () {
      const emitter = FileIconEmitter();
      final config = GenerationConfig(
        packageName: 'sample',
        inputDir: path.join(tempDir.path, 'icons'),
        outFontFile: path.join(tempDir.path, 'out', 'icons.otf'),
        outClassFile: path.join(tempDir.path, 'out', 'icons.dart'),
        fontPackage: r"acme'$icons",
      );

      emitter.emit(
        config: config,
        symbols: const [],
        compileResult: IconCompileResult(
          fontBytes: Uint8List(0),
          fontFamily: r"Acme's $icons",
          compiledSymbolCount: 0,
          glyphs: const [],
        ),
      );

      final source = File(config.outClassFile).readAsStringSync();
      expect(
        source,
        contains(r"static const String fontFamily = 'Acme\'s \$icons';"),
      );
      expect(
        source,
        contains(r"static const String? fontPackage = 'acme\'\$icons';"),
      );
    });

    test('uses the pubspec-relative font path in generated setup docs', () {
      const emitter = FileIconEmitter();
      final config = GenerationConfig(
        packageName: 'sample',
        inputDir: path.join(tempDir.path, 'icons'),
        outFontFile: path.join(tempDir.path, 'out', 'icons.otf'),
        fontAssetPath: path.join('assets', 'fonts', 'icons.otf'),
        outClassFile: path.join(tempDir.path, 'out', 'icons.dart'),
      );

      emitter.emit(
        config: config,
        symbols: const [],
        compileResult: IconCompileResult(
          fontBytes: Uint8List(0),
          fontFamily: 'AppIcons',
          compiledSymbolCount: 0,
          glyphs: const [],
        ),
      );

      final source = File(config.outClassFile).readAsStringSync();
      expect(source, contains('asset: assets/fonts/icons.otf'));
      expect(source, isNot(contains(tempDir.path)));
    });

    test('replaces existing artifacts without leaving staging files', () {
      const emitter = FileIconEmitter();
      final config = GenerationConfig(
        packageName: 'sample',
        inputDir: path.join(tempDir.path, 'icons'),
        outFontFile: path.join(tempDir.path, 'out', 'icons.otf'),
        outClassFile: path.join(tempDir.path, 'out', 'icons.dart'),
      );
      IconCompileResult result(List<int> bytes) => IconCompileResult(
        fontBytes: Uint8List.fromList(bytes),
        fontFamily: 'AppIcons',
        compiledSymbolCount: 0,
        glyphs: const [],
      );

      emitter.emit(
        config: config,
        symbols: const [],
        compileResult: result([1]),
      );
      emitter.emit(
        config: config,
        symbols: const [],
        compileResult: result([2, 3]),
      );

      expect(File(config.outFontFile!).readAsBytesSync(), [2, 3]);
      expect(
        Directory(path.dirname(config.outFontFile!))
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.tmp')),
        isEmpty,
      );
    });

    test('omits staticIconProvider annotation when disabled', () {
      const emitter = FileIconEmitter();

      final config = GenerationConfig(
        packageName: 'sample',
        inputDir: path.join(tempDir.path, 'icons'),
        outFontFile: path.join(tempDir.path, 'out', 'icons.otf'),
        outClassFile: path.join(tempDir.path, 'out', 'icons.dart'),
        staticIconProvider: false,
      );

      emitter.emit(
        config: config,
        symbols: const [
          IconSymbol(
            file: IconFile(
              absolutePath: '/tmp/home.svg',
              relativePath: 'home.svg',
            ),
            name: 'home',
          ),
        ],
        compileResult: IconCompileResult(
          fontBytes: Uint8List.fromList([1, 2, 3]),
          fontFamily: 'sample',
          compiledSymbolCount: 1,
          glyphs: const [FontGlyph(name: 'home', codePoint: 0xe001)],
        ),
      );

      final classFile = File(config.outClassFile);
      expect(
        classFile.readAsStringSync(),
        isNot(contains('@staticIconProvider')),
      );
    });

    test('emits all icon map only when generateIconMap is enabled', () {
      const emitter = FileIconEmitter();

      final config = GenerationConfig(
        packageName: 'sample',
        inputDir: path.join(tempDir.path, 'icons'),
        outFontFile: path.join(tempDir.path, 'out', 'icons.otf'),
        outClassFile: path.join(tempDir.path, 'out', 'icons.dart'),
        generateIconMap: true,
      );

      emitter.emit(
        config: config,
        symbols: const [
          IconSymbol(
            file: IconFile(
              absolutePath: '/tmp/home.svg',
              relativePath: 'home.svg',
            ),
            name: 'home',
          ),
        ],
        compileResult: IconCompileResult(
          fontBytes: Uint8List.fromList([1, 2, 3]),
          fontFamily: 'sample',
          compiledSymbolCount: 1,
          glyphs: const [FontGlyph(name: 'home', codePoint: 0xe001)],
        ),
      );

      final classFile = File(config.outClassFile);
      expect(
        classFile.readAsStringSync(),
        contains('static const Map<String, IconData> all ='),
      );
      expect(classFile.readAsStringSync(), contains("'home': home"));
    });
  });
}
