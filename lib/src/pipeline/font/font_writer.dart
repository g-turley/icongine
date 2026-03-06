import 'dart:typed_data';
import 'font_glyph.dart';

abstract interface class FontWriter {
  Uint8List write({
    required String familyName,
    required List<FontGlyph> glyphs,
  });
}
