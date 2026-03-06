import 'dart:typed_data';

import '../../sfnt.dart';

/// A single character-to-glyph mapping for the cmap table.
class CmapEntry {
  const CmapEntry({required this.codePoint, required this.glyphId});

  final int codePoint;
  final int glyphId;
}

/// Horizontal metrics for a single glyph in the hmtx table.
class HorizontalMetric {
  const HorizontalMetric({
    required this.advanceWidth,
    required this.leftSideBearing,
  });

  final int advanceWidth;
  final int leftSideBearing;
}

/// Global bounding box computed across all glyphs.
class FontBoundingBox {
  const FontBoundingBox({
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;
}

/// Builds individual SFNT tables for an OTF (CFF-based OpenType) font.
///
/// Each method constructs one table and returns it as an [SfntTable]. The
/// caller assembles all tables via [SfntWriter] with the "OTTO" scaler type.
class OtfTableBuilder {
  const OtfTableBuilder();

  /// Builds the `head` table (font header, 54 bytes).
  SfntTable buildHeadTable({
    required int unitsPerEm,
    required FontBoundingBox boundingBox,
  }) {
    final data = ByteData(54);
    data.setUint32(0, 0x00010000); // majorVersion=1, minorVersion=0
    data.setUint32(4, 0x00010000); // fontRevision 1.0 (fixed 16.16)
    data.setUint32(8, 0); // checksumAdjustment (placeholder)
    data.setUint32(12, 0x5F0F3CF5); // magicNumber
    data.setUint16(16, 0x000B); // flags
    data.setUint16(18, unitsPerEm);
    // created (Int64 at offset 20): leave as 0
    // modified (Int64 at offset 28): leave as 0
    data.setInt16(36, boundingBox.xMin);
    data.setInt16(38, boundingBox.yMin);
    data.setInt16(40, boundingBox.xMax);
    data.setInt16(42, boundingBox.yMax);
    data.setUint16(44, 0); // macStyle
    data.setUint16(46, 8); // lowestRecPPEM
    data.setInt16(48, 2); // fontDirectionHint (strongly left to right)
    data.setInt16(50, 0); // indexToLocFormat
    data.setInt16(52, 0); // glyphDataFormat
    return SfntTable(tag: 'head', data: data.buffer.asUint8List());
  }

  /// Builds the `hhea` table (horizontal header, 36 bytes).
  SfntTable buildHheaTable({
    required int unitsPerEm,
    required int advanceWidthMax,
    required int numberOfHorizontalMetrics,
  }) {
    final data = ByteData(36);
    data.setUint32(0, 0x00010000); // version 1.0
    data.setInt16(4, unitsPerEm); // ascender
    data.setInt16(6, 0); // descender
    data.setInt16(8, 0); // lineGap
    data.setUint16(10, advanceWidthMax);
    data.setInt16(12, 0); // minLeftSideBearing
    data.setInt16(14, 0); // minRightSideBearing
    data.setInt16(16, unitsPerEm); // xMaxExtent
    data.setInt16(18, 1); // caretSlopeRise
    data.setInt16(20, 0); // caretSlopeRun
    // reserved fields 22..30 are already 0
    data.setInt16(32, 0); // metricDataFormat
    data.setUint16(34, numberOfHorizontalMetrics);
    return SfntTable(tag: 'hhea', data: data.buffer.asUint8List());
  }

  /// Builds the `maxp` table (maximum profile, 6 bytes for CFF-based fonts).
  SfntTable buildMaxpTable({required int numberOfGlyphs}) {
    final data = ByteData(6);
    data.setUint32(0, 0x00005000); // version 0.5 (CFF)
    data.setUint16(4, numberOfGlyphs);
    return SfntTable(tag: 'maxp', data: data.buffer.asUint8List());
  }

  /// Builds the `OS/2` table (OS/2 and Windows metrics, 96 bytes, version 4).
  SfntTable buildOs2Table({
    required int unitsPerEm,
    required int firstCharIndex,
    required int lastCharIndex,
  }) {
    final data = ByteData(96);
    data.setUint16(0, 4); // version
    data.setInt16(2, unitsPerEm); // xAvgCharWidth
    data.setUint16(4, 400); // usWeightClass (Regular)
    data.setUint16(6, 5); // usWidthClass (Medium)
    data.setUint16(8, 0); // fsType (installable embedding)
    // ySubscriptXSize..yStrikeoutPosition (offsets 10..28) use defaults (0)
    data.setInt16(26, unitsPerEm ~/ 14); // yStrikeoutSize
    data.setInt16(28, unitsPerEm ~/ 3); // yStrikeoutPosition
    // sFamilyClass (offset 30) = 0
    // panose (offsets 32..41) = all zeros
    // ulUnicodeRange1 (offset 42)
    data.setUint32(42, 0); // ulUnicodeRange1
    data.setUint32(46, 0x00100000); // ulUnicodeRange2: bit 57-32=20 (PUA)
    data.setUint32(50, 0); // ulUnicodeRange3
    data.setUint32(54, 0); // ulUnicodeRange4
    // achVendID (offset 58, 4 bytes)
    final vendorId = 'ICFG'.codeUnits;
    for (var index = 0; index < 4; index += 1) {
      data.setUint8(58 + index, vendorId[index]);
    }
    data.setUint16(62, 0x0040); // fsSelection (Regular)
    data.setUint16(64, firstCharIndex); // usFirstCharIndex
    data.setUint16(66, lastCharIndex); // usLastCharIndex
    data.setInt16(68, unitsPerEm); // sTypoAscender
    data.setInt16(70, 0); // sTypoDescender
    data.setInt16(72, 0); // sTypoLineGap
    data.setUint16(74, unitsPerEm); // usWinAscent
    data.setUint16(76, 0); // usWinDescent
    data.setUint32(78, 0); // ulCodePageRange1
    data.setUint32(82, 0); // ulCodePageRange2
    data.setInt16(86, unitsPerEm ~/ 2); // sxHeight
    data.setInt16(88, unitsPerEm); // sCapHeight
    data.setUint16(90, 0); // usDefaultChar
    data.setUint16(92, 0x20); // usBreakChar
    data.setUint16(94, 1); // usMaxContext
    return SfntTable(tag: 'OS/2', data: data.buffer.asUint8List());
  }

  /// Builds the `name` table with the font's naming records.
  ///
  /// Uses platform 3 (Windows), encoding 1 (Unicode BMP),
  /// language 0x0409 (English US). All strings are UTF-16BE encoded.
  SfntTable buildNameTable({required String familyName}) {
    final nameRecords = <_NameRecord>[
      _NameRecord(nameId: 0, value: 'Generated by icongine'),
      _NameRecord(nameId: 1, value: familyName),
      _NameRecord(nameId: 2, value: 'Regular'),
      _NameRecord(nameId: 3, value: familyName),
      _NameRecord(nameId: 4, value: familyName),
      _NameRecord(nameId: 5, value: 'Version 1.0'),
      _NameRecord(nameId: 6, value: _sanitizePostScriptName(familyName)),
    ];

    final encodedStrings = nameRecords
        .map((record) => _encodeUtf16BigEndian(record.value))
        .toList(growable: false);

    // Header: format(2) + count(2) + storageOffset(2)
    const headerSize = 6;
    const recordSize = 12; // per record
    final storageOffset = headerSize + (recordSize * nameRecords.length);

    final builder = BytesBuilder();
    final header = ByteData(headerSize);
    header.setUint16(0, 0); // format
    header.setUint16(2, nameRecords.length);
    header.setUint16(4, storageOffset);
    builder.add(header.buffer.asUint8List());

    // Write name records, accumulating string offsets.
    var currentStringOffset = 0;
    for (var index = 0; index < nameRecords.length; index += 1) {
      final record = ByteData(recordSize);
      record.setUint16(0, 3); // platformID (Windows)
      record.setUint16(2, 1); // encodingID (Unicode BMP)
      record.setUint16(4, 0x0409); // languageID (English US)
      record.setUint16(6, nameRecords[index].nameId);
      record.setUint16(8, encodedStrings[index].length);
      record.setUint16(10, currentStringOffset);
      builder.add(record.buffer.asUint8List());
      currentStringOffset += encodedStrings[index].length;
    }

    // Write string storage.
    for (final encodedString in encodedStrings) {
      builder.add(encodedString);
    }

    return SfntTable(tag: 'name', data: builder.takeBytes());
  }

  /// Builds the `cmap` table with a format 4 subtable mapping codepoints
  /// to glyph IDs.
  SfntTable buildCmapTable({required List<CmapEntry> entries}) {
    final sortedEntries = List<CmapEntry>.from(entries)
      ..sort((left, right) => left.codePoint.compareTo(right.codePoint));

    // Build contiguous ranges from sorted entries.
    final ranges = _buildCmapRanges(sortedEntries);

    // Add sentinel segment (0xFFFF).
    final segmentCount = ranges.length + 1;
    final searchRangeValue = _highestPowerOfTwo(segmentCount) * 2;
    final entrySelectorValue = _log2Floor(_highestPowerOfTwo(segmentCount));
    final rangeShiftValue = (segmentCount * 2) - searchRangeValue;

    // Format 4 subtable.
    final subtableHeaderSize = 14; // format(2) + length(2) + language(2) +
    // segCountX2(2) + searchRange(2) + entrySelector(2) + rangeShift(2)
    final segmentArraySize = segmentCount * 2; // each of 4 arrays
    final reservedPadSize = 2;
    final subtableSize =
        subtableHeaderSize + (segmentArraySize * 4) + reservedPadSize;

    // cmap header: version(2) + numTables(2) + platformRecord(8)
    const cmapHeaderSize = 4;
    const encodingRecordSize = 8;
    final subtableOffset = cmapHeaderSize + encodingRecordSize;

    final builder = BytesBuilder();

    // cmap header
    final cmapHeader = ByteData(cmapHeaderSize);
    cmapHeader.setUint16(0, 0); // version
    cmapHeader.setUint16(2, 1); // numTables
    builder.add(cmapHeader.buffer.asUint8List());

    // Encoding record: platform 3, encoding 1
    final encodingRecord = ByteData(encodingRecordSize);
    encodingRecord.setUint16(0, 3); // platformID
    encodingRecord.setUint16(2, 1); // encodingID
    encodingRecord.setUint32(4, subtableOffset);
    builder.add(encodingRecord.buffer.asUint8List());

    // Format 4 subtable header
    final subtableHeader = ByteData(subtableHeaderSize);
    subtableHeader.setUint16(0, 4); // format
    subtableHeader.setUint16(2, subtableSize);
    subtableHeader.setUint16(4, 0); // language
    subtableHeader.setUint16(6, segmentCount * 2); // segCountX2
    subtableHeader.setUint16(8, searchRangeValue);
    subtableHeader.setUint16(10, entrySelectorValue);
    subtableHeader.setUint16(12, rangeShiftValue);
    builder.add(subtableHeader.buffer.asUint8List());

    // endCode array
    for (final range in ranges) {
      final endCode = ByteData(2)..setUint16(0, range.endCode);
      builder.add(endCode.buffer.asUint8List());
    }
    builder.add(ByteData(2).buffer.asUint8List()..setAll(0, [0xFF, 0xFF]));

    // reservedPad
    builder.add(ByteData(2).buffer.asUint8List());

    // startCode array
    for (final range in ranges) {
      final startCode = ByteData(2)..setUint16(0, range.startCode);
      builder.add(startCode.buffer.asUint8List());
    }
    builder.add(ByteData(2).buffer.asUint8List()..setAll(0, [0xFF, 0xFF]));

    // idDelta array
    for (final range in ranges) {
      final idDelta = ByteData(2)
        ..setInt16(0, range.startGlyphId - range.startCode);
      builder.add(idDelta.buffer.asUint8List());
    }
    // Sentinel idDelta: 1 so that 0xFFFF + 1 = 0 (mod 65536)
    final sentinelDelta = ByteData(2)..setInt16(0, 1);
    builder.add(sentinelDelta.buffer.asUint8List());

    // idRangeOffset array (all zeros — we use idDelta for direct mapping)
    for (var index = 0; index < segmentCount; index += 1) {
      builder.add(ByteData(2).buffer.asUint8List());
    }

    return SfntTable(tag: 'cmap', data: builder.takeBytes());
  }

  /// Builds the `post` table (PostScript name mapping, format 3.0, 32 bytes).
  /// Format 3.0 means glyph names are not stored here (they come from CFF).
  SfntTable buildPostTable() {
    final data = ByteData(32);
    data.setUint32(0, 0x00030000); // format 3.0
    // italicAngle (fixed 16.16 at offset 4) = 0
    data.setInt16(8, -100); // underlinePosition
    data.setInt16(10, 50); // underlineThickness
    data.setUint32(12, 1); // isFixedPitch (monospaced icons)
    // minMemType42..maxMemType1 (offsets 16..28) = 0
    return SfntTable(tag: 'post', data: data.buffer.asUint8List());
  }

  /// Builds the `hmtx` table with horizontal metrics for each glyph.
  SfntTable buildHmtxTable({required List<HorizontalMetric> metrics}) {
    final data = ByteData(metrics.length * 4);
    for (var index = 0; index < metrics.length; index += 1) {
      final offset = index * 4;
      data.setUint16(offset, metrics[index].advanceWidth);
      data.setInt16(offset + 2, metrics[index].leftSideBearing);
    }
    return SfntTable(tag: 'hmtx', data: data.buffer.asUint8List());
  }

  // -- Private helpers --

  Uint8List _encodeUtf16BigEndian(String value) {
    final builder = BytesBuilder();
    for (final codeUnit in value.codeUnits) {
      builder.add([codeUnit >> 8, codeUnit & 0xFF]);
    }
    return builder.takeBytes();
  }

  String _sanitizePostScriptName(String name) {
    return name
        .replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  int _highestPowerOfTwo(int value) {
    if (value <= 0) return 0;
    var power = 1;
    while (power * 2 <= value) {
      power *= 2;
    }
    return power;
  }

  int _log2Floor(int value) {
    if (value <= 0) return 0;
    var result = 0;
    var remaining = value;
    while (remaining > 1) {
      remaining ~/= 2;
      result += 1;
    }
    return result;
  }

  List<_CmapRange> _buildCmapRanges(List<CmapEntry> sortedEntries) {
    if (sortedEntries.isEmpty) {
      return const [];
    }

    final ranges = <_CmapRange>[];
    var rangeStart = sortedEntries.first.codePoint;
    var rangeStartGlyphId = sortedEntries.first.glyphId;
    var previousCode = rangeStart;

    for (var index = 1; index < sortedEntries.length; index += 1) {
      final entry = sortedEntries[index];
      final expectedGlyphId =
          rangeStartGlyphId + (entry.codePoint - rangeStart);

      if (entry.codePoint == previousCode + 1 &&
          entry.glyphId == expectedGlyphId) {
        // Continue the current contiguous range.
        previousCode = entry.codePoint;
      } else {
        // Finalize the current range and start a new one.
        ranges.add(
          _CmapRange(
            startCode: rangeStart,
            endCode: previousCode,
            startGlyphId: rangeStartGlyphId,
          ),
        );
        rangeStart = entry.codePoint;
        rangeStartGlyphId = entry.glyphId;
        previousCode = entry.codePoint;
      }
    }

    ranges.add(
      _CmapRange(
        startCode: rangeStart,
        endCode: previousCode,
        startGlyphId: rangeStartGlyphId,
      ),
    );

    return ranges;
  }
}

class _NameRecord {
  const _NameRecord({required this.nameId, required this.value});

  final int nameId;
  final String value;
}

class _CmapRange {
  const _CmapRange({
    required this.startCode,
    required this.endCode,
    required this.startGlyphId,
  });

  final int startCode;
  final int endCode;
  final int startGlyphId;
}
