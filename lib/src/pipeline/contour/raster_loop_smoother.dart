import 'dart:math' as math;

import 'contour.dart';

class RasterLoopSmoother {
  const RasterLoopSmoother({
    this.cornerAngleThreshold = 150.0,
    this.douglasPeuckerEpsilon = 0.85,
  });

  final double cornerAngleThreshold;
  final double douglasPeuckerEpsilon;

  SvgContour smooth(List<SvgPoint> rawLoop) {
    final simplifiedLoop = _simplifyClosedLoop(rawLoop);
    if (simplifiedLoop.length < 2) {
      return const SvgContour(segments: [], isClosed: true);
    }
    if (simplifiedLoop.length == 2) {
      return SvgContour(
        isClosed: true,
        segments: [
          SvgContourSegment.line(
            start: simplifiedLoop.first,
            end: simplifiedLoop.last,
          ),
          SvgContourSegment.line(
            start: simplifiedLoop.last,
            end: simplifiedLoop.first,
          ),
        ],
      );
    }

    final classifications = _classifyVertices(simplifiedLoop);
    if (classifications.every((classification) {
      return classification == _VertexClassification.corner;
    })) {
      return _buildLineContour(simplifiedLoop);
    }
    if (classifications.every((classification) {
      return classification == _VertexClassification.smooth;
    })) {
      return _assembleContour(_fitClosedSpline(simplifiedLoop));
    }

    final smoothRuns = _extractRuns(simplifiedLoop, classifications);
    final segments = <SvgContourSegment>[];
    for (final smoothRun in smoothRuns) {
      segments.addAll(_fitRun(smoothRun));
    }
    return _assembleContour(segments);
  }

  SvgContour _buildLineContour(List<SvgPoint> points) {
    final segments = <SvgContourSegment>[];
    for (var index = 0; index < points.length; index += 1) {
      segments.add(
        SvgContourSegment.line(
          start: points[index],
          end: points[(index + 1) % points.length],
        ),
      );
    }
    return SvgContour(segments: segments, isClosed: true);
  }

  List<SvgPoint> _simplifyClosedLoop(List<SvgPoint> points) {
    final withoutAdjacentDuplicates = _removeAdjacentDuplicatePoints(points);
    final withoutCollinearPoints = _removeCollinearPoints(
      withoutAdjacentDuplicates,
    );
    if (withoutCollinearPoints.length <= 3) {
      return withoutCollinearPoints;
    }

    final anchor = withoutCollinearPoints.first;
    final rotated = [...withoutCollinearPoints, anchor];
    final simplifiedOpen = _douglasPeucker(
      rotated,
      epsilon: douglasPeuckerEpsilon,
    );

    final deduped = <SvgPoint>[];
    for (final point in simplifiedOpen) {
      if (deduped.isEmpty || !_pointsEqual(deduped.last, point)) {
        deduped.add(point);
      }
    }
    if (deduped.length > 1 && _pointsEqual(deduped.first, deduped.last)) {
      deduped.removeLast();
    }
    return deduped.length >= 3 ? deduped : withoutCollinearPoints;
  }

  List<SvgPoint> _removeAdjacentDuplicatePoints(List<SvgPoint> points) {
    if (points.length <= 1) {
      return points;
    }

    final deduped = <SvgPoint>[];
    for (final point in points) {
      if (deduped.isEmpty || !_pointsEqual(deduped.last, point)) {
        deduped.add(point);
      }
    }
    if (deduped.length > 1 && _pointsEqual(deduped.first, deduped.last)) {
      deduped.removeLast();
    }
    return deduped;
  }

  List<SvgPoint> _removeCollinearPoints(List<SvgPoint> points) {
    if (points.length <= 3) {
      return points;
    }

    final filtered = <SvgPoint>[];
    for (var index = 0; index < points.length; index += 1) {
      final previous = points[(index - 1 + points.length) % points.length];
      final current = points[index];
      final next = points[(index + 1) % points.length];
      final areaTwice =
          (current.x - previous.x) * (next.y - previous.y) -
          (current.y - previous.y) * (next.x - previous.x);
      if (areaTwice.abs() > 1e-6 || filtered.isEmpty) {
        filtered.add(current);
      }
    }
    return filtered.length >= 3 ? filtered : points;
  }

