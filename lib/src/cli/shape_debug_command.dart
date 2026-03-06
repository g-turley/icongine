import 'dart:io';
import 'dart:math' as math;

import '../../icongine.dart';
import '../pipeline/svg/contour_flattener.dart';

class ShapeDebugCommand {
  const ShapeDebugCommand();

  int run(
    List<String> args, {
    required void Function(String line) stdoutWriteln,
    required void Function(String line) stderrWriteln,
  }) {
    if (args.isEmpty || args.first == '-h' || args.first == '--help') {
      _writeUsage(stdoutWriteln);
      return args.isEmpty ? 64 : 0;
    }

    final input = args.first;
    final svgFile = _resolveSvgFile(input);
    if (svgFile == null || !svgFile.existsSync()) {
      stderrWriteln('Shape not found: $input');
      return 66;
    }

    final svgContent = svgFile.readAsStringSync();
    const extractor = SvgDocumentPathExtractor();
    const parser = SvgPathDataParser();
    const converter = StrokeToFillConverter();
    const corrector = WindingCorrector();

    final document = extractor.extract(svgContent);
    stdoutWriteln('shape: ${svgFile.path}');
    stdoutWriteln(
      'viewport: ${document.viewport?.width ?? 'none'} x ${document.viewport?.height ?? 'none'}',
    );
    stdoutWriteln('path entries: ${document.pathEntries.length}');
    stdoutWriteln('');

    final fillContours = <SvgContour>[];
    final openStrokeContours = <SvgContour>[];
    final closedStrokeContours = <SvgContour>[];

    for (var index = 0; index < document.pathEntries.length; index += 1) {
      final entry = document.pathEntries[index];
      final parsed = parser.parse(entry.pathData);
      final transformed = _applyTransform(parsed, entry.transformMatrix);
      final stroke = entry.strokeProperties;
      final allOpen =
          transformed.contours.isNotEmpty &&
          transformed.contours.every((contour) => !contour.isClosed);
      final allClosed =
          transformed.contours.isNotEmpty &&
          transformed.contours.every((contour) => contour.isClosed);

      stdoutWriteln(
        '[entry $index] tag=${entry.sourceTagName} '
        'stroke=${stroke != null ? 'yes' : 'no'} '
        'strokeOnly=${stroke?.isStrokeOnly ?? false} '
        'allOpen=$allOpen allClosed=$allClosed '
        'inputContours=${transformed.contours.length}',
      );
      for (
        var inputIndex = 0;
        inputIndex < transformed.contours.length;
        inputIndex += 1
      ) {
        final inputContour = transformed.contours[inputIndex];
        final area = _signedArea(inputContour);
        stdoutWriteln(
          '  input[$inputIndex] closed=${inputContour.isClosed} '
          'segments=${inputContour.segments.length} '
          'area=${area.toStringAsFixed(2)} sign=${_sign(area)}',
        );
      }

      final shouldEmitFill = stroke == null || stroke.hasVisibleFill;
      if (shouldEmitFill) {
        fillContours.addAll(_closeContoursForFill(transformed.contours));
      }

      final shouldExpandStroke =
          stroke != null && (stroke.isStrokeOnly || allOpen);
      if (shouldExpandStroke) {
        final expanded = converter.convert(
          sourcePath: transformed,
          strokeProperties: stroke,
        );
        stdoutWriteln(
          '  expandedContours=${expanded.contours.length} '
          'lineJoin=${stroke.lineJoin.name} lineCap=${stroke.lineCap.name}',
        );
        for (
          var contourIndex = 0;
          contourIndex < expanded.contours.length;
          contourIndex += 1
        ) {
          final contour = expanded.contours[contourIndex];
          final area = _signedArea(contour);
          final bounds = _bounds(contour);
          stdoutWriteln(
            '    contour[$contourIndex] '
            'closed=${contour.isClosed} '
            'segments=${contour.segments.length} '
            'area=${area.toStringAsFixed(2)} '
            'sign=${_sign(area)} '
            'selfX=${_countSelfIntersections(contour)} '
            'minAngle=${_minVertexAngleDegrees(contour).toStringAsFixed(1)} '
            'bbox=[${bounds.minX.toStringAsFixed(2)},${bounds.minY.toStringAsFixed(2)}]-'
            '[${bounds.maxX.toStringAsFixed(2)},${bounds.maxY.toStringAsFixed(2)}]',
          );
        }
        if (allClosed) {
          closedStrokeContours.addAll(expanded.contours);
        } else {
          openStrokeContours.addAll(expanded.contours);
        }
      }
    }

    final correctedFills = corrector.correct(
      SvgContourPath(contours: fillContours),
    );

    stdoutWriteln('');
    stdoutWriteln('summary:');
    stdoutWriteln('  fillContours=${fillContours.length}');
    stdoutWriteln('  correctedFills=${correctedFills.contours.length}');
    stdoutWriteln('  openStrokeContours=${openStrokeContours.length}');
    stdoutWriteln('  closedStrokeContours=${closedStrokeContours.length}');

    if (openStrokeContours.isNotEmpty || closedStrokeContours.isNotEmpty) {
      stdoutWriteln('');
      stdoutWriteln('overlap candidates (opposite sign + bbox overlap):');
      final allStrokes = [...openStrokeContours, ...closedStrokeContours];
      var found = false;
      for (
        var firstIndex = 0;
        firstIndex < allStrokes.length;
        firstIndex += 1
      ) {
        for (
          var secondIndex = firstIndex + 1;
          secondIndex < allStrokes.length;
          secondIndex += 1
        ) {
          final first = allStrokes[firstIndex];
          final second = allStrokes[secondIndex];
          final firstArea = _signedArea(first);
          final secondArea = _signedArea(second);
          final firstSign = _sign(firstArea);
          final secondSign = _sign(secondArea);
          if (firstSign == 0 || secondSign == 0 || firstSign == secondSign) {
            continue;
          }
          if (!_overlap(_bounds(first), _bounds(second))) {
            continue;
          }
          found = true;
          stdoutWriteln(
            '  [$firstIndex,$secondIndex] signs=($firstSign,$secondSign) '
            'areas=(${firstArea.toStringAsFixed(1)},${secondArea.toStringAsFixed(1)})',
          );
        }
      }
      if (!found) {
        stdoutWriteln('  none');
      }
    }

    if (closedStrokeContours.length == 2 && openStrokeContours.isNotEmpty) {
      final groupBounds = _mergeBounds(
        _bounds(closedStrokeContours[0]),
        _bounds(closedStrokeContours[1]),
      );
      var currentScore = 0;
      var flippedScore = 0;
      for (final openContour in openStrokeContours) {
        final sampleBounds = _intersectBounds(
          _bounds(openContour),
          groupBounds,
        );
        if (sampleBounds == null) {
          continue;
        }
        final openSign = _sign(_signedArea(openContour));
        currentScore += _openStrokeCompatibilityScore(
          openStrokeContour: openContour,
          openSign: openSign,
          ringContours: closedStrokeContours,
          sampleBounds: sampleBounds,
          flipped: false,
        );
        flippedScore += _openStrokeCompatibilityScore(
          openStrokeContour: openContour,
          openSign: openSign,
          ringContours: closedStrokeContours,
          sampleBounds: sampleBounds,
          flipped: true,
        );
      }
      stdoutWriteln('');
      stdoutWriteln(
        'closed/open compatibility score: current=$currentScore flipped=$flippedScore',
      );
    }

    stdoutWriteln('');
    stdoutWriteln('compiler sourceContourPath (post-merge):');
    final compiledShape = _compileShape(svgFile);
    final mergedContours = compiledShape.sourceContourPath.contours;
    stdoutWriteln('  contours=${mergedContours.length}');
    for (var index = 0; index < mergedContours.length; index += 1) {
      final contour = mergedContours[index];
      final area = _signedArea(contour);
      final bounds = _bounds(contour);
      stdoutWriteln(
        '  [$index] '
        'segments=${contour.segments.length} '
        'area=${area.toStringAsFixed(2)} '
        'sign=${_sign(area)} '
        'selfX=${_countSelfIntersections(contour)} '
        'minAngle=${_minVertexAngleDegrees(contour).toStringAsFixed(1)} '
        'bbox=[${bounds.minX.toStringAsFixed(2)},${bounds.minY.toStringAsFixed(2)}]-'
        '[${bounds.maxX.toStringAsFixed(2)},${bounds.maxY.toStringAsFixed(2)}]',
      );
    }
    _printOppositeSignOverlaps(mergedContours, stdoutWriteln, indent: '  ');
    return 0;
  }

