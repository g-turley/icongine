import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as image;

import '../../domain/icon_symbol.dart';
import '../../domain/png_tracing_mode.dart';
import '../font/font_glyph.dart';
import '../contour/contour.dart';
import '../contour/raster_loop_smoother.dart';
import '../contour/alpha_contour_tracer.dart';
import '../contour/rect_clipper.dart';
import '../contour/stroke_style.dart';
import '../contour/stroke_to_fill_converter.dart';
import '../contour/winding_corrector.dart';
import '../svg_input/coordinate_transformer.dart';
import '../svg_input/document.dart';
import '../svg_input/path_data_parser.dart';
import 'compile.dart';

abstract interface class GlyphCompilationFacade {
  List<FontGlyph> compileGlyphs({
    required List<IconSymbol> symbols,
    required int startCodePoint,
    required int targetUnitsPerEm,
    required bool normalize,
  });
}

/// Optional PNG tracing support without changing existing custom facades.
abstract interface class PngTracingGlyphCompilationFacade
    implements GlyphCompilationFacade {
  @override
  List<FontGlyph> compileGlyphs({
    required List<IconSymbol> symbols,
    required int startCodePoint,
    required int targetUnitsPerEm,
    required bool normalize,
    PngTracingMode pngTracing = PngTracingMode.smooth,
  });
}

class SvgGlyphCompilationFacade implements PngTracingGlyphCompilationFacade {
  const SvgGlyphCompilationFacade({
    this.boundsExtractor = const DefaultSvgBoundsExtractor(),
    this.documentExtractor = const SvgDocumentPathExtractor(),
    this.pathDataParser = const SvgPathDataParser(),
    this.coordinateTransformer = const SvgToFontCoordinateTransformer(
      contentScale: 0.92,
    ),
    this.rectClipper = const SvgRectClipper(),
    this.rasterLoopSmoother = const RasterLoopSmoother(),
    this.strokeToFillConverter = const StrokeToFillConverter(),
    this.windingCorrector = const WindingCorrector(),
  });

  final SvgBoundsExtractor boundsExtractor;
  final SvgDocumentPathExtractor documentExtractor;
  final SvgPathDataParser pathDataParser;
  final SvgToFontCoordinateTransformer coordinateTransformer;
  final SvgRectClipper rectClipper;
  final RasterLoopSmoother rasterLoopSmoother;
  final StrokeToFillConverter strokeToFillConverter;
  final WindingCorrector windingCorrector;

  @override
  List<FontGlyph> compileGlyphs({
    required List<IconSymbol> symbols,
    required int startCodePoint,
    required int targetUnitsPerEm,
    required bool normalize,
    PngTracingMode pngTracing = PngTracingMode.smooth,
  }) {
    final preparedGlyphs = symbols
        .map((symbol) => _prepareGlyph(symbol, pngTracing))
        .toList(growable: false);
    final normalizationPlan = _resolveNormalizationPlan(preparedGlyphs);

    final glyphs = <FontGlyph>[];
    for (var index = 0; index < preparedGlyphs.length; index += 1) {
      final prepared = preparedGlyphs[index];
      final codePoint = startCodePoint + index;
      final sizeScale = normalize
          ? _resolveGlyphSizeScale(
              sourceWidth: prepared.sourceWidth,
              sourceHeight: prepared.sourceHeight,
              targetWidth: normalizationPlan.targetWidth,
              targetHeight: normalizationPlan.targetHeight,
            )
          : 1.0;
      final normalizedSourceContourPath = sizeScale == 1.0
          ? prepared.sourceContourPath
          : _scaleContourPath(prepared.sourceContourPath, sizeScale);
      final normalizedSourceWidth = prepared.sourceWidth * sizeScale;
      final normalizedSourceHeight = prepared.sourceHeight * sizeScale;

      final compiledContourPath = coordinateTransformer.transform(
        contourPath: normalizedSourceContourPath,
        sourceWidth: normalizedSourceWidth,
        sourceHeight: normalizedSourceHeight,
        targetUnitsPerEm: targetUnitsPerEm,
        normalize: normalize,
        normalizationReferenceLongestSide: normalize
            ? normalizationPlan.referenceLongestSide
            : null,
      );

      glyphs.add(
        FontGlyph(
          name: prepared.symbol.name,
          codePoint: codePoint,
          glyphId: index + 1,
          sourceWidth: prepared.sourceWidth,
          sourceHeight: prepared.sourceHeight,
          sourceMinX: prepared.sourceMinX,
          sourceMinY: prepared.sourceMinY,
          sourceSvgPath: prepared.symbol.file.absolutePath,
          sourceSvgDocument: prepared.svgContent,
          sourceContourPath: prepared.sourceContourPath,
          compiledContourPath: compiledContourPath,
          normalizationScaled: sizeScale != 1.0,
        ),
      );
    }
    return glyphs;
  }

