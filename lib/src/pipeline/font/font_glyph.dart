import '../svg/contour.dart';

/// Format-neutral glyph contract produced by compile and consumed by font writers.
class FontGlyph {
  const FontGlyph({
    required this.name,
    required this.codePoint,
    this.glyphId = 0,
    this.sourceWidth = 0,
    this.sourceHeight = 0,
    this.sourceMinX = 0,
    this.sourceMinY = 0,
    this.sourceSvgPath,
    this.sourceSvgDocument,
    this.sourceContourPath,
    this.compiledContourPath,
    this.normalizationScaled = false,
  });

  final String name;
  final int codePoint;
  final int glyphId;
  final double sourceWidth;
  final double sourceHeight;
  final double sourceMinX;
  final double sourceMinY;
  final String? sourceSvgPath;
  final String? sourceSvgDocument;
  final SvgContourPath? sourceContourPath;
  final SvgContourPath? compiledContourPath;
  final bool normalizationScaled;
}
