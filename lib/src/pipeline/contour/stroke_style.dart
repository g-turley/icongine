import 'dart:math' as math;

enum SvgStrokeLineCap { butt, round, square }

enum SvgStrokeLineJoin { miter, round, bevel }

enum SvgFillRule { nonzero, evenodd }

class SvgStrokeProperties {
  const SvgStrokeProperties({
    required this.strokeWidthPixels,
    this.lineCap = SvgStrokeLineCap.butt,
    this.lineJoin = SvgStrokeLineJoin.miter,
    this.miterLimit = 4,
    required this.hasVisibleFill,
  });

  final double strokeWidthPixels;
  final SvgStrokeLineCap lineCap;
  final SvgStrokeLineJoin lineJoin;
  final double miterLimit;
  final bool hasVisibleFill;

  bool get isStrokeOnly => !hasVisibleFill && strokeWidthPixels > 0;
}

class SvgClipRect {
  const SvgClipRect({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  bool get isValid => maxX > minX && maxY > minY;

  SvgClipRect? intersect(SvgClipRect other) {
    final overlapMinX = math.max(minX, other.minX);
    final overlapMinY = math.max(minY, other.minY);
    final overlapMaxX = math.min(maxX, other.maxX);
    final overlapMaxY = math.min(maxY, other.maxY);
    if (overlapMaxX <= overlapMinX || overlapMaxY <= overlapMinY) {
      return null;
    }
    return SvgClipRect(
      minX: overlapMinX,
      minY: overlapMinY,
      maxX: overlapMaxX,
      maxY: overlapMaxY,
    );
  }
}
