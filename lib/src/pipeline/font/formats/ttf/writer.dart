import 'dart:math' as math;
import 'dart:typed_data';

import '../../font_glyph.dart';
import '../../font_writer.dart';
import '../../sfnt.dart';
import '../../../contour/contour.dart';
import '../../../contour/contour_flattener.dart';
import '../otf/table_builders.dart';

class TtfWriter implements FontWriter {
  const TtfWriter({
    this.rightSideBearingPaddingUnits = defaultRightSideBearingPaddingUnits,
    this.tableBuilder = const OtfTableBuilder(),
    this.curveFlattenSteps = 8,
  });

  static const int defaultRightSideBearingPaddingUnits = 64;

  final int unitsPerEm = 512;
  final int rightSideBearingPaddingUnits;
  final OtfTableBuilder tableBuilder;
  final int curveFlattenSteps;

  @override
  Uint8List write({
    required String familyName,
    required List<FontGlyph> glyphs,
  }) {
    final numberOfGlyphs = glyphs.length + 1; // +1 for .notdef
    final advanceWidth = unitsPerEm + rightSideBearingPaddingUnits;

    final cmapEntries = <CmapEntry>[];
    final horizontalMetrics = <HorizontalMetric>[];
    final glyphRecords = <_SimpleGlyphRecord>[];

    // .notdef (glyph 0)
    horizontalMetrics.add(
      HorizontalMetric(advanceWidth: advanceWidth, leftSideBearing: 0),
    );
    glyphRecords.add(_SimpleGlyphRecord.empty());

    var globalXMin = 0;
    var globalYMin = 0;
    var globalXMax = 0;
    var globalYMax = 0;

    var maxPoints = 0;
    var maxContours = 0;

    for (var index = 0; index < glyphs.length; index += 1) {
      final glyph = glyphs[index];
      cmapEntries.add(
        CmapEntry(codePoint: glyph.codePoint, glyphId: index + 1),
      );

      final record = _buildGlyphRecord(glyph);
      glyphRecords.add(record);

      horizontalMetrics.add(
        HorizontalMetric(
          advanceWidth: advanceWidth,
          leftSideBearing: record.leftSideBearing,
        ),
      );

      globalXMin = math.min(globalXMin, record.xMin);
      globalYMin = math.min(globalYMin, record.yMin);
      globalXMax = math.max(globalXMax, record.xMax);
      globalYMax = math.max(globalYMax, record.yMax);

      maxPoints = math.max(maxPoints, record.pointCount);
      maxContours = math.max(maxContours, record.contourCount);
    }

    final glyphDataAndLoca = _buildGlyfAndLoca(glyphRecords);

    final firstCharIndex = glyphs.isEmpty ? 0 : glyphs.first.codePoint;
    final lastCharIndex = glyphs.isEmpty ? 0 : glyphs.last.codePoint;

    final tables = <SfntTable>[
      _buildHeadTable(
        unitsPerEm: unitsPerEm,
        boundingBox: FontBoundingBox(
          xMin: globalXMin,
          yMin: globalYMin,
          xMax: globalXMax,
          yMax: globalYMax,
        ),
      ),
      _buildHheaTable(
        unitsPerEm: unitsPerEm,
        advanceWidthMax: advanceWidth,
        horizontalMetrics: horizontalMetrics,
        glyphRecords: glyphRecords,
      ),
      _buildMaxpTable(
        numberOfGlyphs: numberOfGlyphs,
        maxPoints: maxPoints,
        maxContours: maxContours,
      ),
      tableBuilder.buildOs2Table(
        unitsPerEm: unitsPerEm,
        firstCharIndex: firstCharIndex,
        lastCharIndex: lastCharIndex,
      ),
      tableBuilder.buildNameTable(familyName: familyName),
      tableBuilder.buildCmapTable(entries: cmapEntries),
      tableBuilder.buildPostTable(),
      tableBuilder.buildHmtxTable(metrics: horizontalMetrics),
      SfntTable(tag: 'glyf', data: glyphDataAndLoca.glyfData),
      SfntTable(tag: 'loca', data: glyphDataAndLoca.locaData),
    ];

    return const SfntWriter().write(tables);
  }

