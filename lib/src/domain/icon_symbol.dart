import 'icon_file.dart';

/// A resolved icon symbol name paired with its source file.
class IconSymbol {
  const IconSymbol({required this.file, required this.name});

  /// Source SVG file for this symbol.
  final IconFile file;

  /// Generated Dart identifier for the icon.
  final String name;
}
