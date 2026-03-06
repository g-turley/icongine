import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../contour/contour.dart';
import '../contour/stroke_style.dart';

class SvgPathEntry {
  const SvgPathEntry({
    required this.pathData,
    required this.sourceTagName,
    required this.fillRule,
    this.strokeProperties,
    this.transformMatrix,
    this.clipRect,
  });

  final String pathData;
  final String sourceTagName;
  final SvgFillRule fillRule;
  final SvgStrokeProperties? strokeProperties;
  final SvgTransformMatrix? transformMatrix;
  final SvgClipRect? clipRect;
}

class SvgDocumentData {
  const SvgDocumentData({required this.pathEntries, required this.viewport});

  final List<SvgPathEntry> pathEntries;
  final SvgDocumentViewport? viewport;
}

class SvgDocumentViewport {
  const SvgDocumentViewport({
    required this.width,
    required this.height,
    this.minX = 0,
    this.minY = 0,
  });

  final double width;
  final double height;
  final double minX;
  final double minY;
}

enum SvgShapeTargetFormat { generic, ttf, otf }

class SvgElementPathContext {
  const SvgElementPathContext({
    required this.tagName,
    required this.attrs,
    required this.targetFormat,
  });

  final String tagName;
  final String attrs;
  final SvgShapeTargetFormat targetFormat;
}

abstract interface class SvgElementPathStrategy {
  String get tagName;

  String? buildPathData({
    required SvgElementPathContext context,
    required SvgAttributeReader attributeReader,
  });
}

class SvgElementPathStrategyRegistry {
  const SvgElementPathStrategyRegistry({
    this.strategies = const [
      SvgPathElementPathStrategy(),
      SvgLineElementPathStrategy(),
      SvgPolylineElementPathStrategy(),
      SvgPolygonElementPathStrategy(),
      SvgRectElementPathStrategy(),
      SvgCircleElementPathStrategy(),
      SvgEllipseElementPathStrategy(),
    ],
  });

  final List<SvgElementPathStrategy> strategies;

  Iterable<SvgElementPathStrategy> strategiesFor(String tagName) sync* {
    for (final strategy in strategies) {
      if (strategy.tagName == tagName) {
        yield strategy;
      }
    }
  }
}

class SvgAttributeReader {
  const SvgAttributeReader();

  String? extractAttribute(String attrs, String name) {
    final pattern = RegExp(
      '(?:^|\\s)$name\\b\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')',
      caseSensitive: false,
      dotAll: true,
    );
    final match = pattern.firstMatch(attrs);
    if (match == null) {
      return null;
    }
    return match.group(1) ?? match.group(2);
  }

  double? extractDoubleAttribute(String attrs, String name) {
    final raw = extractAttribute(attrs, name);
    if (raw == null) return null;
    return double.tryParse(raw);
  }
}

class SvgPathElementPathStrategy implements SvgElementPathStrategy {
  const SvgPathElementPathStrategy();

  @override
  String get tagName => 'path';

  @override
  String? buildPathData({
    required SvgElementPathContext context,
    required SvgAttributeReader attributeReader,
  }) {
    return attributeReader.extractAttribute(context.attrs, 'd');
  }
}

class SvgLineElementPathStrategy implements SvgElementPathStrategy {
  const SvgLineElementPathStrategy();

  @override
  String get tagName => 'line';

  @override
  String? buildPathData({
    required SvgElementPathContext context,
    required SvgAttributeReader attributeReader,
  }) {
    final x1 = attributeReader.extractDoubleAttribute(context.attrs, 'x1') ?? 0;
    final y1 = attributeReader.extractDoubleAttribute(context.attrs, 'y1') ?? 0;
    final x2 = attributeReader.extractDoubleAttribute(context.attrs, 'x2') ?? 0;
    final y2 = attributeReader.extractDoubleAttribute(context.attrs, 'y2') ?? 0;
    return 'M$x1,${y1}L$x2,$y2';
  }
}

class SvgPolylineElementPathStrategy implements SvgElementPathStrategy {
  const SvgPolylineElementPathStrategy();

  @override
  String get tagName => 'polyline';

