import 'dart:math' as math;
import 'dart:typed_data';

import '../../cff.dart';
import '../../cff_contour_program_strategy.dart';
import '../../font_glyph.dart';
import '../../font_writer.dart';
import '../../sfnt.dart';
import '../ttf/writer.dart';
import 'table_builders.dart';

/// Writes a CFF-based OpenType (.otf) font file from compiled glyph data.
///
/// Assembles all required SFNT tables (head, hhea, maxp, OS/2, name, cmap,
/// post, hmtx, CFF) and packages them via [SfntWriter] with the "OTTO"
/// scaler type signature.
class OtfWriter implements FontWriter {
  const OtfWriter({
    this.rightSideBearingPaddingUnits =
        TtfWriter.defaultRightSideBearingPaddingUnits,
    this.cffEncoder = const CffEncoder(),
    this.tableBuilder = const OtfTableBuilder(),
  });

  /// "OTTO" in big-endian — identifies CFF-based OpenType fonts.
  static const int ottoScalerType = 0x4F54544F;

  final int unitsPerEm = 512;
  final int rightSideBearingPaddingUnits;
  final CffEncoder cffEncoder;
  final OtfTableBuilder tableBuilder;

  @override
  Uint8List write({
    required String familyName,
    required List<FontGlyph> glyphs,
  }) {
    final numberOfGlyphs = glyphs.length + 1; // +1 for .notdef
    final advanceWidth = unitsPerEm + rightSideBearingPaddingUnits;

    // Build CFF glyph metrics and contour paths.
    final cffGlyphMetrics = <CffGlyphMetrics>[];
    final contourPaths = <dynamic>[];
    var globalXMin = 0;
    var globalYMin = 0;
    var globalXMax = 0;
    var globalYMax = 0;

    for (final glyph in glyphs) {
      final xMax =
          (glyph.sourceWidth *
                  unitsPerEm /
                  math.max(glyph.sourceWidth, glyph.sourceHeight))
              .round();
      final yMax =
          (glyph.sourceHeight *
                  unitsPerEm /
                  math.max(glyph.sourceWidth, glyph.sourceHeight))
              .round();

      cffGlyphMetrics.add(CffGlyphMetrics(xMax: xMax, yMax: yMax));

      if (glyph.compiledContourPath != null) {
        contourPaths.add(glyph.compiledContourPath!);
      }

      globalXMax = math.max(globalXMax, xMax);
      globalYMax = math.max(globalYMax, yMax);
    }

    // Choose CFF glyph program strategy:
    // - contour-based when contour data exists
    // - metrics fallback otherwise
    final hasContourData =
        contourPaths.length == glyphs.length &&
        contourPaths.every((path) => path.contours.isNotEmpty);

    final CffEncoder encoder;
    if (hasContourData) {
      encoder = CffEncoder(
        glyphProgramStrategy: ContourCffGlyphProgramStrategy(
          contourPaths: List.from(contourPaths),
          advanceWidth: advanceWidth,
        ),
      );
    } else {
      encoder = cffEncoder;
    }

    // Encode CFF data.
    final cffData = encoder.encode(
      CffBuildInput(
        familyName: familyName,
        glyphs: cffGlyphMetrics,
        glyphNames: glyphs.map((glyph) => glyph.name).toList(growable: false),
      ),
    );

    // Build cmap entries.
    final cmapEntries = <CmapEntry>[];
    for (var index = 0; index < glyphs.length; index += 1) {
      cmapEntries.add(
        CmapEntry(
          codePoint: glyphs[index].codePoint,
          glyphId: index + 1, // .notdef is glyphId 0
        ),
      );
    }

    // Build horizontal metrics (.notdef + each glyph).
    final horizontalMetrics = <HorizontalMetric>[
      HorizontalMetric(advanceWidth: advanceWidth, leftSideBearing: 0),
      ...glyphs.map(
        (glyph) =>
            HorizontalMetric(advanceWidth: advanceWidth, leftSideBearing: 0),
      ),
    ];

    final firstCharIndex = glyphs.isEmpty ? 0 : glyphs.first.codePoint;
    final lastCharIndex = glyphs.isEmpty ? 0 : glyphs.last.codePoint;

    // Assemble SFNT tables.
    final tables = <SfntTable>[
      tableBuilder.buildHeadTable(
        unitsPerEm: unitsPerEm,
        boundingBox: FontBoundingBox(
          xMin: globalXMin,
          yMin: globalYMin,
          xMax: globalXMax,
          yMax: globalYMax,
        ),
      ),
      tableBuilder.buildHheaTable(
        unitsPerEm: unitsPerEm,
        advanceWidthMax: advanceWidth,
        numberOfHorizontalMetrics: numberOfGlyphs,
      ),
      tableBuilder.buildMaxpTable(numberOfGlyphs: numberOfGlyphs),
      tableBuilder.buildOs2Table(
        unitsPerEm: unitsPerEm,
        firstCharIndex: firstCharIndex,
        lastCharIndex: lastCharIndex,
      ),
      tableBuilder.buildNameTable(familyName: familyName),
      tableBuilder.buildCmapTable(entries: cmapEntries),
      tableBuilder.buildPostTable(),
      tableBuilder.buildHmtxTable(metrics: horizontalMetrics),
      SfntTable(tag: 'CFF ', data: cffData),
    ];

    return const SfntWriter(scalerType: ottoScalerType).write(tables);
  }
}