  _SimpleGlyphRecord _buildGlyphRecord(FontGlyph glyph) {
    final compiledPath = glyph.compiledContourPath;
    if (compiledPath == null || compiledPath.contours.isEmpty) {
      return _SimpleGlyphRecord.empty();
    }

    final contourPointLists = <List<_GlyphPoint>>[];
    for (final contour in compiledPath.contours) {
      final points = _contourToGlyphPoints(contour);
      if (points.length >= 2) {
        contourPointLists.add(points);
      }
    }

    if (contourPointLists.isEmpty) {
      return _SimpleGlyphRecord.empty();
    }

    var xMin = contourPointLists.first.first.x;
    var yMin = contourPointLists.first.first.y;
    var xMax = contourPointLists.first.first.x;
    var yMax = contourPointLists.first.first.y;

    for (final points in contourPointLists) {
      for (final point in points) {
        xMin = math.min(xMin, point.x);
        yMin = math.min(yMin, point.y);
        xMax = math.max(xMax, point.x);
        yMax = math.max(yMax, point.y);
      }
    }

    final glyphData = _encodeSimpleGlyph(
      contourPointLists: contourPointLists,
      xMin: xMin,
      yMin: yMin,
      xMax: xMax,
      yMax: yMax,
    );

    return _SimpleGlyphRecord(
      data: glyphData,
      xMin: xMin,
      yMin: yMin,
      xMax: xMax,
      yMax: yMax,
      contourCount: contourPointLists.length,
      pointCount: contourPointLists.fold<int>(
        0,
        (sum, points) => sum + points.length,
      ),
      leftSideBearing: xMin,
    );
  }

  List<_GlyphPoint> _contourToGlyphPoints(SvgContour contour) {
    final flattened = flattenContourToPolyline(
      contour,
      curveSteps: curveFlattenSteps,
      arcMaxError: 0.25,
    );
    if (flattened.isEmpty) {
      return const [];
    }

    var points = flattened
        .map((point) => _GlyphPoint(x: point.x.round(), y: point.y.round()))
        .toList(growable: true);

    // Drop terminal duplicate when flattening returns closed start/end pair.
    if (points.length > 1 &&
        points.first.x == points.last.x &&
        points.first.y == points.last.y) {
      points.removeLast();
    }

    // Coalesce adjacent duplicate points to avoid zero-length segments.
    final deduplicated = <_GlyphPoint>[];
    for (final point in points) {
      if (deduplicated.isEmpty ||
          deduplicated.last.x != point.x ||
          deduplicated.last.y != point.y) {
        deduplicated.add(point);
      }
    }

    return deduplicated;
  }

  Uint8List _encodeSimpleGlyph({
    required List<List<_GlyphPoint>> contourPointLists,
    required int xMin,
    required int yMin,
    required int xMax,
    required int yMax,
  }) {
    final allPoints = <_GlyphPoint>[];
    final endPtsOfContours = <int>[];

    for (final contour in contourPointLists) {
      allPoints.addAll(contour);
      endPtsOfContours.add(allPoints.length - 1);
    }

    final flags = <int>[];
    final xBytes = BytesBuilder();
    final yBytes = BytesBuilder();

    var previousX = 0;
    var previousY = 0;

    for (final point in allPoints) {
      final dx = point.x - previousX;
      final dy = point.y - previousY;

      final encoded = _encodePointDeltas(dx: dx, dy: dy);
      flags.add(encoded.flag);
      if (encoded.xData.isNotEmpty) {
        xBytes.add(encoded.xData);
      }
      if (encoded.yData.isNotEmpty) {
        yBytes.add(encoded.yData);
      }

      previousX = point.x;
      previousY = point.y;
    }

    final compressedFlags = _compressFlags(flags);
    final builder = BytesBuilder();

    final header = ByteData(10);
    header.setInt16(0, contourPointLists.length);
    header.setInt16(2, xMin);
    header.setInt16(4, yMin);
    header.setInt16(6, xMax);
    header.setInt16(8, yMax);
    builder.add(header.buffer.asUint8List());

    final endPointsData = ByteData(endPtsOfContours.length * 2);
    for (var index = 0; index < endPtsOfContours.length; index += 1) {
      endPointsData.setUint16(index * 2, endPtsOfContours[index]);
    }
    builder.add(endPointsData.buffer.asUint8List());

    // No hinting instructions.
    builder.add(Uint8List.fromList(const [0x00, 0x00]));
    builder.add(compressedFlags);
    builder.add(xBytes.takeBytes());
    builder.add(yBytes.takeBytes());

    return builder.takeBytes();
  }