  _PreparedGlyph _prepareGlyph(IconSymbol symbol, PngTracingMode pngTracing) {
    final sourcePath = symbol.file.absolutePath;
    if (_isPngSource(sourcePath)) {
      return _preparePngGlyph(symbol, pngTracing);
    }

    return _prepareSvgGlyph(symbol);
  }

  _PreparedGlyph _prepareSvgGlyph(IconSymbol symbol) {
    final svgContent = File(symbol.file.absolutePath).readAsStringSync();
    final documentData = documentExtractor.extract(svgContent);
    final viewport = documentData.viewport;
    final sourceWidth =
        viewport?.width ?? boundsExtractor.extract(svgContent).width;
    final sourceHeight =
        viewport?.height ?? boundsExtractor.extract(svgContent).height;

    final fillContours = <SvgContour>[];
    final strokeGroups = <_StrokeContourGroup>[];
    for (final pathEntry in documentData.pathEntries) {
      final parsed = pathDataParser.parse(pathEntry.pathData);
      var transformed = _applyElementTransform(
        parsed,
        pathEntry.transformMatrix,
      );
      final clipRect = pathEntry.clipRect;
      if (clipRect != null) {
        transformed = rectClipper.clipPath(transformed, clipRect);
      }
      if (transformed.contours.isEmpty) {
        continue;
      }
      final stroke = pathEntry.strokeProperties;
      final allContoursOpen = transformed.contours.every(
        (contour) => !contour.isClosed,
      );
      final allContoursClosed = transformed.contours.every(
        (contour) => contour.isClosed,
      );

      final shouldEmitFill = stroke == null || stroke.hasVisibleFill;
      if (shouldEmitFill) {
        final closedFillContours = _closeContoursForFill(transformed.contours);
        fillContours.addAll(
          _normalizeFillContoursForRule(
            contours: closedFillContours,
            fillRule: pathEntry.fillRule,
            windingCorrector: windingCorrector,
          ),
        );
      }

      final shouldExpandStroke =
          stroke != null && (stroke.isStrokeOnly || allContoursOpen);
      if (shouldExpandStroke) {
        final expanded = strokeToFillConverter.convert(
          sourcePath: transformed,
          strokeProperties: stroke,
        );
        strokeGroups.add(
          _StrokeContourGroup(
            sourceAllClosed: allContoursClosed,
            sourceTagName: pathEntry.sourceTagName,
            contours: expanded.contours,
          ),
        );
      }
    }

    final strokeContours = <SvgContour>[
      for (final group in strokeGroups) ...group.contours,
    ];
    final sourceContourPath = SvgContourPath(
      contours: [...fillContours, ...strokeContours],
    );

    return _PreparedGlyph(
      symbol: symbol,
      svgContent: svgContent,
      sourceContourPath: sourceContourPath,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      sourceMinX: viewport?.minX ?? 0,
      sourceMinY: viewport?.minY ?? 0,
    );
  }