  @override
  String? buildPathData({
    required SvgElementPathContext context,
    required SvgAttributeReader attributeReader,
  }) {
    return _buildPolyPath(attributeReader, context.attrs, close: false);
  }
}

class SvgPolygonElementPathStrategy implements SvgElementPathStrategy {
  const SvgPolygonElementPathStrategy();

  @override
  String get tagName => 'polygon';

  @override
  String? buildPathData({
    required SvgElementPathContext context,
    required SvgAttributeReader attributeReader,
  }) {
    return _buildPolyPath(attributeReader, context.attrs, close: true);
  }
}

/// Parses a `points` attribute into a path `d` string.
/// Used by both polyline (open) and polygon (closed) strategies.
String? _buildPolyPath(
  SvgAttributeReader reader,
  String attrs, {
  required bool close,
}) {
  final pointsRaw = reader.extractAttribute(attrs, 'points');
  if (pointsRaw == null || pointsRaw.trim().isEmpty) return null;

  final numbers = RegExp(
    r'[-+]?(?:\d*\.)?\d+(?:[eE][-+]?\d+)?',
  ).allMatches(pointsRaw).map((match) => match.group(0)!).toList();
  if (numbers.length < 4 || numbers.length.isOdd) return null;

  final buffer = StringBuffer('M${numbers[0]},${numbers[1]}');
  for (var index = 2; index < numbers.length; index += 2) {
    buffer.write('L${numbers[index]},${numbers[index + 1]}');
  }
  if (close) buffer.write('Z');
  return buffer.toString();
}

class SvgRectElementPathStrategy implements SvgElementPathStrategy {
  const SvgRectElementPathStrategy();

  @override
  String get tagName => 'rect';

  @override
  String? buildPathData({
    required SvgElementPathContext context,
    required SvgAttributeReader attributeReader,
  }) {
    final x = attributeReader.extractDoubleAttribute(context.attrs, 'x') ?? 0;
    final y = attributeReader.extractDoubleAttribute(context.attrs, 'y') ?? 0;
    final width = attributeReader.extractDoubleAttribute(
      context.attrs,
      'width',
    );
    final height = attributeReader.extractDoubleAttribute(
      context.attrs,
      'height',
    );
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }

    var rx = attributeReader.extractDoubleAttribute(context.attrs, 'rx');
    var ry = attributeReader.extractDoubleAttribute(context.attrs, 'ry');

    // SVG spec: if only one is specified, the other defaults to the same.
    rx ??= ry;
    ry ??= rx;

    if (rx == null || rx <= 0 || ry == null || ry <= 0) {
      // Sharp-cornered rectangle: 4 lines.
      return 'M$x,$y'
          'L${x + width},$y'
          'L${x + width},${y + height}'
          'L$x,${y + height}'
          'Z';
    }

    // Clamp radii per SVG spec.
    rx = rx.clamp(0, width / 2);
    ry = ry.clamp(0, height / 2);

    // Rounded rectangle: lines + arcs approximated as cubic beziers.
    // The magic constant for a 90-degree arc approximation.
    const double arcMagic = 0.5522847498;
    final cxOffset = rx * arcMagic;
    final cyOffset = ry * arcMagic;

    return 'M${x + rx},$y'
        'L${x + width - rx},$y'
        'C${x + width - rx + cxOffset},$y ${x + width},${y + ry - cyOffset} ${x + width},${y + ry}'
        'L${x + width},${y + height - ry}'
        'C${x + width},${y + height - ry + cyOffset} ${x + width - rx + cxOffset},${y + height} ${x + width - rx},${y + height}'
        'L${x + rx},${y + height}'
        'C${x + rx - cxOffset},${y + height} $x,${y + height - ry + cyOffset} $x,${y + height - ry}'
        'L$x,${y + ry}'
        'C$x,${y + ry - cyOffset} ${x + rx - cxOffset},$y ${x + rx},$y'
        'Z';
  }
}

class SvgCircleElementPathStrategy implements SvgElementPathStrategy {
  const SvgCircleElementPathStrategy();

  @override
  String get tagName => 'circle';

