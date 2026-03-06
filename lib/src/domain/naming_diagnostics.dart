import 'icon_symbol.dart';

enum NamingIssueSeverity { warning, error }

class NamingIssue {
  const NamingIssue({
    required this.severity,
    required this.code,
    required this.message,
  });

  final NamingIssueSeverity severity;
  final String code;
  final String message;
}

class SymbolResolutionResult {
  const SymbolResolutionResult({required this.symbols, required this.issues});

  final List<IconSymbol> symbols;
  final List<NamingIssue> issues;
}
