/// Thrown when no SVG files are found in the configured input directory.
class NoIconsFoundError extends Error {
  NoIconsFoundError(this.inputDir);

  /// Directory that was scanned for SVG files.
  final String inputDir;

  @override
  String toString() => 'No SVG icons found in inputDir: $inputDir';
}

/// Thrown when the compile step is reached without resolved symbols.
class NoSymbolsToCompileError extends Error {
  NoSymbolsToCompileError();

  @override
  String toString() => 'No resolved symbols available for compile step.';
}

/// Thrown when the emit step is reached without compile output.
class NoCompileResultToEmitError extends Error {
  NoCompileResultToEmitError();

  @override
  String toString() => 'No compile result available for emit step.';
}

/// Thrown when naming diagnostics contain one or more errors.
class NamingDiagnosticsError extends Error {
  NamingDiagnosticsError(this.messages);

  /// Error messages reported by the naming stage.
  final List<String> messages;

  @override
  String toString() =>
      'Naming diagnostics reported ${messages.length} error(s): '
      '${messages.join(' | ')}';
}