  @override
  String? buildPathData({
    required SvgElementPathContext context,
    required SvgAttributeReader attributeReader,
  }) {
    final cx = attributeReader.extractDoubleAttribute(context.attrs, 'cx') ?? 0;
    final cy = attributeReader.extractDoubleAttribute(context.attrs, 'cy') ?? 0;
    final r = attributeReader.extractDoubleAttribute(context.attrs, 'r');
    if (r == null || r <= 0) return null;

    return _buildEllipsePath(cx, cy, r, r);
  }
}

class SvgEllipseElementPathStrategy implements SvgElementPathStrategy {
  const SvgEllipseElementPathStrategy();

  @override
  String get tagName => 'ellipse';

  @override
  String? buildPathData({
    required SvgElementPathContext context,
    required SvgAttributeReader attributeReader,
  }) {
    final cx = attributeReader.extractDoubleAttribute(context.attrs, 'cx') ?? 0;
    final cy = attributeReader.extractDoubleAttribute(context.attrs, 'cy') ?? 0;
    final rx = attributeReader.extractDoubleAttribute(context.attrs, 'rx');
    final ry = attributeReader.extractDoubleAttribute(context.attrs, 'ry');
    if (rx == null || ry == null || rx <= 0 || ry <= 0) return null;

    return _buildEllipsePath(cx, cy, rx, ry);
  }
}

/// Builds a closed SVG path `d` string approximating an ellipse using four
/// cubic Bezier curves. Shared by circle and ellipse strategies.
String _buildEllipsePath(double cx, double cy, double rx, double ry) {
  // Kappa: cubic bezier control-point magic constant for a 90-degree arc.
  const double kappa = 0.5522847498;
  final cxOffset = rx * kappa;
  final cyOffset = ry * kappa;
  // Start at the top of the ellipse and draw 4 quarter arcs clockwise.
  final start = SvgPoint(cx, cy - ry);
  final control1 = SvgPoint(cx + cxOffset, cy - ry);
  final control2 = SvgPoint(cx + rx, cy - cyOffset);
  final end1 = SvgPoint(cx + rx, cy);
  final control3 = SvgPoint(cx + rx, cy + cyOffset);
  final control4 = SvgPoint(cx + cxOffset, cy + ry);
  final end2 = SvgPoint(cx, cy + ry);
  final control5 = SvgPoint(cx - cxOffset, cy + ry);
  final control6 = SvgPoint(cx - rx, cy + cyOffset);
  final end3 = SvgPoint(cx - rx, cy);
  final control7 = SvgPoint(cx - rx, cy - cyOffset);
  final control8 = SvgPoint(cx - cxOffset, cy - ry);

  return 'M${start.x},${start.y}'
      'C${control1.x},${control1.y} ${control2.x},${control2.y} ${end1.x},${end1.y}'
      'C${control3.x},${control3.y} ${control4.x},${control4.y} ${end2.x},${end2.y}'
      'C${control5.x},${control5.y} ${control6.x},${control6.y} ${end3.x},${end3.y}'
      'C${control7.x},${control7.y} ${control8.x},${control8.y} ${start.x},${start.y}'
      'Z';
}

class SvgTransformMatrix {
  const SvgTransformMatrix({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
  });

  const SvgTransformMatrix.identity()
    : a = 1,
      b = 0,
      c = 0,
      d = 1,
      e = 0,
      f = 0;

  final double a;
  final double b;
  final double c;
  final double d;
  final double e;
  final double f;

  bool get isIdentity =>
      (a - 1).abs() < 1e-12 &&
      b.abs() < 1e-12 &&
      c.abs() < 1e-12 &&
      (d - 1).abs() < 1e-12 &&
      e.abs() < 1e-12 &&
      f.abs() < 1e-12;

  SvgPoint applyToPoint(SvgPoint point) {
    return SvgPoint(
      a * point.x + c * point.y + e,
      b * point.x + d * point.y + f,
    );
  }

  SvgTransformMatrix then(SvgTransformMatrix next) {
    // Affine composition: apply this, then next.
    return SvgTransformMatrix(
      a: next.a * a + next.c * b,
      b: next.b * a + next.d * b,
      c: next.a * c + next.c * d,
      d: next.b * c + next.d * d,
      e: next.a * e + next.c * f + next.e,
      f: next.b * e + next.d * f + next.f,
    );
  }

