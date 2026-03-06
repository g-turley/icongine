import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

import 'cff_test_support.dart';

void main() {
  group('OtfWriter', () {
    late OtfWriter writer;
    late List<FontGlyph> singleCircleGlyph;

    setUp(() {
      writer = const OtfWriter();

      // A circle glyph with pre-transformed contour data.
      final compiledContour = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.cubic(
                start: const SvgPoint(94, 512),
                control1: const SvgPoint(94, 743),
                control2: const SvgPoint(281, 930),
                end: const SvgPoint(512, 930),
              ),
              SvgContourSegment.cubic(
                start: const SvgPoint(512, 930),
                control1: const SvgPoint(743, 930),
                control2: const SvgPoint(930, 743),
                end: const SvgPoint(930, 512),
              ),
              SvgContourSegment.cubic(
                start: const SvgPoint(930, 512),
                control1: const SvgPoint(930, 281),
                control2: const SvgPoint(743, 94),
                end: const SvgPoint(512, 94),
              ),
              SvgContourSegment.cubic(
                start: const SvgPoint(512, 94),
                control1: const SvgPoint(281, 94),
                control2: const SvgPoint(94, 281),
                end: const SvgPoint(94, 512),
              ),
            ],
            isClosed: true,
          ),
        ],
      );

      singleCircleGlyph = [
        FontGlyph(
          name: 'circleFilled',
          codePoint: 0xe001,
          glyphId: 1,
          sourceWidth: 512,
          sourceHeight: 512,
          compiledContourPath: compiledContour,
        ),
      ];
    });

    test('produces non-empty font bytes', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleCircleGlyph,
      );

      expect(bytes.isNotEmpty, isTrue);
    });

    test('writes OTTO scaler type in SFNT header', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleCircleGlyph,
      );

      final data = ByteData.sublistView(bytes);
      expect(data.getUint32(0), OtfWriter.ottoScalerType);
    });

    test('includes all 9 required SFNT tables', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleCircleGlyph,
      );

      final tags = _extractTableTags(bytes);
      expect(
        tags,
        containsAll([
          'CFF ',
          'OS/2',
          'cmap',
          'head',
          'hhea',
          'hmtx',
          'maxp',
          'name',
          'post',
        ]),
      );
    });

    test('reports correct number of tables in SFNT header', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleCircleGlyph,
      );

      final data = ByteData.sublistView(bytes);
      expect(data.getUint16(4), 9);
    });

    test('CFF table is parseable', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleCircleGlyph,
      );

      final cffTable = readCffTable(bytes);
      expect(cffTable.isNotEmpty, isTrue);

      // CFF header: major=1, minor=0
      expect(cffTable[0], 1);
      expect(cffTable[1], 0);
    });

    test('CFF contains charstring data for .notdef plus one glyph', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleCircleGlyph,
      );

      final cffTable = readCffTable(bytes);

      // Walk to charStrings INDEX via Top DICT offset.
      // Skip header (4 bytes) + Name INDEX + Top DICT INDEX + String INDEX
      // + Global Subr INDEX + charset to reach charstrings.
      final nameIndex = readCffIndex(cffTable, 4);
      final topDictIndex = readCffIndex(cffTable, nameIndex.nextOffset);
      final charStringsOffset = readCffInt32BeforeOperator(
        topDictIndex.objects.first,
        17, // CharStrings operator
      );
      final charStringsIndex = readCffIndex(cffTable, charStringsOffset);

      // Should have 2 charstrings: .notdef + circleFilled.
      expect(charStringsIndex.objects, hasLength(2));
    });

    test('maxp table reports correct glyph count', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleCircleGlyph,
      );

      final maxpData = _extractTableData(bytes, 'maxp');
      final maxpView = ByteData.sublistView(maxpData);
      final numberOfGlyphs = maxpView.getUint16(4);

      // .notdef + 1 glyph = 2
      expect(numberOfGlyphs, 2);
    });

    test('hmtx table has correct number of metric entries', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleCircleGlyph,
      );

      final hmtxData = _extractTableData(bytes, 'hmtx');

      // Each longHorMetric is 4 bytes. 2 glyphs = 8 bytes.
      expect(hmtxData.length, 8);
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

Uint8List _extractTableData(Uint8List otfBytes, String targetTag) {
  final data = ByteData.sublistView(otfBytes);
  final numTables = data.getUint16(4);
  for (var index = 0; index < numTables; index += 1) {
    final recordOffset = 12 + index * 16;
    final tag = String.fromCharCodes(
      otfBytes.sublist(recordOffset, recordOffset + 4),
    );
    if (tag == targetTag) {
      final offset = data.getUint32(recordOffset + 8);
      final length = data.getUint32(recordOffset + 12);
      return otfBytes.sublist(offset, offset + length);
    }
  }
  throw StateError('Table $targetTag not found');
}
