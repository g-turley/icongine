import 'dart:typed_data';
import 'font_glyph.dart';

/// Writes a compiled glyph set into a concrete font file format.
abstract interface class FontWriter {
  /// Encodes [glyphs] for [familyName] and returns the font bytes.
  Uint8List write({
    required String familyName,
    required List<FontGlyph> glyphs,
  });
}
