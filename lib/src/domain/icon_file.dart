/// A discovered SVG source file.
class IconFile {
  const IconFile({required this.absolutePath, required this.relativePath});

  /// Absolute file-system path to the SVG file.
  final String absolutePath;

  /// Path to the SVG file relative to the configured input directory.
  final String relativePath;
}
