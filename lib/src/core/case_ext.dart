/// Naming helpers used to convert SVG file names into Dart-safe identifiers.
extension CaseExt on String {
  /// Converts the receiver into lowerCamelCase.
  String toLowerCamel() {
    final words = _words();
    if (words.isEmpty) {
      return '';
    }

    final first = words.first.toLowerCase();
    final rest = words.skip(1).map(_cap).join();
    final value = '$first$rest';
    return value;
  }

  /// Converts the receiver into UpperCamelCase.
  String toUpperCamel() {
    final words = _words();
    if (words.isEmpty) {
      return '';
    }

    final cappedWords = words.map(_cap).join();
    return cappedWords;
  }

  List<String> _words() {
    final boundarySpaced = trim()
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAllMapped(
          RegExp(r'([A-Z])([A-Z][a-z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        );

    return boundarySpaced
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  String _cap(String word) {
    final lower = word.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }
}
