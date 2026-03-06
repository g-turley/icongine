import 'dart:typed_data';
import 'dart:math' as math;

import '../svg/contour.dart';
import 'cff.dart';
import 'type2_charstring_encoder.dart';

/// A [CffGlyphProgramStrategy] that generates Type2 charstring programs
/// from actual [SvgContourPath] outline data.
///
/// Each glyph's contour path is looked up by its glyph index in the
/// [contourPaths] list provided at construction time. The strategy
/// converts contour segments (moveto, lineto, cubic curveto) into
/// relative Type2 charstring operators.
class ContourCffGlyphProgramStrategy implements CffGlyphProgramStrategy {
  ContourCffGlyphProgramStrategy({
    required this.contourPaths,
    this.advanceWidth = 0,
    this.encoder = const Type2CharstringEncoder(),
  });

  /// Contour paths indexed by glyph index (0-based, excluding .notdef).
  final List<SvgContourPath> contourPaths;

  /// Advance width encoded as the first operand in each charstring.
  /// In CFF, this is relative to the Private DICT's nominalWidthX.
  final int advanceWidth;

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
    final contourPath = contourPaths[glyphIndex];

    var currentX = 0.0;
    var currentY = 0.0;
    var isFirstOperator = true;

    for (final contour in contourPath.contours) {
      if (contour.segments.isEmpty) {
        continue;
      }

      final firstSegment = contour.segments.first;
      final moveToX = firstSegment.start.x;
      final moveToY = firstSegment.start.y;
      final targetMoveToX = moveToX.round();
      final targetMoveToY = moveToY.round();
      final deltaX = targetMoveToX - currentX.round();
      final deltaY = targetMoveToY - currentY.round();

      if (isFirstOperator) {
        // Encode advance width before the very first operator.
        encoder.writeNumber(program, advanceWidth);
        isFirstOperator = false;
      }

      encoder.writeNumber(program, deltaX);
      encoder.writeNumber(program, deltaY);
      program.add([Type2CharstringEncoder.operatorRmoveto]);
      currentX = targetMoveToX.toDouble();
      currentY = targetMoveToY.toDouble();

      for (final segment in contour.segments) {
        switch (segment.type) {
          case SvgContourSegmentType.line:
            final lineEnd = _emitLineTo(program, segment, currentX, currentY);
            currentX = lineEnd.$1;
            currentY = lineEnd.$2;

          case SvgContourSegmentType.cubic:
            final curveEnd = _emitCubicCurveTo(
              program,
              segment,
              currentX,
              currentY,
            );
            currentX = curveEnd.$1;
            currentY = curveEnd.$2;

          case SvgContourSegmentType.quadratic:
            // Promote quadratic to cubic for Type2 compatibility.
            final quadEnd = _emitQuadraticAsCubic(
              program,
              segment,
              currentX,
              currentY,
            );
            currentX = quadEnd.$1;
            currentY = quadEnd.$2;

          case SvgContourSegmentType.arc:
            final arcEnd = _emitArcAsLines(
              program,
              segment,
              currentX,
              currentY,
            );
            currentX = arcEnd.$1;
            currentY = arcEnd.$2;
            break;
        }
      }
      // Type2 does not have an explicit closepath operator.
      // Contours are closed implicitly by the next rmoveto or endchar.
    }

