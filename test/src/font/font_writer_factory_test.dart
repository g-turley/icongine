import 'dart:typed_data';

import 'package:icongine/icongine.dart';
import 'package:test/test.dart';

void main() {
  group('FontWriterFactory', () {
    test('resolves otf format to OtfWriter', () {
      const factory = FontWriterFactory();

      final writer = factory.resolve(FontFormat.otf);

      expect(writer, isA<OtfWriter>());
    });

    test('keeps default right side bearing for otf format', () {
      const factory = FontWriterFactory();

      final writer = factory.resolve(FontFormat.otf);

      expect(writer, isA<OtfWriter>());
      final otfWriter = writer as OtfWriter;
      expect(
        otfWriter.rightSideBearingPaddingUnits,
        TtfWriter.defaultRightSideBearingPaddingUnits,
      );
    });

    test('keeps default right side bearing for ttf format', () {
      const factory = FontWriterFactory();

      final writer = factory.resolve(FontFormat.ttf);

      expect(writer, isA<TtfWriter>());
      final ttfWriter = writer as TtfWriter;
      expect(
        ttfWriter.rightSideBearingPaddingUnits,
        TtfWriter.defaultRightSideBearingPaddingUnits,
      );
    });

    test('throws UnsupportedError for unregistered format', () {
      final factory = FontWriterFactory(
        registeredFormatWriters: {FontFormat.ttf: const _NoOpFontWriter()},
      );

      expect(() => factory.resolve(FontFormat.otf), throwsUnsupportedError);
    });
  });
}

class _NoOpFontWriter implements FontWriter {
  const _NoOpFontWriter();

  @override
  Uint8List write({
    required String familyName,
    required List<FontGlyph> glyphs,
  }) {
    return Uint8List(0);
  }
}