  _PreparedGlyph _preparePngGlyph(
    IconSymbol symbol,
    PngTracingMode pngTracing,
  ) {
    final pngBytes = File(symbol.file.absolutePath).readAsBytesSync();
    final decodedImage = image.decodePng(pngBytes);
    if (decodedImage == null) {
      throw StateError(
        'Unable to decode PNG source: ${symbol.file.absolutePath}',
      );
    }

    final rasterContourPath = pngTracing == PngTracingMode.smooth
        ? const AlphaContourTracer().trace(decodedImage)
        : _buildRasterContourPath(
            decodedImage,
            preservePixels: pngTracing == PngTracingMode.pixel,
          );
    return _PreparedGlyph(
      symbol: symbol,
      svgContent: '',
      sourceContourPath: rasterContourPath,
      sourceWidth: decodedImage.width.toDouble(),
      sourceHeight: decodedImage.height.toDouble(),
      sourceMinX: 0,
      sourceMinY: 0,
    );
  }

  _NormalizationPlan _resolveNormalizationPlan(List<_PreparedGlyph> glyphs) {
    if (glyphs.isEmpty) {
      return const _NormalizationPlan(
        targetWidth: 1,
        targetHeight: 1,
        referenceLongestSide: 1,
      );
    }

    final grouped = <String, _SizeGroup>{};
    for (final glyph in glyphs) {
      final key = _sizeKey(glyph.sourceWidth, glyph.sourceHeight);
      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = _SizeGroup(
          key: key,
          width: glyph.sourceWidth,
          height: glyph.sourceHeight,
          count: 1,
        );
      } else {
        grouped[key] = existing.copyWith(count: existing.count + 1);
      }
    }

    final groups = grouped.values.toList(growable: false);
    final majorityGroup = groups
        .where((group) => group.count > glyphs.length / 2)
        .toList();
    final selected = majorityGroup.isNotEmpty
        ? majorityGroup.first
        : (groups..sort((left, right) {
                final byArea = (right.width * right.height).compareTo(
                  left.width * left.height,
                );
                if (byArea != 0) {
                  return byArea;
                }
                return right.count.compareTo(left.count);
              }))
              .first;

