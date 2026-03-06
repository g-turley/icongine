import 'dart:typed_data';

/// Encodes Type2 charstring numbers and operators per the Adobe Type2
/// Charstring Format specification (Technical Note #5177).
///
/// Type2 charstrings use a variable-length integer encoding where small
/// values occupy fewer bytes. This encoder handles the full signed range
/// needed for glyph coordinate deltas.
class Type2CharstringEncoder {
  const Type2CharstringEncoder();

  /// Type2 charstring operator codes.
  static const int operatorRmoveto = 21;
  static const int operatorRlineto = 5;
  static const int operatorRrcurveto = 8;
  static const int operatorEndchar = 14;

  /// Encodes a signed [value] using Type2 number encoding rules
  /// and appends the result to [builder].
  ///
  /// Encoding ranges:
  ///   -107..107       → 1 byte
  ///   108..1131       → 2 bytes
  ///   -1131..-108     → 2 bytes
  ///   -32768..32767   → 3 bytes (shortint prefix 28)
  void writeNumber(BytesBuilder builder, int value) {
    if (value >= -107 && value <= 107) {
      builder.add([value + 139]);
      return;
    }

    if (value >= 108 && value <= 1131) {
      final encoded = value - 108;
      builder.add([247 + (encoded ~/ 256), encoded % 256]);
      return;
    }

    if (value >= -1131 && value <= -108) {
      final encoded = -value - 108;
      builder.add([251 + (encoded ~/ 256), encoded % 256]);
      return;
    }

    // shortint: 3 bytes for values in -32768..32767
    final bytes = ByteData(3);
    bytes.setUint8(0, 28);
    bytes.setInt16(1, value);
    builder.add(bytes.buffer.asUint8List());
  }
}