  List<SvgPoint> _douglasPeucker(
    List<SvgPoint> points, {
    required double epsilon,
  }) {
    if (points.length <= 2) {
      return points;
    }

    var maxDistance = 0.0;
    var splitIndex = 0;
    for (var index = 1; index < points.length - 1; index += 1) {
      final distance = _perpendicularDistance(
        point: points[index],
        lineStart: points.first,
        lineEnd: points.last,
      );
      if (distance > maxDistance) {
        maxDistance = distance;
        splitIndex = index;
      }
    }

    if (maxDistance <= epsilon) {
      return [points.first, points.last];
    }

    final left = _douglasPeucker(
      points.sublist(0, splitIndex + 1),
      epsilon: epsilon,
    );
    final right = _douglasPeucker(points.sublist(splitIndex), epsilon: epsilon);
    return [...left.sublist(0, left.length - 1), ...right];
  }

  double _perpendicularDistance({
    required SvgPoint point,
    required SvgPoint lineStart,
    required SvgPoint lineEnd,
  }) {
    final deltaX = lineEnd.x - lineStart.x;
    final deltaY = lineEnd.y - lineStart.y;
    if (deltaX.abs() < 1e-9 && deltaY.abs() < 1e-9) {
      final distanceX = point.x - lineStart.x;
      final distanceY = point.y - lineStart.y;
      return math.sqrt(distanceX * distanceX + distanceY * distanceY);
    }

    final numerator =
        ((point.x - lineStart.x) * deltaY - (point.y - lineStart.y) * deltaX)
            .abs();
    final denominator = math.sqrt(deltaX * deltaX + deltaY * deltaY);
    return numerator / denominator;
  }

  List<_VertexClassification> _classifyVertices(List<SvgPoint> points) {
    return List<_VertexClassification>.generate(points.length, (index) {
      final previous = points[(index - 1 + points.length) % points.length];
      final current = points[index];
      final next = points[(index + 1) % points.length];
      final angle = _vertexAngleDegrees(
        previous: previous,
        current: current,
        next: next,
      );
      return angle < cornerAngleThreshold
          ? _VertexClassification.corner
          : _VertexClassification.smooth;
    }, growable: false);
  }

  double _vertexAngleDegrees({
    required SvgPoint previous,
    required SvgPoint current,
    required SvgPoint next,
  }) {
    final incomingX = previous.x - current.x;
    final incomingY = previous.y - current.y;
    final outgoingX = next.x - current.x;
    final outgoingY = next.y - current.y;
    final cross = incomingX * outgoingY - incomingY * outgoingX;
    final dot = incomingX * outgoingX + incomingY * outgoingY;
    return math.atan2(cross.abs(), dot) * 180 / math.pi;
  }

  List<_SmoothRun> _extractRuns(
    List<SvgPoint> points,
    List<_VertexClassification> classifications,
  ) {
    final cornerIndices = <int>[];
    for (var index = 0; index < classifications.length; index += 1) {
      if (classifications[index] == _VertexClassification.corner) {
        cornerIndices.add(index);
      }
    }

    final runs = <_SmoothRun>[];
    for (
      var cornerIndexPosition = 0;
      cornerIndexPosition < cornerIndices.length;
      cornerIndexPosition += 1
    ) {
      final startIndex = cornerIndices[cornerIndexPosition];
      final endIndex =
          cornerIndices[(cornerIndexPosition + 1) % cornerIndices.length];
      final smoothPoints = <SvgPoint>[];
      var pointIndex = (startIndex + 1) % points.length;
      while (pointIndex != endIndex) {
        smoothPoints.add(points[pointIndex]);
        pointIndex = (pointIndex + 1) % points.length;
      }
      runs.add(
        _SmoothRun(
          startCorner: points[startIndex],
          smoothPoints: smoothPoints,
          endCorner: points[endIndex],
        ),
      );
    }
    return runs;
  }

  List<SvgContourSegment> _fitRun(_SmoothRun smoothRun) {
    if (smoothRun.smoothPoints.isEmpty) {
      return [
        SvgContourSegment.line(
          start: smoothRun.startCorner,
          end: smoothRun.endCorner,
        ),
      ];
    }

    final runPoints = [
      smoothRun.startCorner,
      ...smoothRun.smoothPoints,
      smoothRun.endCorner,
    ];
    return _fitOpenSpline(runPoints);
  }

  List<SvgContourSegment> _fitOpenSpline(List<SvgPoint> points) {
    final segments = <SvgContourSegment>[];
    for (var index = 0; index < points.length - 1; index += 1) {
      final previous = index == 0 ? points[index] : points[index - 1];
      final start = points[index];
      final end = points[index + 1];
      final next = index + 2 < points.length ? points[index + 2] : end;
      final control1 = SvgPoint(
        start.x + (end.x - previous.x) / 6,
        start.y + (end.y - previous.y) / 6,
      );
      final control2 = SvgPoint(
        end.x - (next.x - start.x) / 6,
        end.y - (next.y - start.y) / 6,
      );
      segments.add(
        SvgContourSegment.cubic(
          start: start,
          control1: control1,
          control2: control2,
          end: end,
        ),
      );
    }
    return segments;
  }