  static SvgTransformMatrix parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const SvgTransformMatrix.identity();
    }

    var matrix = const SvgTransformMatrix.identity();
    final commandPattern = RegExp(r'([A-Za-z]+)\s*\(([^)]*)\)');
    for (final match in commandPattern.allMatches(raw)) {
      final command = match.group(1)!.toLowerCase();
      final args = RegExp(r'[-+]?(?:\d*\.)?\d+(?:[eE][-+]?\d+)?')
          .allMatches(match.group(2)!)
          .map((m) => double.parse(m.group(0)!))
          .toList();

      switch (command) {
        case 'matrix':
          if (args.length < 6) {
            continue;
          }
          final commandMatrix = SvgTransformMatrix(
            a: args[0],
            b: args[1],
            c: args[2],
            d: args[3],
            e: args[4],
            f: args[5],
          );
          matrix = commandMatrix.then(matrix);
        case 'scale':
          if (args.isEmpty) {
            continue;
          }
          final sx = args[0];
          final sy = args.length > 1 ? args[1] : sx;
          final commandMatrix = SvgTransformMatrix(
            a: sx,
            b: 0,
            c: 0,
            d: sy,
            e: 0,
            f: 0,
          );
          matrix = commandMatrix.then(matrix);
        case 'translate':
          final tx = args.isNotEmpty ? args[0] : 0.0;
          final ty = args.length > 1 ? args[1] : 0.0;
          final commandMatrix = SvgTransformMatrix(
            a: 1,
            b: 0,
            c: 0,
            d: 1,
            e: tx,
            f: ty,
          );
          matrix = commandMatrix.then(matrix);
        case 'rotate':
          if (args.isEmpty) {
            continue;
          }
          final angleRadians = args[0] * math.pi / 180.0;
          final cosTheta = math.cos(angleRadians);
          final sinTheta = math.sin(angleRadians);
          final rotation = SvgTransformMatrix(
            a: cosTheta,
            b: sinTheta,
            c: -sinTheta,
            d: cosTheta,
            e: 0,
            f: 0,
          );
          SvgTransformMatrix commandMatrix = rotation;
          if (args.length >= 3) {
            final cx = args[1];
            final cy = args[2];
            commandMatrix =
                SvgTransformMatrix(a: 1, b: 0, c: 0, d: 1, e: cx, f: cy)
                    .then(rotation)
                    .then(
                      SvgTransformMatrix(
                        a: 1,
                        b: 0,
                        c: 0,
                        d: 1,
                        e: -cx,
                        f: -cy,
                      ),
                    );
          }
          matrix = commandMatrix.then(matrix);
        case 'skewx':
          if (args.isEmpty) {
            continue;
          }
          final tanTheta = math.tan(args[0] * math.pi / 180.0);
          final commandMatrix = SvgTransformMatrix(
            a: 1,
            b: 0,
            c: tanTheta,
            d: 1,
            e: 0,
            f: 0,
          );
          matrix = commandMatrix.then(matrix);
        case 'skewy':
          if (args.isEmpty) {
            continue;
          }
          final tanTheta = math.tan(args[0] * math.pi / 180.0);
          final commandMatrix = SvgTransformMatrix(
            a: 1,
            b: tanTheta,
            c: 0,
            d: 1,
            e: 0,
            f: 0,
          );
          matrix = commandMatrix.then(matrix);
      }
    }

    return matrix;
  }
}

/// Reads CSS properties from an SVG element, checking the inline `style`
/// attribute first, then XML presentation attributes, then walking up to
/// ancestor elements for inherited properties per the SVG cascade order.
///
/// SVG presentation attributes like `stroke-linecap`, `stroke-linejoin`,
/// `stroke-width`, `fill`, etc. are inherited from parent elements when
/// not specified on the element itself.
class SvgStyleReader {
  SvgStyleReader(XmlElement element)
    : _element = element,
      _styleProperties = _parseStyleAttribute(element.getAttribute('style'));

  final XmlElement _element;
  final Map<String, String> _styleProperties;

  String? read(String propertyName) {
    // 1. Check inline style attribute (highest specificity).
    final fromStyle = _styleProperties[propertyName];
    if (fromStyle != null) return fromStyle;

    // 2. Check XML presentation attribute on the element itself.
    final fromAttribute = _element.getAttribute(propertyName);
    if (fromAttribute != null) return fromAttribute;

    // 3. Walk up ancestors for inherited CSS properties.
    return _readInherited(propertyName, _element.parentElement);
  }

