import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

// table_builders.dart uncovered lines:
// _buildCmapRanges - starting a new range for non-contiguous code points

void main() {
  const builder = OtfTableBuilder();

  group('OtfTableBuilder.buildCmapTable', () {
    test('builds cmap table with contiguous code points (single range)', () {
      // Normal single contiguous range
      final table = builder.buildCmapTable(
        entries: const [
          CmapEntry(codePoint: 0xe001, glyphId: 1),
          CmapEntry(codePoint: 0xe002, glyphId: 2),
          CmapEntry(codePoint: 0xe003, glyphId: 3),
        ],
      );

      expect(table.tag, 'cmap');
      expect(table.data.isNotEmpty, isTrue);
    });

    test(
      'builds cmap table with non-contiguous code points (multiple ranges)',
      () {
        // Lines 464-473: _buildCmapRanges creates a new range when code points
        // are not contiguous or glyphId mapping breaks.
        // Gap between 0xe001 and 0xe010 → two separate ranges.
        final table = builder.buildCmapTable(
          entries: const [
            CmapEntry(codePoint: 0xe001, glyphId: 1),
            CmapEntry(codePoint: 0xe002, glyphId: 2),
            // Gap: 0xe010 is not contiguous from 0xe002
            CmapEntry(codePoint: 0xe010, glyphId: 3),
            CmapEntry(codePoint: 0xe011, glyphId: 4),
          ],
        );

        expect(table.tag, 'cmap');
        expect(table.data.isNotEmpty, isTrue);
      },
    );

    test('builds cmap table with single entry', () {
      final table = builder.buildCmapTable(
        entries: const [CmapEntry(codePoint: 0xe001, glyphId: 1)],
      );

      expect(table.tag, 'cmap');
    });
  });
}
