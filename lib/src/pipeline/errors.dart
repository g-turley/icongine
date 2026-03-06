class NoIconsFoundError extends Error {
  NoIconsFoundError(this.inputDir);

  final String inputDir;

  @override
  String toString() => 'No SVG icons found in inputDir: $inputDir';
}

class NoSymbolsToCompileError extends Error {
  NoSymbolsToCompileError();

  @override
  String toString() => 'No resolved symbols available for compile step.';
}

class NoCompileResultToEmitError extends Error {
  NoCompileResultToEmitError();

  @override
  String toString() => 'No compile result available for emit step.';
}

class NamingDiagnosticsError extends Error {
  NamingDiagnosticsError(this.messages);

  final List<String> messages;

  @override
  String toString() =>
      'Naming diagnostics reported ${messages.length} error(s): '
      '${messages.join(' | ')}';
}
