import 'icon_symbol.dart';

/// Severity levels emitted during icon naming.
enum NamingIssueSeverity { warning, error }

/// A single warning or error produced by the naming phase.
class NamingIssue {
  const NamingIssue({
    required this.severity,
    required this.code,
    required this.message,
  });

  /// Severity assigned to the issue.
  final NamingIssueSeverity severity;

  /// Stable machine-readable issue code.
  final String code;

  /// Human-readable explanation for the issue.
  final String message;
}

/// Naming output containing resolved symbols and diagnostics.
class SymbolResolutionResult {
  const SymbolResolutionResult({required this.symbols, required this.issues});

  /// Successfully resolved icon symbols.
  final List<IconSymbol> symbols;

  /// Warnings and errors collected during resolution.
  final List<NamingIssue> issues;
}