  String? _readInherited(String propertyName, XmlNode? ancestor) {
    if (ancestor == null || ancestor is! XmlElement) return null;

    // Check ancestor's inline style.
    final ancestorStyle = _parseStyleAttribute(ancestor.getAttribute('style'));
    final fromStyle = ancestorStyle[propertyName];
    if (fromStyle != null) return fromStyle;

    // Check ancestor's presentation attribute.
    final fromAttribute = ancestor.getAttribute(propertyName);
    if (fromAttribute != null) return fromAttribute;

    // Continue up the tree.
    return _readInherited(propertyName, ancestor.parentElement);
  }

  static Map<String, String> _parseStyleAttribute(String? styleValue) {
    if (styleValue == null || styleValue.isEmpty) return const {};
    final result = <String, String>{};
    for (final declaration in styleValue.split(';')) {
      final colonIndex = declaration.indexOf(':');
      if (colonIndex < 0) continue;
      final name = declaration.substring(0, colonIndex).trim();
      final value = declaration.substring(colonIndex + 1).trim();
      if (name.isNotEmpty && value.isNotEmpty) {
        result[name] = value;
      }
    }
    return result;
  }
}

/// Extracts [SvgStrokeProperties] from an SVG element by reading its
/// CSS style and presentation attributes via [SvgStyleReader].
class SvgStrokePropertiesExtractor {
  const SvgStrokePropertiesExtractor();

  SvgStrokeProperties? extract(XmlElement element) {
    final styleReader = SvgStyleReader(element);

    final strokeRaw = styleReader.read('stroke');
    final strokeWidthRaw = styleReader.read('stroke-width');
    if (strokeRaw == null && strokeWidthRaw == null) return null;

    final strokeWidthPixels = _parseStrokeWidth(strokeWidthRaw);
    if (strokeWidthPixels <= 0) return null;

    final fillRaw = styleReader.read('fill');
    final fillOpacityRaw = styleReader.read('fill-opacity');

    return SvgStrokeProperties(
      strokeWidthPixels: strokeWidthPixels,
      lineCap: _parseLineCap(styleReader.read('stroke-linecap')),
      lineJoin: _parseLineJoin(styleReader.read('stroke-linejoin')),
      miterLimit: _parseMiterLimit(styleReader.read('stroke-miterlimit')),
      hasVisibleFill: _hasVisibleFill(
        fillRaw,
        fillOpacityRaw,
        element.localName,
      ),
    );
  }

  bool hasVisibleFill(XmlElement element) {
    final styleReader = SvgStyleReader(element);
    return _hasVisibleFill(
      styleReader.read('fill'),
      styleReader.read('fill-opacity'),
      element.localName,
    );
  }

  double _parseStrokeWidth(String? raw) {
    if (raw == null) return 0;
    final numeric = RegExp(r'[-+]?(?:\d*\.)?\d+').firstMatch(raw)?.group(0);
    if (numeric == null) return 0;
    return double.tryParse(numeric) ?? 0;
  }

  SvgStrokeLineCap _parseLineCap(String? raw) {
    return switch (raw) {
      'round' => SvgStrokeLineCap.round,
      'square' => SvgStrokeLineCap.square,
      _ => SvgStrokeLineCap.butt,
    };
  }

  SvgStrokeLineJoin _parseLineJoin(String? raw) {
    return switch (raw) {
      'round' => SvgStrokeLineJoin.round,
      'bevel' => SvgStrokeLineJoin.bevel,
      _ => SvgStrokeLineJoin.miter,
    };
  }

  double _parseMiterLimit(String? raw) {
    if (raw == null) return 4;
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed <= 0) return 4;
    return parsed;
  }

  bool _hasVisibleFill(
    String? fillRaw,
    String? fillOpacityRaw,
    String tagName,
  ) {
    // SVG lines are never fill-painted.
    if (tagName == 'line') return false;
    if (fillRaw == 'none') return false;
    if (fillOpacityRaw != null) {
      final opacity = double.tryParse(fillOpacityRaw) ?? 1;
      if (opacity <= 0) return false;
    }
    return true;
  }
}