  List<SvgContourSegment> _fitClosedSpline(List<SvgPoint> points) {
    final segments = <SvgContourSegment>[];
    for (var index = 0; index < points.length; index += 1) {
      final previous = points[(index - 1 + points.length) % points.length];
      final start = points[index];
      final end = points[(index + 1) % points.length];
      final next = points[(index + 2) % points.length];
      final control1 = SvgPoint(
        start.x + (end.x - previous.x) / 6,
        start.y + (end.y - previous.y) / 6,
      );
      final control2 = SvgPoint(
        end.x - (next.x - start.x) / 6,
        end.y - (next.y - start.y) / 6,
      );
      segments.add(
        SvgContourSegment.cubic(
          start: start,
          control1: control1,
          control2: control2,
          end: end,
        ),
      );
    }
    return segments;
  }

  SvgContour _assembleContour(List<SvgContourSegment> segments) {
    if (segments.isEmpty) {
      return const SvgContour(segments: [], isClosed: true);
    }

    final contiguousSegments = <SvgContourSegment>[segments.first];
    for (var index = 1; index < segments.length; index += 1) {
      final previous = contiguousSegments.last;
      final current = segments[index];
      if (_pointsEqual(previous.end, current.start)) {
        contiguousSegments.add(current);
        continue;
      }

      contiguousSegments.add(_retargetSegmentStart(current, previous.end));
    }

    final first = contiguousSegments.first;
    final last = contiguousSegments.last;
    if (!_pointsEqual(last.end, first.start)) {
      contiguousSegments[contiguousSegments.length - 1] = _retargetSegmentEnd(
        last,
        first.start,
      );
    }

    return SvgContour(segments: contiguousSegments, isClosed: true);
  }

  SvgContourSegment _retargetSegmentStart(
    SvgContourSegment segment,
    SvgPoint newStart,
  ) {
    switch (segment.type) {
      case SvgContourSegmentType.line:
        return SvgContourSegment.line(start: newStart, end: segment.end);
      case SvgContourSegmentType.cubic:
        return SvgContourSegment.cubic(
          start: newStart,
          control1: segment.control1!,
          control2: segment.control2!,
          end: segment.end,
        );
      case SvgContourSegmentType.quadratic:
        return SvgContourSegment.quadratic(
          start: newStart,
          control1: segment.control1!,
          end: segment.end,
        );
      case SvgContourSegmentType.arc:
        return SvgContourSegment.arc(
          start: newStart,
          end: segment.end,
          rx: segment.rx!,
          ry: segment.ry!,
          xAxisRotation: segment.xAxisRotation!,
          largeArc: segment.largeArc!,
          sweep: segment.sweep!,
        );
    }
  }

  SvgContourSegment _retargetSegmentEnd(
    SvgContourSegment segment,
    SvgPoint newEnd,
  ) {
    switch (segment.type) {
      case SvgContourSegmentType.line:
        return SvgContourSegment.line(start: segment.start, end: newEnd);
      case SvgContourSegmentType.cubic:
        return SvgContourSegment.cubic(
          start: segment.start,
          control1: segment.control1!,
          control2: segment.control2!,
          end: newEnd,
        );
      case SvgContourSegmentType.quadratic:
        return SvgContourSegment.quadratic(
          start: segment.start,
          control1: segment.control1!,
          end: newEnd,
        );
      case SvgContourSegmentType.arc:
        return SvgContourSegment.arc(
          start: segment.start,
          end: newEnd,
          rx: segment.rx!,
          ry: segment.ry!,
          xAxisRotation: segment.xAxisRotation!,
          largeArc: segment.largeArc!,
          sweep: segment.sweep!,
        );
    }
  }

  bool _pointsEqual(SvgPoint first, SvgPoint second) {
    return (first.x - second.x).abs() < 1e-9 &&
        (first.y - second.y).abs() < 1e-9;
  }
}

enum _VertexClassification { corner, smooth }

class _SmoothRun {
  const _SmoothRun({
    required this.startCorner,
    required this.smoothPoints,
    required this.endCorner,
  });

  final SvgPoint startCorner;
  final List<SvgPoint> smoothPoints;
  final SvgPoint endCorner;
}