    program.add([Type2CharstringEncoder.operatorEndchar]);
    return program.takeBytes();
  }

  (double, double) _emitLineTo(
    BytesBuilder program,
    SvgContourSegment segment,
    double currentX,
    double currentY,
  ) {
    final currentXInt = currentX.round();
    final currentYInt = currentY.round();
    final targetX = segment.end.x.round();
    final targetY = segment.end.y.round();
    final deltaX = targetX - currentXInt;
    final deltaY = targetY - currentYInt;
    encoder.writeNumber(program, deltaX);
    encoder.writeNumber(program, deltaY);
    program.add([Type2CharstringEncoder.operatorRlineto]);
    return (targetX.toDouble(), targetY.toDouble());
  }

  (double, double) _emitCubicCurveTo(
    BytesBuilder program,
    SvgContourSegment segment,
    double currentX,
    double currentY,
  ) {
    return _emitCubicCurveToPoints(
      program: program,
      currentX: currentX,
      currentY: currentY,
      control1X: segment.control1!.x,
      control1Y: segment.control1!.y,
      control2X: segment.control2!.x,
      control2Y: segment.control2!.y,
      endX: segment.end.x,
      endY: segment.end.y,
    );
  }

  /// Converts a quadratic bezier to a cubic bezier for Type2 encoding.
  ///
  /// Cubic control points from quadratic control point Q:
  ///   CP1 = start + 2/3 * (Q - start)
  ///   CP2 = end + 2/3 * (Q - end)
  (double, double) _emitQuadraticAsCubic(
    BytesBuilder program,
    SvgContourSegment segment,
    double currentX,
    double currentY,
  ) {
    final quadControlX = segment.control1!.x;
    final quadControlY = segment.control1!.y;

    final cubicControl1X =
        segment.start.x + (2.0 / 3.0) * (quadControlX - segment.start.x);
    final cubicControl1Y =
        segment.start.y + (2.0 / 3.0) * (quadControlY - segment.start.y);
    final cubicControl2X =
        segment.end.x + (2.0 / 3.0) * (quadControlX - segment.end.x);
    final cubicControl2Y =
        segment.end.y + (2.0 / 3.0) * (quadControlY - segment.end.y);

    return _emitCubicCurveToPoints(
      program: program,
      currentX: currentX,
      currentY: currentY,
      control1X: cubicControl1X,
      control1Y: cubicControl1Y,
      control2X: cubicControl2X,
      control2Y: cubicControl2Y,
      endX: segment.end.x,
      endY: segment.end.y,
    );
  }

  (double, double) _emitArcAsLines(
    BytesBuilder program,
    SvgContourSegment segment,
    double currentX,
    double currentY,
  ) {
    final points = _flattenArcSegment(segment);
    var cursorX = currentX;
    var cursorY = currentY;
    for (final point in points) {
      final cursorXInt = cursorX.round();
      final cursorYInt = cursorY.round();
      final targetX = point.x.round();
      final targetY = point.y.round();
      final deltaX = targetX - cursorXInt;
      final deltaY = targetY - cursorYInt;
      if (deltaX == 0 && deltaY == 0) continue;

      encoder.writeNumber(program, deltaX);
      encoder.writeNumber(program, deltaY);
      program.add([Type2CharstringEncoder.operatorRlineto]);
      cursorX = targetX.toDouble();
      cursorY = targetY.toDouble();
    }
    return (cursorX, cursorY);
  }

  (double, double) _emitCubicCurveToPoints({
    required BytesBuilder program,
    required double currentX,
    required double currentY,
    required double control1X,
    required double control1Y,
    required double control2X,
    required double control2Y,
    required double endX,
    required double endY,
  }) {
    final currentXInt = currentX.round();
    final currentYInt = currentY.round();
    final control1XInt = control1X.round();
    final control1YInt = control1Y.round();
    final control2XInt = control2X.round();
    final control2YInt = control2Y.round();
    final endXInt = endX.round();
    final endYInt = endY.round();

    final deltaControl1X = control1XInt - currentXInt;
    final deltaControl1Y = control1YInt - currentYInt;
    final deltaControl2X = control2XInt - control1XInt;
    final deltaControl2Y = control2YInt - control1YInt;
    final deltaEndX = endXInt - control2XInt;
    final deltaEndY = endYInt - control2YInt;

    encoder.writeNumber(program, deltaControl1X);
    encoder.writeNumber(program, deltaControl1Y);
    encoder.writeNumber(program, deltaControl2X);
    encoder.writeNumber(program, deltaControl2Y);
    encoder.writeNumber(program, deltaEndX);
    encoder.writeNumber(program, deltaEndY);
    program.add([Type2CharstringEncoder.operatorRrcurveto]);

    return (endXInt.toDouble(), endYInt.toDouble());
  }

  List<SvgPoint> _flattenArcSegment(SvgContourSegment segment) {
    final params = _arcCenterParams(segment);
    if (params == null) {
      return [segment.end];
    }

    final stepCount = math.max(
      6,
      ((params.deltaTheta.abs() / (2 * math.pi)) * 24).ceil(),
    );
    final points = <SvgPoint>[];
    for (var step = 1; step <= stepCount; step += 1) {
      final t = step / stepCount;
      final theta = params.theta1 + params.deltaTheta * t;
      final cosTheta = math.cos(theta);
      final sinTheta = math.sin(theta);
      points.add(
        SvgPoint(
          params.cosPhi * params.rx * cosTheta -
              params.sinPhi * params.ry * sinTheta +
              params.cx,
          params.sinPhi * params.rx * cosTheta +
              params.cosPhi * params.ry * sinTheta +
              params.cy,
        ),
      );
    }
    return points;
  }

  _ArcCenterParams? _arcCenterParams(SvgContourSegment segment) {
    final rxInput = segment.rx ?? 0;
    final ryInput = segment.ry ?? 0;
    if (rxInput <= 0 || ryInput <= 0) return null;

    final start = segment.start;
    final end = segment.end;
    final phi = (segment.xAxisRotation ?? 0) * (math.pi / 180);
    final cosPhi = math.cos(phi);
    final sinPhi = math.sin(phi);

    final dx2 = (start.x - end.x) / 2;
    final dy2 = (start.y - end.y) / 2;
    final x1Prime = cosPhi * dx2 + sinPhi * dy2;
    final y1Prime = -sinPhi * dx2 + cosPhi * dy2;

    var rx = rxInput.abs();
    var ry = ryInput.abs();
    final lambda =
        (x1Prime * x1Prime) / (rx * rx) + (y1Prime * y1Prime) / (ry * ry);
    if (lambda > 1) {
      final scale = math.sqrt(lambda);
      rx *= scale;
      ry *= scale;
    }

    final rxSq = rx * rx;
    final rySq = ry * ry;
    final x1PrimeSq = x1Prime * x1Prime;
    final y1PrimeSq = y1Prime * y1Prime;
    final denominator = rxSq * y1PrimeSq + rySq * x1PrimeSq;
    if (denominator.abs() < 1e-12) return null;

    final numerator = rxSq * rySq - rxSq * y1PrimeSq - rySq * x1PrimeSq;
    final sign = segment.largeArc == segment.sweep ? -1.0 : 1.0;
    final factor = sign * math.sqrt(math.max(0, numerator / denominator));

    final cxPrime = factor * (rx * y1Prime / ry);
    final cyPrime = factor * (-ry * x1Prime / rx);
    final cx = cosPhi * cxPrime - sinPhi * cyPrime + (start.x + end.x) / 2;
    final cy = sinPhi * cxPrime + cosPhi * cyPrime + (start.y + end.y) / 2;

    final ux = (x1Prime - cxPrime) / rx;
    final uy = (y1Prime - cyPrime) / ry;
    final vx = (-x1Prime - cxPrime) / rx;
    final vy = (-y1Prime - cyPrime) / ry;
    final theta1 = math.atan2(uy, ux);

    var deltaTheta = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);
    final sweepFlag = segment.sweep ?? false;
    if (!sweepFlag && deltaTheta > 0) {
      deltaTheta -= 2 * math.pi;
    } else if (sweepFlag && deltaTheta < 0) {
      deltaTheta += 2 * math.pi;
    }

    return _ArcCenterParams(
      cx: cx,
      cy: cy,
      rx: rx,
      ry: ry,
      cosPhi: cosPhi,
      sinPhi: sinPhi,
      theta1: theta1,
      deltaTheta: deltaTheta,
    );
  }
}

class _ArcCenterParams {
  const _ArcCenterParams({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.cosPhi,
    required this.sinPhi,
    required this.theta1,
    required this.deltaTheta,
  });

  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final double cosPhi;
  final double sinPhi;
  final double theta1;
  final double deltaTheta;
}