class SvgDocumentPathExtractor {
  const SvgDocumentPathExtractor({
    this.attributeReader = const SvgAttributeReader(),
    this.pathStrategyRegistry = const SvgElementPathStrategyRegistry(),
    this.strokePropertiesExtractor = const SvgStrokePropertiesExtractor(),
  });

  final SvgAttributeReader attributeReader;
  final SvgElementPathStrategyRegistry pathStrategyRegistry;
  final SvgStrokePropertiesExtractor strokePropertiesExtractor;
  static const Set<String> _nonRenderingContainerTags = <String>{
    'defs',
    'clippath',
    'mask',
    'pattern',
    'symbol',
    'marker',
  };

  /// Parses an SVG document string, extracts shape elements via registered
  /// strategies, and returns their path data alongside the document viewport.
  SvgDocumentData extract(
    String svgContent, {
    SvgShapeTargetFormat? targetFormat,
  }) {
    final document = XmlDocument.parse(svgContent);
    final svgRoot = document.rootElement;
    final viewport = _extractViewport(svgRoot);
    final format = targetFormat ?? SvgShapeTargetFormat.generic;
    final clipRectDefinitions = _extractClipRectDefinitions(svgRoot);
    final pathEntries = <SvgPathEntry>[];
    _collectPathEntries(
      svgRoot,
      format,
      pathEntries,
      clipRectDefinitions: clipRectDefinitions,
      inheritedTransform: null,
      inheritedClipRect: null,
    );
    return SvgDocumentData(pathEntries: pathEntries, viewport: viewport);
  }

  Map<String, SvgClipRect> _extractClipRectDefinitions(XmlElement svgRoot) {
    final definitions = <String, SvgClipRect>{};
    final clipPathElements = svgRoot.findAllElements('clipPath');
    for (final clipPathElement in clipPathElements) {
      final id = clipPathElement.getAttribute('id')?.trim();
      if (id == null || id.isEmpty) {
        continue;
      }
      final rect = _extractClipRectFromClipPath(clipPathElement);
      if (rect != null && rect.isValid) {
        definitions[id] = rect;
      }
    }
    return definitions;
  }

  SvgClipRect? _extractClipRectFromClipPath(XmlElement clipPathElement) {
    for (final child in clipPathElement.childElements) {
      if (child.localName != 'rect') {
        continue;
      }
      final attrs = _serializeAttributes(child);
      final x = attributeReader.extractDoubleAttribute(attrs, 'x') ?? 0;
      final y = attributeReader.extractDoubleAttribute(attrs, 'y') ?? 0;
      final width = attributeReader.extractDoubleAttribute(attrs, 'width');
      final height = attributeReader.extractDoubleAttribute(attrs, 'height');
      if (width == null || height == null || width <= 0 || height <= 0) {
        return null;
      }
      return SvgClipRect(minX: x, minY: y, maxX: x + width, maxY: y + height);
    }
    return null;
  }

  SvgDocumentViewport? _extractViewport(XmlElement svgRoot) {
    final viewBoxValue = svgRoot.getAttribute('viewBox');
    if (viewBoxValue != null) {
      final parts = viewBoxValue.split(RegExp(r'[\s,]+'));
      if (parts.length >= 4) {
        final minX = double.tryParse(parts[0]);
        final minY = double.tryParse(parts[1]);
        final width = double.tryParse(parts[2]);
        final height = double.tryParse(parts[3]);
        if (width != null && height != null && width > 0 && height > 0) {
          return SvgDocumentViewport(
            width: width,
            height: height,
            minX: minX ?? 0,
            minY: minY ?? 0,
          );
        }
      }
    }
    return null;
  }