  void _writeUsage(void Function(String line) stdoutWriteln) {
    stdoutWriteln('icongine debug-shape');
    stdoutWriteln('Usage: icongine debug-shape <shape-name-or-svg-path>');
    stdoutWriteln('');
    stdoutWriteln(
      'Resolves either a direct SVG path or test/test_shapes/<name>.svg and prints shape diagnostics.',
    );
  }
}

File? _resolveSvgFile(String input) {
  final directFile = File(input);
  if (directFile.existsSync()) {
    return directFile;
  }
  final candidate = File('test/test_shapes/$input.svg');
  if (candidate.existsSync()) {
    return candidate;
  }
  return null;
}

_CompiledShape _compileShape(File svgFile) {
  final compiler = const SvgFontCompiler();
  final result = compiler.compile(
    config: GenerationConfig(
      packageName: 'debug_shape',
      inputDir: 'test/test_shapes',
      outClassFile: 'build/debug_shape.dart',
      outFontFile: 'build/debug_shape.otf',
      fontFormat: FontFormat.otf,
    ),
    symbols: [
      IconSymbol(
        file: IconFile(
          absolutePath: svgFile.absolute.path,
          relativePath: svgFile.uri.pathSegments.last,
        ),
        name: svgFile.uri.pathSegments.last
            .replaceFirst(RegExp(r'\.svg$'), '')
            .toLowerCamel(),
      ),
    ],
  );
  final glyph = result.glyphs.single;
  final sourceContourPath =
      glyph.sourceContourPath ?? glyph.compiledContourPath;
  if (sourceContourPath == null) {
    throw StateError(
      'Compiled glyph "${glyph.name}" did not include source or compiled contours.',
    );
  }
  return _CompiledShape(sourceContourPath: sourceContourPath);
}

