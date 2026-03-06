import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

import '../../src/font/cff_test_support.dart';

void main() {
  group('End-to-end circle SVG to OTF', () {
    late Directory tempDirectory;
    late String svgFilePath;

    /// Minimal circle SVG matching the geometry of circle-filled.svg.
    const circleSvgContent =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">'
        '<path d="M47,256c0,-115.35 93.65,-209 209,-209c115.35,0 '
        '209,93.65 209,209c0,115.35 -93.65,209 -209,209c-115.35,0 '
        '-209,-93.65 -209,-209Z" style="fill:#ebebeb;stroke:#000;'
        'stroke-width:30px;"/></svg>';

    setUp(() {
      tempDirectory = Directory.systemTemp.createTempSync('icongine_e2e_');
      final svgFile = File('${tempDirectory.path}/circle-filled.svg');
      svgFile.writeAsStringSync(circleSvgContent);
      svgFilePath = svgFile.path;
    });

    tearDown(() {
      tempDirectory.deleteSync(recursive: true);
    });

    test('produces valid OTF from circle-filled SVG', () {
      final config = GenerationConfig(
        packageName: 'test_icons',
        inputDir: tempDirectory.path,
        outClassFile: '${tempDirectory.path}/icons.dart',
        outFontFile: '${tempDirectory.path}/icons.otf',
        fontFormat: FontFormat.otf,
      );

      final compiler = const SvgFontCompiler();
      final symbols = [
        IconSymbol(
          file: IconFile(
            absolutePath: svgFilePath,
            relativePath: 'circle-filled.svg',
          ),
          name: 'circleFilled',
        ),
      ];

      final result = compiler.compile(config: config, symbols: symbols);

      // Font bytes should be non-empty.
      expect(result.fontBytes.isNotEmpty, isTrue);
      expect(result.compiledSymbolCount, 1);
      expect(result.fontFamily, 'AppIcons');
      expect(result.glyphs, hasLength(1));
    });

    test('SFNT header has OTTO scaler type and 9 tables', () {
      final config = GenerationConfig(
        packageName: 'test_icons',
        inputDir: tempDirectory.path,
        outClassFile: '${tempDirectory.path}/icons.dart',
        outFontFile: '${tempDirectory.path}/icons.otf',
        fontFormat: FontFormat.otf,
      );

      final result = const SvgFontCompiler().compile(
        config: config,
        symbols: [
          IconSymbol(
            file: IconFile(
              absolutePath: svgFilePath,
              relativePath: 'circle-filled.svg',
            ),
            name: 'circleFilled',
          ),
        ],
      );

      final data = ByteData.sublistView(result.fontBytes);
      expect(data.getUint32(0), OtfWriter.ottoScalerType);
      expect(data.getUint16(4), 9);
    });

    test('CFF charstrings contain cubic operators for circle contour', () {
      final config = GenerationConfig(
        packageName: 'test_icons',
        inputDir: tempDirectory.path,
        outClassFile: '${tempDirectory.path}/icons.dart',
        outFontFile: '${tempDirectory.path}/icons.otf',
        fontFormat: FontFormat.otf,
      );

      final result = const SvgFontCompiler().compile(
        config: config,
        symbols: [
          IconSymbol(
            file: IconFile(
              absolutePath: svgFilePath,
              relativePath: 'circle-filled.svg',
            ),
            name: 'circleFilled',
          ),
        ],
      );

      final cffTable = readCffTable(result.fontBytes);
      final nameIndex = readCffIndex(cffTable, 4);
      final topDictIndex = readCffIndex(cffTable, nameIndex.nextOffset);
      final charStringsOffset = readCffInt32BeforeOperator(
        topDictIndex.objects.first,
        17,
      );
      final charStringsIndex = readCffIndex(cffTable, charStringsOffset);

      // 2 charstrings: .notdef + circleFilled
      expect(charStringsIndex.objects, hasLength(2));

      // The circle glyph charstring should contain rrcurveto operators.
      final circleCharString = charStringsIndex.objects[1];
      expect(
        circleCharString.contains(Type2CharstringEncoder.operatorRrcurveto),
        isTrue,
      );

      // It should end with endchar.
      expect(circleCharString.last, Type2CharstringEncoder.operatorEndchar);
    });

    test('glyph has populated contour paths', () {
      final config = GenerationConfig(
        packageName: 'test_icons',
        inputDir: tempDirectory.path,
        outClassFile: '${tempDirectory.path}/icons.dart',
        outFontFile: '${tempDirectory.path}/icons.otf',
        fontFormat: FontFormat.otf,
      );

      final result = const SvgFontCompiler().compile(
        config: config,
        symbols: [
          IconSymbol(
            file: IconFile(
              absolutePath: svgFilePath,
              relativePath: 'circle-filled.svg',
            ),
            name: 'circleFilled',
          ),
        ],
      );

      final glyph = result.glyphs.first;
      expect(glyph.name, 'circleFilled');
      expect(glyph.codePoint, 0xe001);

      // Source contour: 1 closed contour with 4 cubic segments.
      expect(glyph.sourceContourPath, isNotNull);
      expect(glyph.sourceContourPath!.contours, hasLength(1));
      expect(glyph.sourceContourPath!.contours.first.isClosed, isTrue);
      expect(glyph.sourceContourPath!.contours.first.segments, hasLength(4));

      // Compiled contour: same structure, transformed to font coordinates.
      expect(glyph.compiledContourPath, isNotNull);
      expect(glyph.compiledContourPath!.contours, hasLength(1));
      expect(glyph.compiledContourPath!.contours.first.isClosed, isTrue);
      expect(glyph.compiledContourPath!.contours.first.segments, hasLength(4));
    });

    test('ttf format emits TrueType outlines with glyf and loca tables', () {
      final config = GenerationConfig(
        packageName: 'test_icons',
        inputDir: tempDirectory.path,
        outClassFile: '${tempDirectory.path}/icons.dart',
        outFontFile: '${tempDirectory.path}/icons.ttf',
        fontFormat: FontFormat.ttf,
      );

      final result = const SvgFontCompiler().compile(
        config: config,
        symbols: [
          IconSymbol(
            file: IconFile(
              absolutePath: svgFilePath,
              relativePath: 'circle-filled.svg',
            ),
            name: 'circleFilled',
          ),
        ],
      );

      final data = ByteData.sublistView(result.fontBytes);
      expect(data.getUint32(0), 0x00010000);

      final tableTags = _extractTableTags(result.fontBytes);
      expect(tableTags, contains('glyf'));
      expect(tableTags, contains('loca'));
      expect(tableTags, isNot(contains('CFF ')));
    });
  });
}

List<String> _extractTableTags(Uint8List otfBytes) {
  final data = ByteData.sublistView(otfBytes);
  final numTables = data.getUint16(4);
  final tags = <String>[];
  for (var index = 0; index < numTables; index += 1) {
    final recordOffset = 12 + index * 16;
    tags.add(
      String.fromCharCodes(otfBytes.sublist(recordOffset, recordOffset + 4)),
    );
  }
  return tags;
}
