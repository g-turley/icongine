import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  group('SvgDocumentPathExtractor', () {
    const extractor = SvgDocumentPathExtractor();

    test('extracts viewport from viewBox attribute', () {
      const svg =
          '<svg viewBox="0 0 512 512" '
          'xmlns="http://www.w3.org/2000/svg"></svg>';

      final result = extractor.extract(svg);

      expect(result.viewport, isNotNull);
      expect(result.viewport!.width, 512.0);
      expect(result.viewport!.height, 512.0);
    });

    test('returns null viewport when viewBox is absent', () {
      const svg = '<svg xmlns="http://www.w3.org/2000/svg"></svg>';

      final result = extractor.extract(svg);

      expect(result.viewport, isNull);
    });

    test('extracts path element d attribute', () {
      const svg =
          '<svg viewBox="0 0 24 24" '
          'xmlns="http://www.w3.org/2000/svg">'
          '<path d="M10,20L10,4"/>'
          '</svg>';

      final result = extractor.extract(svg);

      expect(result.pathEntries, hasLength(1));
      expect(result.pathEntries.first.pathData, 'M10,20L10,4');
      expect(result.pathEntries.first.sourceTagName, 'path');
      expect(result.pathEntries.first.fillRule, SvgFillRule.nonzero);
    });

    test('defaults fill-rule to nonzero when not specified', () {
      const svg =
          '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
          '<path d="M0,0L10,0L10,10L0,10Z"/>'
          '</svg>';

      final result = extractor.extract(svg);

      expect(result.pathEntries, hasLength(1));
      expect(result.pathEntries.single.fillRule, SvgFillRule.nonzero);
    });

    test('inherits fill-rule from ancestor style declarations', () {
      const svg =
          '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" '
          'style="fill-rule:evenodd;">'
          '<g><path d="M0,0L10,0L10,10L0,10Z"/></g>'
          '</svg>';

      final result = extractor.extract(svg);

      expect(result.pathEntries, hasLength(1));
      expect(result.pathEntries.single.fillRule, SvgFillRule.evenodd);
    });

    test('allows element fill-rule to override inherited fill-rule', () {
      const svg =
          '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" '
          'style="fill-rule:evenodd;">'
          '<path d="M0,0L10,0L10,10L0,10Z" fill-rule="nonzero"/>'
          '</svg>';

      final result = extractor.extract(svg);

      expect(result.pathEntries, hasLength(1));
      expect(result.pathEntries.single.fillRule, SvgFillRule.nonzero);
    });

    test('extracts multiple path elements', () {
      const svg =
          '<svg viewBox="0 0 24 24" '
          'xmlns="http://www.w3.org/2000/svg">'
          '<path d="M0,0L10,10"/>'
          '<path d="M5,5L15,15"/>'
          '</svg>';

      final result = extractor.extract(svg);

      expect(result.pathEntries, hasLength(2));
      expect(result.pathEntries[0].pathData, 'M0,0L10,10');
      expect(result.pathEntries[1].pathData, 'M5,5L15,15');
    });

    test('traverses into nested group elements', () {
      const svg =
          '<svg viewBox="0 0 24 24" '
          'xmlns="http://www.w3.org/2000/svg">'
          '<g><path d="M0,0L10,10"/></g>'
          '</svg>';

      final result = extractor.extract(svg);

      expect(result.pathEntries, hasLength(1));
      expect(result.pathEntries.first.pathData, 'M0,0L10,10');
    });

    test('ignores non-rendered definition containers like clipPath', () {
      const svg =
          '<svg viewBox="0 0 14 14" xmlns="http://www.w3.org/2000/svg">'
          '<g clip-path="url(#clip0)">'
          '<path d="M1,1L5,1L5,5L1,5Z"/>'
          '</g>'
          '<defs>'
          '<clipPath id="clip0">'
          '<rect width="14" height="14"/>'
          '</clipPath>'
          '</defs>'
          '</svg>';

      final result = extractor.extract(svg);

      expect(result.pathEntries, hasLength(1));
      expect(result.pathEntries.single.sourceTagName, 'path');
      expect(result.pathEntries.single.pathData, 'M1,1L5,1L5,5L1,5Z');
    });

    test('resolves clipPath rectangles onto extracted entries', () {
      const svg =
          '<svg viewBox="0 0 14 14" xmlns="http://www.w3.org/2000/svg">'
          '<g clip-path="url(#clipRect)">'
          '<path d="M0,0L14,0L14,14L0,14Z"/>'
          '</g>'
          '<defs>'
          '<clipPath id="clipRect"><rect x="1" y="2" width="10" height="9"/></clipPath>'
          '</defs>'
          '</svg>';

      final result = extractor.extract(svg);
      final clipRect = result.pathEntries.single.clipRect;

      expect(result.pathEntries, hasLength(1));
      expect(clipRect, isNotNull);
      expect(clipRect!.minX, closeTo(1.0, 1e-6));
      expect(clipRect.minY, closeTo(2.0, 1e-6));
      expect(clipRect.maxX, closeTo(11.0, 1e-6));
      expect(clipRect.maxY, closeTo(11.0, 1e-6));
    });

    test('skips elements without a registered strategy', () {
      const svg =
          '<svg viewBox="0 0 24 24" '
          'xmlns="http://www.w3.org/2000/svg">'
          '<text>Hello</text>'
          '<path d="M0,0L10,10"/>'
          '</svg>';

      final result = extractor.extract(svg);

      expect(result.pathEntries, hasLength(1));
    });

    test('skips path elements without d attribute', () {
      const svg =
          '<svg viewBox="0 0 24 24" '
          'xmlns="http://www.w3.org/2000/svg">'
          '<path style="fill:red"/>'
          '</svg>';

      final result = extractor.extract(svg);

      expect(result.pathEntries, isEmpty);
    });

    test('extracts path from circle-filled test shape', () {
      const svg =
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">'
          '<path d="M47,256c0,-115.35 93.65,-209 209,-209c115.35,0 '
          '209,93.65 209,209c0,115.35 -93.65,209 -209,209c-115.35,0 '
          '-209,-93.65 -209,-209Z" style="fill:#ebebeb;stroke:#000;'
          'stroke-width:30px;"/></svg>';

      final result = extractor.extract(svg);

      expect(result.viewport, isNotNull);
      expect(result.viewport!.width, 512.0);
      expect(result.pathEntries, hasLength(1));
      expect(result.pathEntries.first.pathData, startsWith('M47,256'));
      expect(result.pathEntries.first.pathData, endsWith('-209,-209Z'));
    });

    test('inherits stroke-linejoin and stroke-miterlimit from svg root style', () {
      const svg =
          '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" '
          'style="stroke-linejoin:bevel;stroke-miterlimit:1.5;stroke-linecap:round;">'
          '<path d="M2,2L2,22L22,22" style="fill:none;stroke:#000;stroke-width:4px;"/>'
          '</svg>';

      final result = extractor.extract(svg);
      final stroke = result.pathEntries.single.strokeProperties;

      expect(stroke, isNotNull);
      expect(stroke!.lineJoin, SvgStrokeLineJoin.bevel);
      expect(stroke.lineCap, SvgStrokeLineCap.round);
      expect(stroke.miterLimit, closeTo(1.5, 0.001));
    });

    test(
      'uses default miterlimit when stroke-miterlimit is missing or invalid',
      () {
        const svgMissing =
            '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
            '<path d="M2,2L2,22L22,22" style="fill:none;stroke:#000;stroke-width:4px;"/>'
            '</svg>';
        final missingResult = extractor.extract(svgMissing);
        expect(
          missingResult.pathEntries.single.strokeProperties!.miterLimit,
          closeTo(4.0, 0.001),
        );

        const svgInvalid =
            '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" '
            'style="stroke-miterlimit:not-a-number;">'
            '<path d="M2,2L2,22L22,22" style="fill:none;stroke:#000;stroke-width:4px;"/>'
            '</svg>';
        final invalidResult = extractor.extract(svgInvalid);
        expect(
          invalidResult.pathEntries.single.strokeProperties!.miterLimit,
          closeTo(4.0, 0.001),
        );
      },
    );

    test('treats line elements with stroke and no fill as stroke-only', () {
      const svg =
          '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
          '<line x1="2" y1="2" x2="22" y2="22" '
          'style="stroke:#000;stroke-width:4px;"/>'
          '</svg>';

      final result = extractor.extract(svg);
      final stroke = result.pathEntries.single.strokeProperties;

      expect(stroke, isNotNull);
      expect(stroke!.isStrokeOnly, isTrue);
    });

    test('skips non-painted elements (fill:none and no stroke)', () {
      const svg =
          '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
          '<polygon points="2,2 22,2 12,22" style="fill:none;"/>'
          '</svg>';

      final result = extractor.extract(svg);

      expect(result.pathEntries, isEmpty);
    });

    test('captures translate/rotate transform matrix on ellipse entry', () {
      const svg =
          '<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">'
          '<ellipse cx="256" cy="256" rx="267.57" ry="173.44" '
          'transform="translate(-106.04 256) rotate(-45)" '
          'style="fill:none;stroke:#000;stroke-width:32px;"/>'
          '</svg>';

      final result = extractor.extract(svg);
      final transform = result.pathEntries.single.transformMatrix;
      final transformedTop = transform!.applyToPoint(
        const SvgPoint(256, 82.56),
      );

      // Top point of the untransformed ellipse should map near (133.36, 133.36).
      expect(transformedTop.x, closeTo(133.36, 0.5));
      expect(transformedTop.y, closeTo(133.36, 0.5));
    });

    test('parses matrix transform commands', () {
      const svg =
          '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
          '<path d="M0,0L1,0" transform="matrix(2 0 0 3 4 5)"/>'
          '</svg>';

      final result = extractor.extract(svg);
      final transform = result.pathEntries.single.transformMatrix!;
      final transformed = transform.applyToPoint(const SvgPoint(1, 1));

      expect(transformed.x, closeTo(6.0, 1e-6));
      expect(transformed.y, closeTo(8.0, 1e-6));
    });

    test('composes inherited group transforms with element transforms', () {
      const svg =
          '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
          '<g transform="translate(10 20)">'
          '<path d="M0,0L1,0" transform="scale(2)"/>'
          '</g>'
          '</svg>';

      final result = extractor.extract(svg);
      final transform = result.pathEntries.single.transformMatrix!;
      final transformed = transform.applyToPoint(const SvgPoint(3, 4));

      expect(transformed.x, closeTo(16.0, 1e-6));
      expect(transformed.y, closeTo(28.0, 1e-6));
    });

    test('parses rotate transform with center point (cx, cy)', () {
      // Lines 476-482, 487-488: rotate(angle, cx, cy) with center point
      // rotate(90, 50, 50) exercises the cx/cy branch of the rotate case
      const svg =
          '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
          '<path d="M0,0L1,0" transform="rotate(90, 50, 50)"/>'
          '</svg>';

      final result = extractor.extract(svg);
      final transform = result.pathEntries.single.transformMatrix!;
      // Verify a non-null transform matrix is produced (the cx/cy branch was hit)
      // The identity matrix would have a=1,d=1 — rotation changes these
      expect(transform.isIdentity, isFalse);

      // Verify that a 90-degree rotation is embedded (cos90=0, sin90=1)
      // The 'a' component of the rotation part should be ~0
      expect(transform.a.abs(), lessThan(0.01));
      final center = transform.applyToPoint(const SvgPoint(50, 50));
      expect(center.x, closeTo(50, 1e-8));
      expect(center.y, closeTo(50, 1e-8));
      final right = transform.applyToPoint(const SvgPoint(60, 50));
      expect(right.x, closeTo(50, 1e-8));
      expect(right.y, closeTo(60, 1e-8));
    });

    test('parses skewX transform', () {
      // Lines 493-506: skewX transform
      // skewX(45): x' = x + y*tan(45) = x + y*1
      const svg =
          '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
          '<path d="M0,0L1,0" transform="skewX(45)"/>'
          '</svg>';

      final result = extractor.extract(svg);
      final transform = result.pathEntries.single.transformMatrix!;
      // skewX(45): x' = x + y*tan(45°) ≈ x + y*1
      final transformed = transform.applyToPoint(const SvgPoint(0, 10));

      expect(transformed.x, closeTo(10, 0.1)); // 0 + 10*tan(45)
      expect(transformed.y, closeTo(10, 1e-6)); // y unchanged
    });

    test('parses skewY transform', () {
      // Lines 507-512, 520: skewY transform
      // skewY(45): y' = y + x*tan(45) = y + x*1
      const svg =
          '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
          '<path d="M0,0L1,0" transform="skewY(45)"/>'
          '</svg>';

      final result = extractor.extract(svg);
      final transform = result.pathEntries.single.transformMatrix!;
      // skewY(45): y' = y + x*tan(45°) ≈ y + x*1
      final transformed = transform.applyToPoint(const SvgPoint(10, 0));

      expect(transformed.x, closeTo(10, 1e-6)); // x unchanged
      expect(transformed.y, closeTo(10, 0.1)); // 0 + 10*tan(45)
    });

    test('handles rotate transform with empty args gracefully', () {
      // Edge case: rotate() with no args is silently skipped
      const svg =
          '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
          '<path d="M0,0L1,0" transform="rotate()"/>'
          '</svg>';

      final result = extractor.extract(svg);
      // No transform matrix since rotate() with empty args is skipped
      // but the path entry should still be extracted
      expect(result.pathEntries, hasLength(1));
    });
  });
}
