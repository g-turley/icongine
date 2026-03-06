import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  const reader = SvgAttributeReader();
  const genericFormat = SvgShapeTargetFormat.generic;

  SvgElementPathContext buildContext(String tagName, String attrs) {
    return SvgElementPathContext(
      tagName: tagName,
      attrs: attrs,
      targetFormat: genericFormat,
    );
  }

  group('SvgRectElementPathStrategy', () {
    const strategy = SvgRectElementPathStrategy();

    test('tag name is rect', () {
      expect(strategy.tagName, 'rect');
    });

    test('returns null when width is missing', () {
      final result = strategy.buildPathData(
        context: buildContext('rect', 'x="0" y="0" height="100"'),
        attributeReader: reader,
      );
      expect(result, isNull);
    });

    test('returns null when height is zero', () {
      final result = strategy.buildPathData(
        context: buildContext('rect', 'x="0" y="0" width="100" height="0"'),
        attributeReader: reader,
      );
      expect(result, isNull);
    });

    test('builds sharp-cornered rect path from x, y, width, height', () {
      final result = strategy.buildPathData(
        context: buildContext('rect', 'x="10" y="20" width="100" height="50"'),
        attributeReader: reader,
      );
      expect(result, contains('M10.0,20.0'));
      expect(result, contains('L110.0,20.0'));
      expect(result, contains('L110.0,70.0'));
      expect(result, contains('L10.0,70.0'));
      expect(result, endsWith('Z'));
    });

    test('defaults x and y to zero when omitted', () {
      final result = strategy.buildPathData(
        context: buildContext('rect', 'width="50" height="30"'),
        attributeReader: reader,
      );
      expect(result, startsWith('M0.0,0.0'));
    });

    test('builds rounded rect path when rx is specified', () {
      final result = strategy.buildPathData(
        context: buildContext(
          'rect',
          'x="0" y="0" width="100" height="100" rx="10"',
        ),
        attributeReader: reader,
      );
      // Should contain cubic bezier curves for rounded corners.
      expect(result, contains('C'));
      expect(result, endsWith('Z'));
    });

    test('uses ry as rx default and vice versa', () {
      final resultRxOnly = strategy.buildPathData(
        context: buildContext(
          'rect',
          'x="0" y="0" width="100" height="100" rx="15"',
        ),
        attributeReader: reader,
      );
      final resultRyOnly = strategy.buildPathData(
        context: buildContext(
          'rect',
          'x="0" y="0" width="100" height="100" ry="15"',
        ),
        attributeReader: reader,
      );
      // Both should produce identical paths since missing radius defaults
      // to the other.
      expect(resultRxOnly, resultRyOnly);
    });
  });

  group('SvgCircleElementPathStrategy', () {
    const strategy = SvgCircleElementPathStrategy();

    test('tag name is circle', () {
      expect(strategy.tagName, 'circle');
    });

    test('returns null when r is missing', () {
      final result = strategy.buildPathData(
        context: buildContext('circle', 'cx="50" cy="50"'),
        attributeReader: reader,
      );
      expect(result, isNull);
    });

    test('returns null when r is zero', () {
      final result = strategy.buildPathData(
        context: buildContext('circle', 'cx="50" cy="50" r="0"'),
        attributeReader: reader,
      );
      expect(result, isNull);
    });

    test('builds circle path with 4 cubic segments', () {
      final result = strategy.buildPathData(
        context: buildContext('circle', 'cx="100" cy="100" r="40"'),
        attributeReader: reader,
      );
      expect(result, isNotNull);
      // 4 cubic bezier curves + close path.
      expect('C'.allMatches(result!).length, 4);
      expect(result, endsWith('Z'));
    });

    test('defaults cx and cy to zero when omitted', () {
      final result = strategy.buildPathData(
        context: buildContext('circle', 'r="25"'),
        attributeReader: reader,
      );
      // Start at top of circle: (cx, cy - r) = (0, -25)
      expect(result, startsWith('M0.0,-25.0'));
    });
  });

  group('SvgEllipseElementPathStrategy', () {
    const strategy = SvgEllipseElementPathStrategy();

    test('tag name is ellipse', () {
      expect(strategy.tagName, 'ellipse');
    });

    test('returns null when rx or ry is missing', () {
      expect(
        strategy.buildPathData(
          context: buildContext('ellipse', 'cx="50" cy="50" rx="30"'),
          attributeReader: reader,
        ),
        isNull,
      );
      expect(
        strategy.buildPathData(
          context: buildContext('ellipse', 'cx="50" cy="50" ry="30"'),
          attributeReader: reader,
        ),
        isNull,
      );
    });

    test('builds ellipse path with 4 cubic segments', () {
      final result = strategy.buildPathData(
        context: buildContext('ellipse', 'cx="50" cy="50" rx="40" ry="20"'),
        attributeReader: reader,
      );
      expect(result, isNotNull);
      expect('C'.allMatches(result!).length, 4);
      expect(result, endsWith('Z'));
    });

    test('produces same path as circle when rx equals ry', () {
      const circleStrategy = SvgCircleElementPathStrategy();
      final ellipsePath = strategy.buildPathData(
        context: buildContext('ellipse', 'cx="100" cy="100" rx="50" ry="50"'),
        attributeReader: reader,
      );
      final circlePath = circleStrategy.buildPathData(
        context: buildContext('circle', 'cx="100" cy="100" r="50"'),
        attributeReader: reader,
      );
      expect(ellipsePath, circlePath);
    });
  });

  group('SvgLineElementPathStrategy', () {
    const strategy = SvgLineElementPathStrategy();

    test('tag name is line', () {
      expect(strategy.tagName, 'line');
    });

    test('builds path from x1, y1 to x2, y2', () {
      final result = strategy.buildPathData(
        context: buildContext('line', 'x1="10" y1="20" x2="100" y2="200"'),
        attributeReader: reader,
      );
      expect(result, 'M10.0,20.0L100.0,200.0');
    });

    test('defaults coordinates to zero when omitted', () {
      final result = strategy.buildPathData(
        context: buildContext('line', 'x2="50" y2="50"'),
        attributeReader: reader,
      );
      expect(result, 'M0.0,0.0L50.0,50.0');
    });
  });

  group('SvgPolylineElementPathStrategy', () {
    const strategy = SvgPolylineElementPathStrategy();

    test('tag name is polyline', () {
      expect(strategy.tagName, 'polyline');
    });

    test('returns null when points attribute is missing', () {
      final result = strategy.buildPathData(
        context: buildContext('polyline', ''),
        attributeReader: reader,
      );
      expect(result, isNull);
    });

    test('returns null when points has fewer than 2 coordinate pairs', () {
      final result = strategy.buildPathData(
        context: buildContext('polyline', 'points="10,20"'),
        attributeReader: reader,
      );
      expect(result, isNull);
    });

    test('builds open path from points', () {
      final result = strategy.buildPathData(
        context: buildContext('polyline', 'points="0,0 50,50 100,0"'),
        attributeReader: reader,
      );
      expect(result, 'M0,0L50,50L100,0');
    });

    test('does not close the path', () {
      final result = strategy.buildPathData(
        context: buildContext('polyline', 'points="10,10 20,20 30,10"'),
        attributeReader: reader,
      );
      expect(result, isNot(endsWith('Z')));
    });
  });

  group('SvgPolygonElementPathStrategy', () {
    const strategy = SvgPolygonElementPathStrategy();

    test('tag name is polygon', () {
      expect(strategy.tagName, 'polygon');
    });

    test('returns null when points attribute is missing', () {
      final result = strategy.buildPathData(
        context: buildContext('polygon', ''),
        attributeReader: reader,
      );
      expect(result, isNull);
    });

    test('builds closed path from points', () {
      final result = strategy.buildPathData(
        context: buildContext('polygon', 'points="0,0 100,0 100,100 0,100"'),
        attributeReader: reader,
      );
      expect(result, 'M0,0L100,0L100,100L0,100Z');
    });

    test('handles space and comma separated points', () {
      final result = strategy.buildPathData(
        context: buildContext('polygon', 'points="10 20, 30 40, 50 60"'),
        attributeReader: reader,
      );
      expect(result, 'M10,20L30,40L50,60Z');
    });
  });

  group('SvgElementPathStrategyRegistry', () {
    const registry = SvgElementPathStrategyRegistry();

    test('has strategies for all standard SVG shape elements', () {
      for (final tagName in [
        'path',
        'rect',
        'circle',
        'ellipse',
        'line',
        'polyline',
        'polygon',
      ]) {
        expect(
          registry.strategiesFor(tagName).isNotEmpty,
          isTrue,
          reason: 'Missing strategy for <$tagName>',
        );
      }
    });

    test('returns empty for unknown tag name', () {
      expect(registry.strategiesFor('unknown'), isEmpty);
    });
  });

  group('SvgDocumentPathExtractor with non-path elements', () {
    const extractor = SvgDocumentPathExtractor();

    test('extracts rect element as path data', () {
      const svg =
          '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
          '<rect x="10" y="10" width="80" height="80"/>'
          '</svg>';
      final data = extractor.extract(svg);
      expect(data.pathEntries, hasLength(1));
      expect(data.pathEntries.first.sourceTagName, 'rect');
      expect(data.pathEntries.first.pathData, contains('M'));
      expect(data.pathEntries.first.pathData, endsWith('Z'));
    });

    test('extracts circle element as path data', () {
      const svg =
          '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
          '<circle cx="50" cy="50" r="40"/>'
          '</svg>';
      final data = extractor.extract(svg);
      expect(data.pathEntries, hasLength(1));
      expect(data.pathEntries.first.sourceTagName, 'circle');
      expect(data.pathEntries.first.pathData, contains('C'));
    });

    test('extracts multiple element types from one SVG', () {
      const svg =
          '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
          '<circle cx="50" cy="50" r="20"/>'
          '<rect x="10" y="10" width="30" height="30"/>'
          '<path d="M0,0L100,100"/>'
          '</svg>';
      final data = extractor.extract(svg);
      expect(data.pathEntries, hasLength(3));
      expect(data.pathEntries[0].sourceTagName, 'circle');
      expect(data.pathEntries[1].sourceTagName, 'rect');
      expect(data.pathEntries[2].sourceTagName, 'path');
    });

    test('extracts polygon element as closed path', () {
      const svg =
          '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
          '<polygon points="50,0 100,100 0,100"/>'
          '</svg>';
      final data = extractor.extract(svg);
      expect(data.pathEntries, hasLength(1));
      expect(data.pathEntries.first.sourceTagName, 'polygon');
      expect(data.pathEntries.first.pathData, endsWith('Z'));
    });
  });
}
