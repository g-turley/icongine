import '../../domain/font_format.dart';
import 'font_writer.dart';
import 'formats/otf.dart';
import 'formats/ttf.dart';

class FontWriterFactory {
  const FontWriterFactory({
    this.ttfWriter = const TtfWriter(),
    this.otfWriter = const OtfWriter(),
    this.registeredFormatWriters,
  });

  final FontWriter ttfWriter;
  final FontWriter otfWriter;
  final Map<FontFormat, FontWriter>? registeredFormatWriters;

  FontWriter resolve(FontFormat format) {
    final writers = registeredFormatWriters ?? _defaultWriters();
    final writer = writers[format];
    if (writer == null) {
      throw UnsupportedError('No font writer registered for format: $format');
    }
    return writer;
  }

  Map<FontFormat, FontWriter> _defaultWriters() {
    return <FontFormat, FontWriter>{
      FontFormat.ttf: ttfWriter,
      FontFormat.otf: otfWriter,
    };
  }
}