SvgContourPath _applyTransform(
  SvgContourPath contourPath,
  SvgTransformMatrix? transformMatrix,
) {
  if (transformMatrix == null) {
    return contourPath;
  }
  final contours = contourPath.contours
      .map((contour) => _transformContour(contour, transformMatrix))
      .toList();
  return SvgContourPath(contours: contours);
}

SvgContour _transformContour(SvgContour contour, SvgTransformMatrix matrix) {
  final transformed = contour.segments
      .map((segment) => _transformSegment(segment, matrix))
      .toList();
  return SvgContour(segments: transformed, isClosed: contour.isClosed);
}

SvgContourSegment _transformSegment(
  SvgContourSegment segment,
  SvgTransformMatrix matrix,
) {
  final start = matrix.applyToPoint(segment.start);
  final end = matrix.applyToPoint(segment.end);
  switch (segment.type) {
    case SvgContourSegmentType.line:
      return SvgContourSegment.line(start: start, end: end);
    case SvgContourSegmentType.cubic:
      return SvgContourSegment.cubic(
        start: start,
        control1: matrix.applyToPoint(segment.control1!),
        control2: matrix.applyToPoint(segment.control2!),
        end: end,
      );
    case SvgContourSegmentType.quadratic:
      return SvgContourSegment.quadratic(
        start: start,
        control1: matrix.applyToPoint(segment.control1!),
        end: end,
      );
    case SvgContourSegmentType.arc:
      final rotationDegrees = math.atan2(matrix.b, matrix.a) * (180 / math.pi);
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

List<SvgContour> _closeContoursForFill(List<SvgContour> contours) {
  return contours
      .map(
        (contour) => contour.isClosed
            ? contour
            : SvgContour(segments: contour.segments, isClosed: true),
      )
      .toList();
}

double _signedArea(SvgContour contour) {
  final polyline = flattenContourToPolyline(contour, curveSteps: 16);
  if (polyline.length < 3) {
    return 0;
  }
  var area = 0.0;
  final lastIndex = polyline.length - 1;
  for (var index = 0; index < lastIndex; index += 1) {
    final current = polyline[index];
    final next = polyline[index + 1];
    area += (current.x * next.y) - (next.x * current.y);
  }
  if (contour.isClosed) {
    final first = polyline.first;
    final last = polyline.last;
    area += (last.x * first.y) - (first.x * last.y);
  }
  return area / 2;
}

int _sign(double value) {
  const epsilon = 1e-6;
  if (value > epsilon) {
    return 1;
  }
  if (value < -epsilon) {
    return -1;
  }
  return 0;
}

_Bounds _bounds(SvgContour contour) {
  final points = flattenContourToPolyline(contour, curveSteps: 16);
  var minX = points.first.x;
  var minY = points.first.y;
  var maxX = minX;
  var maxY = minY;
  for (final point in points.skip(1)) {
    minX = math.min(minX, point.x);
    minY = math.min(minY, point.y);
    maxX = math.max(maxX, point.x);
    maxY = math.max(maxY, point.y);
  }
  return _Bounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

bool _overlap(_Bounds first, _Bounds second) {
  return first.minX <= second.maxX &&
      first.maxX >= second.minX &&
      first.minY <= second.maxY &&
      first.maxY >= second.minY;
}

int _countSelfIntersections(SvgContour contour) {
  final points = flattenContourToPolyline(contour, curveSteps: 16);
  if (points.length < 4) {
    return 0;
  }

  var intersections = 0;
  final lastSegmentIndex = contour.isClosed ? points.length : points.length - 1;
  for (var firstIndex = 0; firstIndex < lastSegmentIndex - 1; firstIndex += 1) {
    final firstStart = points[firstIndex];
    final firstEnd = points[(firstIndex + 1) % points.length];
    for (
      var secondIndex = firstIndex + 1;
      secondIndex < lastSegmentIndex;
      secondIndex += 1
    ) {
      if ((secondIndex - firstIndex).abs() <= 1) {
        continue;
      }
      if (contour.isClosed &&
          firstIndex == 0 &&
          secondIndex == lastSegmentIndex - 1) {
        continue;
      }

      final secondStart = points[secondIndex];
      final secondEnd = points[(secondIndex + 1) % points.length];
      if (_segmentsIntersect(firstStart, firstEnd, secondStart, secondEnd)) {
        intersections += 1;
      }
    }
  }
  return intersections;
}

bool _segmentsIntersect(
  SvgPoint startA,
  SvgPoint endA,
  SvgPoint startB,
  SvgPoint endB,
) {
  final d1 = _direction(startB, endB, startA);
  final d2 = _direction(startB, endB, endA);
  final d3 = _direction(startA, endA, startB);
  final d4 = _direction(startA, endA, endB);

  if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
    return true;
  }

  return (d1 == 0 && _onSegment(startB, endB, startA)) ||
      (d2 == 0 && _onSegment(startB, endB, endA)) ||
      (d3 == 0 && _onSegment(startA, endA, startB)) ||
      (d4 == 0 && _onSegment(startA, endA, endB));
}

double _direction(SvgPoint start, SvgPoint end, SvgPoint point) {
  return ((point.x - start.x) * (end.y - start.y)) -
      ((end.x - start.x) * (point.y - start.y));
}

bool _onSegment(SvgPoint start, SvgPoint end, SvgPoint point) {
  return point.x >= math.min(start.x, end.x) &&
      point.x <= math.max(start.x, end.x) &&
      point.y >= math.min(start.y, end.y) &&
      point.y <= math.max(start.y, end.y);
}

double _minVertexAngleDegrees(SvgContour contour) {
  final points = flattenContourToPolyline(contour, curveSteps: 16);
  if (points.length < 3) {
    return 180;
  }

  final minIndex = contour.isClosed ? points.length : points.length - 1;
  var minAngle = 180.0;
  for (var index = 1; index < minIndex - 1; index += 1) {
    final previous = points[index - 1];
    final current = points[index];
    final next = points[index + 1];
    final angle = _vertexAngleDegrees(previous, current, next);
    minAngle = math.min(minAngle, angle);
  }

  if (contour.isClosed) {
    minAngle = math.min(
      minAngle,
      _vertexAngleDegrees(points[points.length - 2], points.first, points[1]),
    );
    minAngle = math.min(
      minAngle,
      _vertexAngleDegrees(
        points[points.length - 3],
        points[points.length - 2],
        points.first,
      ),
    );
  }
  return minAngle;
}

double _vertexAngleDegrees(SvgPoint previous, SvgPoint current, SvgPoint next) {
  final ax = previous.x - current.x;
  final ay = previous.y - current.y;
  final bx = next.x - current.x;
  final by = next.y - current.y;
  final magnitudeA = math.sqrt((ax * ax) + (ay * ay));
  final magnitudeB = math.sqrt((bx * bx) + (by * by));
  if (magnitudeA == 0 || magnitudeB == 0) {
    return 180;
  }
  final cosine = ((ax * bx) + (ay * by)) / (magnitudeA * magnitudeB);
  final clampedCosine = cosine.clamp(-1.0, 1.0);
  return math.acos(clampedCosine) * 180 / math.pi;
}

_Bounds _mergeBounds(_Bounds first, _Bounds second) {
  return _Bounds(
    minX: math.min(first.minX, second.minX),
    minY: math.min(first.minY, second.minY),
    maxX: math.max(first.maxX, second.maxX),
    maxY: math.max(first.maxY, second.maxY),
  );
}

_Bounds? _intersectBounds(_Bounds first, _Bounds second) {
  final minX = math.max(first.minX, second.minX);
  final minY = math.max(first.minY, second.minY);
  final maxX = math.min(first.maxX, second.maxX);
  final maxY = math.min(first.maxY, second.maxY);
  if (minX > maxX || minY > maxY) {
    return null;
  }
  return _Bounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

int _openStrokeCompatibilityScore({
  required SvgContour openStrokeContour,
  required int openSign,
  required List<SvgContour> ringContours,
  required _Bounds sampleBounds,
  required bool flipped,
}) {
  final samplePoint = SvgPoint(
    (sampleBounds.minX + sampleBounds.maxX) / 2,
    (sampleBounds.minY + sampleBounds.maxY) / 2,
  );
  var score = 0;
  for (var index = 0; index < ringContours.length; index += 1) {
    final ringContour = ringContours[index];
    final ringSign = _sign(_signedArea(ringContour)) * (flipped ? -1 : 1);
    if (ringSign == openSign && _containsPoint(ringContour, samplePoint)) {
      score += 1;
    }
  }
  return score;
}

bool _containsPoint(SvgContour contour, SvgPoint point) {
  final polygon = flattenContourToPolyline(contour, curveSteps: 16);
  var inside = false;
  for (
    var currentIndex = 0, previousIndex = polygon.length - 1;
    currentIndex < polygon.length;
    previousIndex = currentIndex, currentIndex += 1
  ) {
    final current = polygon[currentIndex];
    final previous = polygon[previousIndex];
    final crosses =
        ((current.y > point.y) != (previous.y > point.y)) &&
        (point.x <
            ((previous.x - current.x) * (point.y - current.y)) /
                    (previous.y - current.y) +
                current.x);
    if (crosses) {
      inside = !inside;
    }
  }
  return inside;
}

void _printOppositeSignOverlaps(
  List<SvgContour> contours,
  void Function(String line) stdoutWriteln, {
  required String indent,
}) {
  stdoutWriteln('${indent}opposite-sign overlaps:');
  var found = false;
  for (var firstIndex = 0; firstIndex < contours.length; firstIndex += 1) {
    for (
      var secondIndex = firstIndex + 1;
      secondIndex < contours.length;
      secondIndex += 1
    ) {
      final first = contours[firstIndex];
      final second = contours[secondIndex];
      final firstSign = _sign(_signedArea(first));
      final secondSign = _sign(_signedArea(second));
      if (firstSign == 0 || secondSign == 0 || firstSign == secondSign) {
        continue;
      }
      if (!_overlap(_bounds(first), _bounds(second))) {
        continue;
      }
      found = true;
      stdoutWriteln(
        '$indent[$firstIndex,$secondIndex] signs=($firstSign,$secondSign)',
      );
    }
  }
  if (!found) {
    stdoutWriteln('${indent}none');
  }
}

class _Bounds {
  const _Bounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
}

class _CompiledShape {
  const _CompiledShape({required this.sourceContourPath});

  final SvgContourPath sourceContourPath;
}