  _GlyfAndLoca _buildGlyfAndLoca(List<_SimpleGlyphRecord> glyphRecords) {
    final glyfBuilder = BytesBuilder();
    final locaData = ByteData((glyphRecords.length + 1) * 4);

    var offset = 0;
    for (var index = 0; index < glyphRecords.length; index += 1) {
      locaData.setUint32(index * 4, offset);
      final glyphData = glyphRecords[index].data;
      glyfBuilder.add(glyphData);
      offset += glyphData.length;
    }
    locaData.setUint32(glyphRecords.length * 4, offset);

    return _GlyfAndLoca(
      glyfData: glyfBuilder.takeBytes(),
      locaData: locaData.buffer.asUint8List(),
    );
  }

  SfntTable _buildHeadTable({
    required int unitsPerEm,
    required FontBoundingBox boundingBox,
  }) {
    final data = ByteData(54);
    data.setUint32(0, 0x00010000); // version
    data.setUint32(4, 0x00010000); // fontRevision
    data.setUint32(8, 0); // checksumAdjustment
    data.setUint32(12, 0x5F0F3CF5); // magicNumber
    data.setUint16(16, 0x000B); // flags
    data.setUint16(18, unitsPerEm);
    data.setInt16(36, boundingBox.xMin);
    data.setInt16(38, boundingBox.yMin);
    data.setInt16(40, boundingBox.xMax);
    data.setInt16(42, boundingBox.yMax);
    data.setUint16(44, 0); // macStyle
    data.setUint16(46, 8); // lowestRecPPEM
    data.setInt16(48, 2); // fontDirectionHint
    data.setInt16(50, 1); // indexToLocFormat (long offsets)
    data.setInt16(52, 0); // glyphDataFormat
    return SfntTable(tag: 'head', data: data.buffer.asUint8List());
  }

  SfntTable _buildHheaTable({
    required int unitsPerEm,
    required int advanceWidthMax,
    required List<HorizontalMetric> horizontalMetrics,
    required List<_SimpleGlyphRecord> glyphRecords,
  }) {
    var minLeftSideBearing = 0;
    var minRightSideBearing = 0;
    var xMaxExtent = 0;

    for (var index = 0; index < glyphRecords.length; index += 1) {
      final metric = horizontalMetrics[index];
      final glyph = glyphRecords[index];
      final lsb = metric.leftSideBearing;
      final glyphWidth = glyph.xMax - glyph.xMin;
      final rsb = metric.advanceWidth - (lsb + glyphWidth);
      final extent = lsb + glyphWidth;

      minLeftSideBearing = math.min(minLeftSideBearing, lsb);
      minRightSideBearing = math.min(minRightSideBearing, rsb);
      xMaxExtent = math.max(xMaxExtent, extent);
    }

    final data = ByteData(36);
    data.setUint32(0, 0x00010000); // version
    data.setInt16(4, unitsPerEm); // ascender
    data.setInt16(6, 0); // descender
    data.setInt16(8, 0); // lineGap
    data.setUint16(10, advanceWidthMax);
    data.setInt16(12, minLeftSideBearing);
    data.setInt16(14, minRightSideBearing);
    data.setInt16(16, xMaxExtent);
    data.setInt16(18, 1); // caretSlopeRise
    data.setInt16(20, 0); // caretSlopeRun
    data.setInt16(32, 0); // metricDataFormat
    data.setUint16(34, horizontalMetrics.length);

    return SfntTable(tag: 'hhea', data: data.buffer.asUint8List());
  }