  void _collectPathEntries(
    XmlElement element,
    SvgShapeTargetFormat format,
    List<SvgPathEntry> results, {
    required Map<String, SvgClipRect> clipRectDefinitions,
    required SvgTransformMatrix? inheritedTransform,
    required SvgClipRect? inheritedClipRect,
  }) {
    for (final child in element.childElements) {
      if (_nonRenderingContainerTags.contains(child.localName.toLowerCase())) {
        continue;
      }
      final accumulatedTransform = _composeTransforms(
        inheritedTransform,
        _extractElementTransform(child),
      );
      final tagName = child.localName;
      final strategies = pathStrategyRegistry.strategiesFor(tagName);
      final elementClipRect = _resolveElementClipRect(
        child: child,
        clipRectDefinitions: clipRectDefinitions,
        inheritedClipRect: inheritedClipRect,
      );

      for (final strategy in strategies) {
        final serializedAttributes = _serializeAttributes(child);
        final context = SvgElementPathContext(
          tagName: tagName,
          attrs: serializedAttributes,
          targetFormat: format,
        );
        final pathData = strategy.buildPathData(
          context: context,
          attributeReader: attributeReader,
        );
        if (pathData != null && pathData.isNotEmpty) {
          final strokeProperties = strokePropertiesExtractor.extract(child);
          final hasVisibleFill = strokePropertiesExtractor.hasVisibleFill(
            child,
          );
          final fillRule = _extractFillRule(child);
          // Skip fully non-painted elements (fill:none with no visible stroke).
          if (strokeProperties == null && !hasVisibleFill) {
            continue;
          }
          results.add(
            SvgPathEntry(
              pathData: pathData,
              sourceTagName: tagName,
              fillRule: fillRule,
              strokeProperties: strokeProperties,
              transformMatrix: accumulatedTransform,
              clipRect: elementClipRect,
            ),
          );
        }
      }

      // Recurse into child elements (handles <g>, <defs>, etc.)
      _collectPathEntries(
        child,
        format,
        results,
        clipRectDefinitions: clipRectDefinitions,
        inheritedTransform: accumulatedTransform,
        inheritedClipRect: elementClipRect,
      );
    }
  }

  SvgClipRect? _resolveElementClipRect({
    required XmlElement child,
    required Map<String, SvgClipRect> clipRectDefinitions,
    required SvgClipRect? inheritedClipRect,
  }) {
    final clipReference = _extractClipPathReference(child);
    if (clipReference == null) {
      return inheritedClipRect;
    }
    final currentClipRect = clipRectDefinitions[clipReference];
    if (currentClipRect == null) {
      return inheritedClipRect;
    }
    if (inheritedClipRect == null) {
      return currentClipRect;
    }
    return inheritedClipRect.intersect(currentClipRect);
  }

  String? _extractClipPathReference(XmlElement element) {
    final raw =
        SvgStyleReader(element).read('clip-path') ??
        element.getAttribute('clip-path');
    if (raw == null) {
      return null;
    }
    final match = RegExp(r'url\(\s*#([^)]+)\s*\)').firstMatch(raw);
    if (match == null) {
      return null;
    }
    return match.group(1)?.trim();
  }

  /// Serializes an XML element's attributes into the space-separated
  /// `name="value"` string format that [SvgAttributeReader] expects.
  String _serializeAttributes(XmlElement element) {
    final buffer = StringBuffer();
    for (final attribute in element.attributes) {
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write('${attribute.localName}="${attribute.value}"');
    }
    return buffer.toString();
  }

  SvgTransformMatrix? _extractElementTransform(XmlElement element) {
    final raw = element.getAttribute('transform');
    final matrix = SvgTransformMatrix.parse(raw);
    return matrix.isIdentity ? null : matrix;
  }

  SvgTransformMatrix? _composeTransforms(
    SvgTransformMatrix? inheritedTransform,
    SvgTransformMatrix? elementTransform,
  ) {
    if (inheritedTransform == null) {
      return elementTransform;
    }
    if (elementTransform == null) {
      return inheritedTransform;
    }

    // Child-local coordinates are transformed by the element first, then
    // by inherited parent transforms.
    final composed = elementTransform.then(inheritedTransform);
    return composed.isIdentity ? null : composed;
  }

  SvgFillRule _extractFillRule(XmlElement element) {
    final rawFillRule = SvgStyleReader(element).read('fill-rule');
    if (rawFillRule == null) {
      return SvgFillRule.nonzero;
    }

    return switch (rawFillRule.trim().toLowerCase()) {
      'evenodd' => SvgFillRule.evenodd,
      _ => SvgFillRule.nonzero,
    };
  }
}