    final referenceLongestSide = math.max(selected.width, selected.height);
    return _NormalizationPlan(
      targetWidth: selected.width,
      targetHeight: selected.height,
      referenceLongestSide: referenceLongestSide <= 0
          ? 1
          : referenceLongestSide,
    );
  }

  double _resolveGlyphSizeScale({
    required double sourceWidth,
    required double sourceHeight,
    required double targetWidth,
    required double targetHeight,
  }) {
    final sourceLongest = math.max(sourceWidth, sourceHeight);
    final targetLongest = math.max(targetWidth, targetHeight);
    if (sourceLongest <= 0 || targetLongest <= 0) {
      return 1.0;
    }
    return targetLongest / sourceLongest;
  }

  SvgContourPath _scaleContourPath(SvgContourPath contourPath, double scale) {
    return SvgContourPath(
      contours: contourPath.contours
          .map((contour) => _scaleContour(contour, scale))
          .toList(growable: false),
    );
  }

  SvgContour _scaleContour(SvgContour contour, double scale) {
    return SvgContour(
      isClosed: contour.isClosed,
      segments: contour.segments
          .map((segment) => _scaleSegment(segment, scale))
          .toList(growable: false),
    );
  }

  SvgContourSegment _scaleSegment(SvgContourSegment segment, double scale) {
    switch (segment.type) {
      case SvgContourSegmentType.line:
        return SvgContourSegment.line(
          start: _scalePoint(segment.start, scale),
          end: _scalePoint(segment.end, scale),
        );
      case SvgContourSegmentType.cubic:
        return SvgContourSegment.cubic(
          start: _scalePoint(segment.start, scale),
          control1: _scalePoint(segment.control1!, scale),
          control2: _scalePoint(segment.control2!, scale),
          end: _scalePoint(segment.end, scale),
        );
      case SvgContourSegmentType.quadratic:
        return SvgContourSegment.quadratic(
          start: _scalePoint(segment.start, scale),
          control1: _scalePoint(segment.control1!, scale),
          end: _scalePoint(segment.end, scale),
        );
      case SvgContourSegmentType.arc:
        return SvgContourSegment.arc(
          start: _scalePoint(segment.start, scale),
          end: _scalePoint(segment.end, scale),
          rx: segment.rx! * scale,
          ry: segment.ry! * scale,
          xAxisRotation: segment.xAxisRotation!,
          largeArc: segment.largeArc!,
          sweep: segment.sweep!,
        );
    }
  }

  SvgPoint _scalePoint(SvgPoint point, double scale) {
    return SvgPoint(point.x * scale, point.y * scale);
  }

  String _sizeKey(double width, double height) {
    return '${width.toStringAsFixed(3)}x${height.toStringAsFixed(3)}';
  }

  List<SvgContour> _closeContoursForFill(List<SvgContour> contours) {
    return contours.map(_closeContourForFill).toList(growable: false);
  }

  List<SvgContour> _normalizeFillContoursForRule({
    required List<SvgContour> contours,
    required SvgFillRule fillRule,
    required WindingCorrector windingCorrector,
  }) {
    if (contours.isEmpty) {
      return const [];
    }
    return switch (fillRule) {
      SvgFillRule.evenodd || SvgFillRule.nonzero =>
        windingCorrector.correct(SvgContourPath(contours: contours)).contours,
    };
  }

  SvgContour _closeContourForFill(SvgContour contour) {
    if (contour.isClosed || contour.segments.isEmpty) {
      return contour;
    }
    final start = contour.segments.first.start;
    final end = contour.segments.last.end;
    final closedSegments = List<SvgContourSegment>.from(contour.segments);
    if (!_pointsEqual(start, end)) {
      closedSegments.add(SvgContourSegment.line(start: end, end: start));
    }
    return SvgContour(segments: closedSegments, isClosed: true);
  }

  SvgContourPath _applyElementTransform(
    SvgContourPath contourPath,
    SvgTransformMatrix? transformMatrix,
  ) {
    if (transformMatrix == null) {
      return contourPath;
    }
    final transformedContours = contourPath.contours
        .map((contour) => _transformContour(contour, transformMatrix))
        .toList();
    return SvgContourPath(contours: transformedContours);
  }

  SvgContour _transformContour(
    SvgContour contour,
    SvgTransformMatrix transformMatrix,
  ) {
    final transformedSegments = contour.segments
        .map((segment) => _transformSegment(segment, transformMatrix))
        .toList();
    return SvgContour(
      segments: transformedSegments,
      isClosed: contour.isClosed,
    );
  }

  SvgContourSegment _transformSegment(
    SvgContourSegment segment,
    SvgTransformMatrix transformMatrix,
  ) {
    final start = transformMatrix.applyToPoint(segment.start);
    final end = transformMatrix.applyToPoint(segment.end);
    switch (segment.type) {
      case SvgContourSegmentType.line:
        return SvgContourSegment.line(start: start, end: end);
      case SvgContourSegmentType.cubic:
        return SvgContourSegment.cubic(
          start: start,
          control1: transformMatrix.applyToPoint(segment.control1!),
          control2: transformMatrix.applyToPoint(segment.control2!),
          end: end,
        );
      case SvgContourSegmentType.quadratic:
        return SvgContourSegment.quadratic(
          start: start,
          control1: transformMatrix.applyToPoint(segment.control1!),
          end: end,
        );
      case SvgContourSegmentType.arc:
        final rotationDegrees =
            math.atan2(transformMatrix.b, transformMatrix.a) * (180 / math.pi);
        return SvgContourSegment.arc(
          start: start,
          end: end,
          rx: segment.rx!,
          ry: segment.ry!,
          xAxisRotation: (segment.xAxisRotation ?? 0) + rotationDegrees,
          largeArc: segment.largeArc!,
          sweep: segment.sweep!,
        );
    }
  }

  bool _pointsEqual(SvgPoint first, SvgPoint second) {
    return (first.x - second.x).abs() < 1e-9 &&
        (first.y - second.y).abs() < 1e-9;
  }

  bool _isPngSource(String sourcePath) {
    return sourcePath.toLowerCase().endsWith('.png');
  }

  SvgContourPath _buildRasterContourPath(
    image.Image rasterImage, {
    required bool preservePixels,
  }) {
    final mask = _buildRasterMask(rasterImage);
    final boundaryEdges = _extractRasterBoundaryEdges(mask);
    if (boundaryEdges.isEmpty) {
      return const SvgContourPath(contours: []);
    }

    final tracedContours =
        _traceRasterLoops(boundaryEdges, preservePixels: preservePixels)
            .map(
              (loop) => preservePixels
                  ? SvgContour(
                      isClosed: true,
                      segments: [
                        for (var i = 0; i < loop.length; i++)
                          SvgContourSegment.line(
                            start: loop[i],
                            end: loop[(i + 1) % loop.length],
                          ),
                      ],
                    )
                  : rasterLoopSmoother.smooth(loop),
            )
            .where((contour) => contour.segments.isNotEmpty)
            .toList(growable: false);
    return windingCorrector.correct(SvgContourPath(contours: tracedContours));
  }

  bool _isFilledPixel(image.Pixel pixel) {
    return pixel.aNormalized >= 0.5;
  }

  List<List<bool>> _buildRasterMask(image.Image rasterImage) {
    return List<List<bool>>.generate(
      rasterImage.height,
      (y) => List<bool>.generate(
        rasterImage.width,
        (x) => _isFilledPixel(rasterImage.getPixel(x, y)),
        growable: false,
      ),
      growable: false,
    );
  }

  List<_RasterEdge> _extractRasterBoundaryEdges(List<List<bool>> mask) {
    final height = mask.length;
    if (height == 0) {
      return const [];
    }
    final width = mask.first.length;
    final edges = <_RasterEdge>[];
    var nextEdgeId = 0;

    bool isFilledAt(int x, int y) {
      if (y < 0 || y >= height || x < 0 || x >= width) {
        return false;
      }
      return mask[y][x];
    }

    for (var y = 0; y < height; y += 1) {
      for (var x = 0; x < width; x += 1) {
        if (!mask[y][x]) {
          continue;
        }
        if (!isFilledAt(x, y - 1)) {
          edges.add(
            _RasterEdge(
              start: SvgPoint(x.toDouble(), y.toDouble()),
              end: SvgPoint((x + 1).toDouble(), y.toDouble()),
              id: nextEdgeId++,
            ),
          );
        }
        if (!isFilledAt(x + 1, y)) {
          edges.add(
            _RasterEdge(
              start: SvgPoint((x + 1).toDouble(), y.toDouble()),
              end: SvgPoint((x + 1).toDouble(), (y + 1).toDouble()),
              id: nextEdgeId++,
            ),
          );
        }
        if (!isFilledAt(x, y + 1)) {
          edges.add(
            _RasterEdge(
              start: SvgPoint((x + 1).toDouble(), (y + 1).toDouble()),
              end: SvgPoint(x.toDouble(), (y + 1).toDouble()),
              id: nextEdgeId++,
            ),
          );
        }
        if (!isFilledAt(x - 1, y)) {
          edges.add(
            _RasterEdge(
              start: SvgPoint(x.toDouble(), (y + 1).toDouble()),
              end: SvgPoint(x.toDouble(), y.toDouble()),
              id: nextEdgeId++,
            ),
          );
        }
      }
    }
    return edges;
  }

  List<List<SvgPoint>> _traceRasterLoops(
    List<_RasterEdge> edges, {
    required bool preservePixels,
  }) {
    final outgoingEdges = <String, List<_RasterEdge>>{};
    for (final edge in edges) {
      outgoingEdges.putIfAbsent(_pointKey(edge.start), () => []).add(edge);
    }

    final loops = <List<SvgPoint>>[];
    final visitedEdgeIds = <int>{};
    for (final edge in edges) {
      if (visitedEdgeIds.contains(edge.id)) {
        continue;
      }

      final loop = <SvgPoint>[edge.start];
      var currentEdge = edge;
      visitedEdgeIds.add(currentEdge.id);
      loop.add(currentEdge.end);

      while (!_pointsEqual(currentEdge.end, edge.start)) {
        final candidates = outgoingEdges[_pointKey(currentEdge.end)];
        if (candidates == null || candidates.isEmpty) {
          break;
        }
        var nextEdge = const _RasterEdge.empty();
        var bestTurn = double.negativeInfinity;
        for (final candidate in candidates) {
          if (visitedEdgeIds.contains(candidate.id)) continue;
          final dx = currentEdge.end.x - currentEdge.start.x;
          final dy = currentEdge.end.y - currentEdge.start.y;
          final nx = candidate.end.x - candidate.start.x;
          final ny = candidate.end.y - candidate.start.y;
          final turn = math.atan2(dx * ny - dy * nx, dx * nx + dy * ny);
          if (nextEdge.isEmpty || (preservePixels && turn > bestTurn)) {
            nextEdge = candidate;
            bestTurn = turn;
          }
        }
        if (nextEdge.isEmpty) {
          break;
        }
        visitedEdgeIds.add(nextEdge.id);
        loop.add(nextEdge.end);
        currentEdge = nextEdge;
      }

      if (loop.length >= 4 && _pointsEqual(loop.first, loop.last)) {
        loops.add(loop.sublist(0, loop.length - 1));
      }
    }
    return loops;
  }

  String _pointKey(SvgPoint point) {
    return '${point.x.toStringAsFixed(4)},${point.y.toStringAsFixed(4)}';
  }
}

