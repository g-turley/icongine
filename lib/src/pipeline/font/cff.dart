import 'dart:typed_data';

import 'type2_charstring_encoder.dart';

/// Bounding metrics used when building a glyph program in the CFF table.
class CffGlyphMetrics {
  const CffGlyphMetrics({
    this.xMin = 0,
    this.yMin = 0,
    required this.xMax,
    required this.yMax,
  });

  /// Minimum X coordinate of the glyph bounds.
  final int xMin;

  /// Minimum Y coordinate of the glyph bounds.
  final int yMin;

  /// Maximum X coordinate of the glyph bounds.
  final int xMax;

  /// Maximum Y coordinate of the glyph bounds.
  final int yMax;
}

/// Input payload used by [CffEncoder] to build a minimal CFF table.
class CffBuildInput {
  const CffBuildInput({
    required this.familyName,
    required this.glyphs,
    required this.glyphNames,
  });

  /// PostScript font family name stored in the CFF name index.
  final String familyName;

  /// Glyph metrics, excluding the implicit `.notdef` glyph.
  final List<CffGlyphMetrics> glyphs;

  /// Glyph names paired with [glyphs].
  final List<String> glyphNames;
}

/// Strategy for generating Type 2 charstrings for CFF glyphs.
abstract interface class CffGlyphProgramStrategy {
  /// Builds the program for the required `.notdef` glyph.
  Uint8List buildNotdefProgram();

  /// Builds the program for a glyph at [glyphIndex].
  Uint8List buildGlyphProgram({
    required int glyphIndex,
    required CffGlyphMetrics glyph,
  });
}

/// Simple fallback strategy that emits a rectangle from glyph metrics.
class MetricsRectGlyphProgramStrategy implements CffGlyphProgramStrategy {
  const MetricsRectGlyphProgramStrategy({
    this.encoder = const Type2CharstringEncoder(),
  });

  /// Number encoder used to write Type 2 charstrings.
  final Type2CharstringEncoder encoder;

  @override
  Uint8List buildNotdefProgram() {
    return Uint8List.fromList([Type2CharstringEncoder.operatorEndchar]);
  }

  @override
  Uint8List buildGlyphProgram({
    required int glyphIndex,
    required CffGlyphMetrics glyph,
  }) {
    final program = BytesBuilder();

    encoder.writeNumber(program, 0);
    encoder.writeNumber(program, 0);
    program.add([Type2CharstringEncoder.operatorRmoveto]);

    encoder.writeNumber(program, glyph.xMax);
    encoder.writeNumber(program, 0);
    encoder.writeNumber(program, 0);
    encoder.writeNumber(program, glyph.yMax);
    encoder.writeNumber(program, -glyph.xMax);
    encoder.writeNumber(program, 0);
    encoder.writeNumber(program, 0);
    encoder.writeNumber(program, -glyph.yMax);
    program.add([Type2CharstringEncoder.operatorRlineto]);

    program.add([Type2CharstringEncoder.operatorEndchar]);
    return program.takeBytes();
  }
}

/// Emits an empty glyph program (`endchar` only) for each glyph.
///
/// This is useful for OTF + `SVG ` fonts where SVG documents are the
/// intended glyph source and CFF outlines are only structural fallbacks.
class EmptyGlyphProgramStrategy implements CffGlyphProgramStrategy {
  const EmptyGlyphProgramStrategy();

  @override
  Uint8List buildNotdefProgram() {
    return Uint8List.fromList([Type2CharstringEncoder.operatorEndchar]);
  }

  @override
  Uint8List buildGlyphProgram({
    required int glyphIndex,
    required CffGlyphMetrics glyph,
  }) {
    return Uint8List.fromList([Type2CharstringEncoder.operatorEndchar]);
  }
}

/// Encodes glyph metadata into a Compact Font Format table.
class CffEncoder {
  const CffEncoder({
    this.glyphProgramStrategy = const MetricsRectGlyphProgramStrategy(),
  });

  /// Strategy used to generate charstrings for each glyph.
  final CffGlyphProgramStrategy glyphProgramStrategy;