  SfntTable _buildMaxpTable({
    required int numberOfGlyphs,
    required int maxPoints,
    required int maxContours,
  }) {
    // TrueType maxp v1.0 (32 bytes).
    final data = ByteData(32);
    data.setUint32(0, 0x00010000);
    data.setUint16(4, numberOfGlyphs);
    data.setUint16(6, maxPoints);
    data.setUint16(8, maxContours);
    data.setUint16(10, 0); // maxCompositePoints
    data.setUint16(12, 0); // maxCompositeContours
    data.setUint16(14, 2); // maxZones
    data.setUint16(16, maxPoints); // maxTwilightPoints
    data.setUint16(18, 0); // maxStorage
    data.setUint16(20, 0); // maxFunctionDefs
    data.setUint16(22, 0); // maxInstructionDefs
    data.setUint16(24, 0); // maxStackElements
    data.setUint16(26, 0); // maxSizeOfInstructions
    data.setUint16(28, maxContours); // maxComponentElements
    data.setUint16(30, 0); // maxComponentDepth
    return SfntTable(tag: 'maxp', data: data.buffer.asUint8List());
  }

  _EncodedPoint _encodePointDeltas({required int dx, required int dy}) {
    const onCurve = 0x01;
    const xShort = 0x02;
    const yShort = 0x04;
    const xSameOrPositive = 0x10;
    const ySameOrPositive = 0x20;

    var flag = onCurve;
    Uint8List xData = Uint8List(0);
    Uint8List yData = Uint8List(0);

    if (dx == 0) {
      flag |= xSameOrPositive;
    } else if (dx > 0 && dx <= 255) {
      flag |= xShort;
      flag |= xSameOrPositive;
      xData = Uint8List.fromList([dx]);
    } else if (dx < 0 && dx >= -255) {
      flag |= xShort;
      xData = Uint8List.fromList([-dx]);
    } else {
      final xLong = ByteData(2)..setInt16(0, dx);
      xData = xLong.buffer.asUint8List();
    }

    if (dy == 0) {
      flag |= ySameOrPositive;
    } else if (dy > 0 && dy <= 255) {
      flag |= yShort;
      flag |= ySameOrPositive;
      yData = Uint8List.fromList([dy]);
    } else if (dy < 0 && dy >= -255) {
      flag |= yShort;
      yData = Uint8List.fromList([-dy]);
    } else {
      final yLong = ByteData(2)..setInt16(0, dy);
      yData = yLong.buffer.asUint8List();
    }

    return _EncodedPoint(flag: flag, xData: xData, yData: yData);
  }

  Uint8List _compressFlags(List<int> flags) {
    const repeatFlag = 0x08;
    final builder = BytesBuilder();

    var index = 0;
    while (index < flags.length) {
      final current = flags[index];
      var repeatCount = 0;
      while (index + repeatCount + 1 < flags.length &&
          flags[index + repeatCount + 1] == current &&
          repeatCount < 255) {
        repeatCount += 1;
      }

      if (repeatCount > 0) {
        builder.add([current | repeatFlag, repeatCount]);
      } else {
        builder.add([current]);
      }
      index += repeatCount + 1;
    }

    return builder.takeBytes();
  }
}

class _GlyphPoint {
  const _GlyphPoint({required this.x, required this.y});

  final int x;
  final int y;
}

class _SimpleGlyphRecord {
  const _SimpleGlyphRecord({
    required this.data,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
    required this.contourCount,
    required this.pointCount,
    required this.leftSideBearing,
  });

  factory _SimpleGlyphRecord.empty() {
    // numberOfContours=0, bbox=0, no points.
    final data = ByteData(12);
    data.setInt16(0, 0);
    data.setInt16(2, 0);
    data.setInt16(4, 0);
    data.setInt16(6, 0);
    data.setInt16(8, 0);
    data.setUint16(10, 0); // instructionLength
    return _SimpleGlyphRecord(
      data: data.buffer.asUint8List(),
      xMin: 0,
      yMin: 0,
      xMax: 0,
      yMax: 0,
      contourCount: 0,
      pointCount: 0,
      leftSideBearing: 0,
    );
  }

  final Uint8List data;
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;
  final int contourCount;
  final int pointCount;
  final int leftSideBearing;
}

class _GlyfAndLoca {
  const _GlyfAndLoca({required this.glyfData, required this.locaData});

  final Uint8List glyfData;
  final Uint8List locaData;
}

class _EncodedPoint {
  const _EncodedPoint({
    required this.flag,
    required this.xData,
    required this.yData,
  });

  final int flag;
  final Uint8List xData;
  final Uint8List yData;
}
