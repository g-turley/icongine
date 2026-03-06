import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  group('Type2CharstringEncoder', () {
    const encoder = Type2CharstringEncoder();

    test('encodes zero as single byte 139', () {
      final builder = BytesBuilder();
      encoder.writeNumber(builder, 0);
      expect(builder.takeBytes(), [139]);
    });

    test('encodes small positive value (1..107) as single byte', () {
      final builder = BytesBuilder();
      encoder.writeNumber(builder, 1);
      expect(builder.takeBytes(), [140]);
    });

    test('encodes 107 as single byte 246', () {
      final builder = BytesBuilder();
      encoder.writeNumber(builder, 107);
      expect(builder.takeBytes(), [246]);
    });

    test('encodes small negative value (-1..-107) as single byte', () {
      final builder = BytesBuilder();
      encoder.writeNumber(builder, -1);
      expect(builder.takeBytes(), [138]);
    });

    test('encodes -107 as single byte 32', () {
      final builder = BytesBuilder();
      encoder.writeNumber(builder, -107);
      expect(builder.takeBytes(), [32]);
    });

    test('encodes medium positive value (108..1131) as two bytes', () {
      final builder = BytesBuilder();
      encoder.writeNumber(builder, 108);
      final bytes = builder.takeBytes();
      expect(bytes.length, 2);
      expect(bytes[0], 247);
    });

    test('encodes medium negative value (-108..-1131) as two bytes', () {
      final builder = BytesBuilder();
      encoder.writeNumber(builder, -108);
      final bytes = builder.takeBytes();
      expect(bytes.length, 2);
      expect(bytes[0], 251);
    });

    test('encodes large value as three-byte shortint', () {
      final builder = BytesBuilder();
      encoder.writeNumber(builder, 2000);
      final bytes = builder.takeBytes();
      expect(bytes.length, 3);
      expect(bytes[0], 28); // shortint prefix
    });

    test('encodes large negative value as three-byte shortint', () {
      final builder = BytesBuilder();
      encoder.writeNumber(builder, -2000);
      final bytes = builder.takeBytes();
      expect(bytes.length, 3);
      expect(bytes[0], 28);
    });

    test('round-trips value through shortint encoding', () {
      final builder = BytesBuilder();
      encoder.writeNumber(builder, 2000);
      final bytes = builder.takeBytes();
      // shortint: byte[0]=28, then Int16BE (3 bytes total)
      expect(bytes.length, 3);
      expect(bytes[0], 28);
      final decoded = ByteData.sublistView(
        Uint8List.fromList(bytes),
      ).getInt16(1);
      expect(decoded, 2000);
    });
  });
}
