import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

// sfnt.dart uncovered lines:
// 8: ArgumentError thrown when tag is not 4 ASCII characters

void main() {
  group('SfntTable', () {
    test('throws ArgumentError when tag length is not 4', () {
      // Line 8: tag.length != 4
      expect(
        () => SfntTable(tag: 'AB', data: Uint8List(0)),
        throwsArgumentError,
      );

      expect(
        () => SfntTable(tag: 'ABCDE', data: Uint8List(0)),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when tag contains non-ASCII characters', () {
      // Line 8: !isAsciiTag
      expect(
        () => SfntTable(tag: 'AB\u0080Z', data: Uint8List(0)),
        throwsArgumentError,
      );
    });

    test('creates SfntTable successfully with valid 4-char ASCII tag', () {
      final table = SfntTable(tag: 'head', data: Uint8List(4));
      expect(table.tag, 'head');
    });
  });

  group('SfntWriter', () {
    test('writes SFNT tables in sorted tag order', () {
      final writer = const SfntWriter();
      final tables = [
        SfntTable(tag: 'zzzz', data: Uint8List.fromList([1, 2, 3, 4])),
        SfntTable(tag: 'aaaa', data: Uint8List.fromList([5, 6, 7, 8])),
      ];

      final bytes = writer.write(tables);

      expect(bytes.isNotEmpty, isTrue);
      // Table tags in directory should be sorted: aaaa before zzzz
      // First 12 bytes = SFNT header, then 16-byte records start
      final firstTag = String.fromCharCodes(bytes.sublist(12, 16));
      expect(firstTag, 'aaaa');
    });
  });
}
