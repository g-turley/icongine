class SvgContourPath {
  const SvgContourPath({required this.contours});

  final List<SvgContour> contours;
}

class SvgContour {
  const SvgContour({required this.segments, required this.isClosed});

  final List<SvgContourSegment> segments;
  final bool isClosed;
}

class SvgPoint {
  const SvgPoint(this.x, this.y);

  final double x;
  final double y;
}

enum SvgContourSegmentType {
  line,
  cubic,
  quadratic,
  arc;

  /// Whether this is a curve type (cubic, quadratic, or arc) as opposed to a
  /// straight line.
  bool get isCurve => this != line;
}

class SvgContourSegment {
  const SvgContourSegment._({
    required this.type,
    required this.start,
    required this.end,
    this.control1,
    this.control2,
    this.rx,
    this.ry,
    this.xAxisRotation,
    this.largeArc,
    this.sweep,
  });

  factory SvgContourSegment.line({
    required SvgPoint start,
    required SvgPoint end,
  }) {
    return SvgContourSegment._(
      type: SvgContourSegmentType.line,
      start: start,
      end: end,
    );
  }

  factory SvgContourSegment.cubic({
    required SvgPoint start,
    required SvgPoint control1,
    required SvgPoint control2,
    required SvgPoint end,
  }) {
    return SvgContourSegment._(
      type: SvgContourSegmentType.cubic,
      start: start,
      end: end,
      control1: control1,
      control2: control2,
    );
  }

  factory SvgContourSegment.quadratic({
    required SvgPoint start,
    required SvgPoint control1,
    required SvgPoint end,
  }) {
    return SvgContourSegment._(
      type: SvgContourSegmentType.quadratic,
      start: start,
      end: end,
      control1: control1,
    );
  }

  factory SvgContourSegment.arc({
    required SvgPoint start,
    required SvgPoint end,
    required double rx,
    required double ry,
    required double xAxisRotation,
    required bool largeArc,
    required bool sweep,
  }) {
    return SvgContourSegment._(
      type: SvgContourSegmentType.arc,
      start: start,
      end: end,
      rx: rx,
      ry: ry,
      xAxisRotation: xAxisRotation,
      largeArc: largeArc,
      sweep: sweep,
    );
  }

  final SvgContourSegmentType type;
  final SvgPoint start;
  final SvgPoint end;
  final SvgPoint? control1;
  final SvgPoint? control2;
  final double? rx;
  final double? ry;
  final double? xAxisRotation;
  final bool? largeArc;
  final bool? sweep;
}