  /// Encodes a complete CFF payload for [input].
  Uint8List encode(CffBuildInput input) {
    final numGlyphs = input.glyphs.length + 1; // include .notdef
    final glyphNames = input.glyphNames.length == input.glyphs.length
        ? input.glyphNames.map(_sanitizeGlyphName).toList(growable: false)
        : List<String>.generate(
            numGlyphs - 1,
            (index) => 'glyph${index + 1}',
            growable: false,
          );
    final charsetSids = List<int>.generate(
      glyphNames.length,
      (index) => 391 + index, // custom String INDEX SIDs start at 391
      growable: false,
    );

    final nameIndex = _buildCffIndex([_toAsciiBytes(input.familyName)]);
    final stringIndex = _buildCffIndex(
      glyphNames.map(_toAsciiBytes).toList(growable: false),
    );
    final globalSubrIndex = _buildCffIndex(const []);
    final charsetData = _buildCharsetData(charsetSids);
    final charStringsIndex = _buildCharStringsIndex(input.glyphs);

    // Build a minimal Private DICT with defaultWidthX=0 and nominalWidthX=0.
    final privateDictData = _buildPrivateDict();

    const headerLength = 4;
    var topDictIndexLength = 0;
    Uint8List topDictIndex = Uint8List(0);
    for (var iteration = 0; iteration < 8; iteration += 1) {
      final charsetOffset =
          headerLength +
          nameIndex.length +
          topDictIndexLength +
          stringIndex.length +
          globalSubrIndex.length;
      final charStringsOffset = charsetOffset + charsetData.length;
      final privateDictOffset = charStringsOffset + charStringsIndex.length;

      final topDictData = Uint8List.fromList([
        ..._encodeCffInteger(charsetOffset),
        15, // charset operator
        ..._encodeCffInteger(charStringsOffset),
        17, // CharStrings operator
        ..._encodeCffInteger(privateDictData.length),
        ..._encodeCffInteger(privateDictOffset),
        18, // Private operator (size, offset)
      ]);
      topDictIndex = _buildCffIndex([topDictData]);

      if (topDictIndex.length == topDictIndexLength) {
        break;
      }
      topDictIndexLength = topDictIndex.length;
    }

    final builder = BytesBuilder()
      ..add([1, 0, 4, 4]) // CFF header
      ..add(nameIndex)
      ..add(topDictIndex)
      ..add(stringIndex)
      ..add(globalSubrIndex)
      ..add(charsetData)
      ..add(charStringsIndex)
      ..add(privateDictData);
    return builder.takeBytes();
  }

  Uint8List _buildCffIndex(List<Uint8List> objects) {
    final builder = BytesBuilder();
    final header = ByteData(2)..setUint16(0, objects.length);
    builder.add(header.buffer.asUint8List());

    if (objects.isEmpty) {
      return builder.takeBytes();
    }

    var runningOffset = 1;
    for (final object in objects) {
      runningOffset += object.length;
    }

    final offSize = _requiredOffSize(runningOffset);
    builder.add([offSize]);

    runningOffset = 1;
    final offsetData = ByteData((objects.length + 1) * offSize);
    for (var index = 0; index < objects.length; index += 1) {
      _setOffsetValue(offsetData, index * offSize, offSize, runningOffset);
      runningOffset += objects[index].length;
    }
    _setOffsetValue(
      offsetData,
      objects.length * offSize,
      offSize,
      runningOffset,
    );
    builder.add(offsetData.buffer.asUint8List());

    for (final object in objects) {
      builder.add(object);
    }

    return builder.takeBytes();
  }

  int _requiredOffSize(int maxOffsetValue) {
    if (maxOffsetValue <= 0xff) {
      return 1;
    }
    if (maxOffsetValue <= 0xffff) {
      return 2;
    }
    if (maxOffsetValue <= 0xffffff) {
      return 3;
    }
    return 4;
  }

  void _setOffsetValue(ByteData data, int offset, int offSize, int value) {
    for (var index = 0; index < offSize; index += 1) {
      final shift = (offSize - index - 1) * 8;
      data.setUint8(offset + index, (value >> shift) & 0xff);
    }
  }

  Uint8List _toAsciiBytes(String value) {
    final sanitized = value.isEmpty
        ? 'icongine'
        : value.replaceAll(RegExp(r'[^ -~]'), '_');
    return Uint8List.fromList(sanitized.codeUnits);
  }

  String _sanitizeGlyphName(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (sanitized.isEmpty) {
      return 'glyph';
    }
    return sanitized.length > 63 ? sanitized.substring(0, 63) : sanitized;
  }

  Uint8List _buildCharsetData(List<int> sids) {
    final builder = BytesBuilder()..add([0]); // format 0
    for (final sidValue in sids) {
      final sid = ByteData(2)..setUint16(0, sidValue);
      builder.add(sid.buffer.asUint8List());
    }
    return builder.takeBytes();
  }

  Uint8List _buildCharStringsIndex(List<CffGlyphMetrics> glyphs) {
    final glyphPrograms = <Uint8List>[
      glyphProgramStrategy.buildNotdefProgram(),
      ...glyphs.asMap().entries.map(
        (entry) => glyphProgramStrategy.buildGlyphProgram(
          glyphIndex: entry.key,
          glyph: entry.value,
        ),
      ),
    ];
    return _buildCffIndex(glyphPrograms);
  }

  /// Builds a minimal Private DICT with defaultWidthX=0 and nominalWidthX=0.
  /// These values mean the charstring width operand is an absolute advance width.
  Uint8List _buildPrivateDict() {
    return Uint8List.fromList([
      // defaultWidthX = 0 (operator 20)
      ..._encodeCffSmallInteger(0),
      20,
      // nominalWidthX = 0 (operator 21)
      ..._encodeCffSmallInteger(0),
      21,
    ]);
  }

  /// Encodes a small integer using the 1-byte Type2 encoding (range -107..107).
  Uint8List _encodeCffSmallInteger(int value) {
    return Uint8List.fromList([value + 139]);
  }

  Uint8List _encodeCffInteger(int value) {
    final byteData = ByteData(5);
    byteData.setUint8(0, 29); // int32 operator
    byteData.setInt32(1, value);
    return byteData.buffer.asUint8List();
  }
}
