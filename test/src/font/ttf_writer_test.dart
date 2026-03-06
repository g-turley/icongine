import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  group('TtfWriter', () {
    late TtfWriter writer;
    late List<FontGlyph> singleRectGlyph;

    setUp(() {
      writer = const TtfWriter();
      final compiledContour = SvgContourPath(
        contours: [
          SvgContour(
            segments: [
              SvgContourSegment.line(
                start: const SvgPoint(128, 128),
                end: const SvgPoint(896, 128),
              ),
              SvgContourSegment.line(
                start: const SvgPoint(896, 128),
                end: const SvgPoint(896, 896),
              ),
              SvgContourSegment.line(
                start: const SvgPoint(896, 896),
                end: const SvgPoint(128, 896),
              ),
              SvgContourSegment.line(
                start: const SvgPoint(128, 896),
                end: const SvgPoint(128, 128),
              ),
            ],
            isClosed: true,
          ),
        ],
      );

      singleRectGlyph = [
        FontGlyph(
          name: 'rectFilled',
          codePoint: 0xe001,
          glyphId: 1,
          sourceWidth: 1024,
          sourceHeight: 1024,
          compiledContourPath: compiledContour,
        ),
      ];
    });

    test('produces non-empty font bytes', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleRectGlyph,
      );

      expect(bytes.isNotEmpty, isTrue);
    });

    test('writes TrueType scaler type in SFNT header', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleRectGlyph,
      );

      final data = ByteData.sublistView(bytes);
      expect(data.getUint32(0), 0x00010000);
    });

    test('includes required TrueType SFNT tables', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleRectGlyph,
      );

      final tags = _extractTableTags(bytes);
      expect(
        tags,
        containsAll([
          'OS/2',
          'cmap',
          'glyf',
          'head',
          'hhea',
          'hmtx',
          'loca',
          'maxp',
          'name',
          'post',
        ]),
      );
      expect(tags, isNot(contains('CFF ')));
    });

    test('head table uses long loca format', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleRectGlyph,
      );

      final headData = _extractTableData(bytes, 'head');
      final headView = ByteData.sublistView(headData);
      expect(headView.getInt16(50), 1);
    });

    test('maxp reports TrueType version and glyph count', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleRectGlyph,
      );

      final maxpData = _extractTableData(bytes, 'maxp');
      final maxpView = ByteData.sublistView(maxpData);
      expect(maxpView.getUint32(0), 0x00010000);
      // .notdef + 1 glyph
      expect(maxpView.getUint16(4), 2);
    });

    test('loca offsets map .notdef and glyph entries into glyf table', () {
      final bytes = writer.write(
        familyName: 'TestIcons',
        glyphs: singleRectGlyph,
      );

      final locaData = _extractTableData(bytes, 'loca');
      final glyfData = _extractTableData(bytes, 'glyf');
      final locaView = ByteData.sublistView(locaData);

      // numGlyphs=2 => loca has 3 offsets.
      final offset0 = locaView.getUint32(0);
      final offset1 = locaView.getUint32(4);
      final offset2 = locaView.getUint32(8);

      expect(offset0, 0);
      expect(offset1, greaterThan(offset0));
      expect(offset2, greaterThan(offset1));
      expect(offset2, lessThanOrEqualTo(glyfData.length));

      final notdefContours = ByteData.sublistView(glyfData).getInt16(offset0);
      final glyphContours = ByteData.sublistView(glyfData).getInt16(offset1);
      expect(notdefContours, 0);
      expect(glyphContours, greaterThan(0));
    });
  });
}

List<String> _extractTableTags(Uint8List sfntBytes) {
  final data = ByteData.sublistView(sfntBytes);
  final numTables = data.getUint16(4);
  final tags = <String>[];
  for (var index = 0; index < numTables; index += 1) {
    final recordOffset = 12 + index * 16;
    tags.add(
      String.fromCharCodes(sfntBytes.sublist(recordOffset, recordOffset + 4)),
    );
  }
  return tags;
}

Uint8List _extractTableData(Uint8List sfntBytes, String tag) {
  final data = ByteData.sublistView(sfntBytes);
  final numTables = data.getUint16(4);

  for (var index = 0; index < numTables; index += 1) {
    final recordOffset = 12 + index * 16;
    final tableTag = String.fromCharCodes(
      sfntBytes.sublist(recordOffset, recordOffset + 4),
    );
    if (tableTag != tag) {
      continue;
    }

    final tableOffset = data.getUint32(recordOffset + 8);
    final tableLength = data.getUint32(recordOffset + 12);
    return sfntBytes.sublist(tableOffset, tableOffset + tableLength);
  }

  throw StateError('Table $tag not found');
}
