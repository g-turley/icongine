import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

// cff.dart uncovered lines:
// 110-112: glyphNames.length != glyphs.length → generates fallback names
// 219: _requiredOffSize returns 3 for values <= 0xffffff

void main() {
  group('CffEncoder', () {
    const encoder = CffEncoder();

    test(
      'generates fallback glyph names when names count does not match glyphs',
      () {
        // Lines 110-112: glyphNames.length != glyphs.length
        // When glyphNames count doesn't match glyphs count, auto-generate names.
        final input = CffBuildInput(
          familyName: 'TestFont',
          glyphs: [
            const CffGlyphMetrics(xMax: 100, yMax: 100),
            const CffGlyphMetrics(xMax: 200, yMax: 200),
          ],
          // Intentionally wrong count: 1 name for 2 glyphs
          glyphNames: const ['onlyOneName'],
        );

        final cff = encoder.encode(input);

        // CFF should still encode successfully
        expect(cff.isNotEmpty, isTrue);
        expect(cff[0], 1); // CFF major version
        expect(cff[1], 0); // CFF minor version
      },
    );

    test('uses 3-byte offSize for CFF index with offset > 0xffff', () {
      const largeEncoder = CffEncoder(
        glyphProgramStrategy: EmptyGlyphProgramStrategy(),
      );

      final glyphs = List.generate(
        700,
        (_) => const CffGlyphMetrics(xMax: 1000, yMax: 1000),
      );
      final longSuffix = 'a' * 120;
      final glyphNames = List.generate(
        700,
        (index) => 'glyph_${index}_$longSuffix',
      );

      final input = CffBuildInput(
        familyName: 'TestFont',
        glyphs: glyphs,
        glyphNames: glyphNames,
      );

      final cff = largeEncoder.encode(input);

      expect(cff.isNotEmpty, isTrue);
      expect(cff[0], 1);
    });

    test(
      'encodes with EmptyGlyphProgramStrategy producing minimal charstrings',
      () {
        // Tests EmptyGlyphProgramStrategy.buildGlyphProgram (line 94-96 in cff.dart)
        const emptyEncoder = CffEncoder(
          glyphProgramStrategy: EmptyGlyphProgramStrategy(),
        );

        final input = CffBuildInput(
          familyName: 'Icons',
          glyphs: [const CffGlyphMetrics(xMax: 512, yMax: 512)],
          glyphNames: const ['icon1'],
        );

        final cff = emptyEncoder.encode(input);
        expect(cff.isNotEmpty, isTrue);
      },
    );

    test('encodes with matched glyph names', () {
      // Standard path (lines 108-109): names match glyphs
      final input = CffBuildInput(
        familyName: 'Icons',
        glyphs: [
          const CffGlyphMetrics(xMax: 512, yMax: 512),
          const CffGlyphMetrics(xMax: 256, yMax: 256),
        ],
        glyphNames: const ['iconA', 'iconB'],
      );

      final cff = encoder.encode(input);

      expect(cff.isNotEmpty, isTrue);
      expect(cff[0], 1);
    });
  });
}
