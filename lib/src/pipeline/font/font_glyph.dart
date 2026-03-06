import '../contour/contour.dart';

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

  /// Stable Dart identifier for the generated icon.
  final String name;

  /// Unicode code point assigned to the glyph.
  final int codePoint;

  /// Optional glyph ID used by low-level font writers.
  final int glyphId;

  /// Source SVG width before scaling into font space.
  final double sourceWidth;

  /// Source SVG height before scaling into font space.
  final double sourceHeight;

  /// Minimum X coordinate of the source geometry.
  final double sourceMinX;

  /// Minimum Y coordinate of the source geometry.
  final double sourceMinY;

  /// Original SVG path data when available.
  final String? sourceSvgPath;

  /// Original SVG document markup when available.
  final String? sourceSvgDocument;

  /// Source contour path before font-space transforms.
  final SvgContourPath? sourceContourPath;

  /// Final contour path after compilation into font space.
  final SvgContourPath? compiledContourPath;

  /// Whether normalization changed this glyph's geometry.
  final bool normalizationScaled;
}