class _StrokeContourGroup {
  const _StrokeContourGroup({
    required this.sourceAllClosed,
    required this.sourceTagName,
    required this.contours,
  });

  final bool sourceAllClosed;
  final String sourceTagName;
  final List<SvgContour> contours;
}

class _PreparedGlyph {
  const _PreparedGlyph({
    required this.symbol,
    required this.svgContent,
    required this.sourceContourPath,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.sourceMinX,
    required this.sourceMinY,
  });

  final IconSymbol symbol;
  final String svgContent;
  final SvgContourPath sourceContourPath;
  final double sourceWidth;
  final double sourceHeight;
  final double sourceMinX;
  final double sourceMinY;
}

class _NormalizationPlan {
  const _NormalizationPlan({
    required this.targetWidth,
    required this.targetHeight,
    required this.referenceLongestSide,
  });

  final double targetWidth;
  final double targetHeight;
  final double referenceLongestSide;
}

class _SizeGroup {
  const _SizeGroup({
    required this.key,
    required this.width,
    required this.height,
    required this.count,
  });

  final String key;
  final double width;
  final double height;
  final int count;

  _SizeGroup copyWith({int? count}) {
    return _SizeGroup(
      key: key,
      width: width,
      height: height,
      count: count ?? this.count,
    );
  }
}

class _RasterEdge {
  const _RasterEdge({required this.start, required this.end, this.id = -1});

  const _RasterEdge.empty()
    : start = const SvgPoint(0, 0),
      end = const SvgPoint(0, 0),
      id = -1;

  final SvgPoint start;
  final SvgPoint end;
  final int id;

  bool get isEmpty => id == -1;
}
