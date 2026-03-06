import 'package:path/path.dart' as path;

import '../core/case_ext.dart';
import 'icon_file.dart';
import 'icon_symbol.dart';
import 'naming_diagnostics.dart';

abstract interface class IconNamer {
  String symbolFor({
    required String relativePath,
    required bool prefixWithSubdir,
  });
}

class PathNamer implements IconNamer {
  const PathNamer();

  @override
  String symbolFor({
    required String relativePath,
    required bool prefixWithSubdir,
  }) {
    final withoutExt = path.withoutExtension(relativePath);

    if (!prefixWithSubdir) {
      return path.basename(withoutExt).toLowerCamel();
    }

    final normalized = withoutExt.replaceAll(path.separator, '_');
    return normalized.toLowerCamel();
  }
}

class SymbolResolver {
  const SymbolResolver({this.namer = const PathNamer()});

  final IconNamer namer;

  List<IconSymbol> resolve({
    required List<IconFile> files,
    required bool prefixWithSubdir,
    Set<String> additionalReserved = const {},
  }) {
    return resolveWithDiagnostics(
      files: files,
      prefixWithSubdir: prefixWithSubdir,
      additionalReserved: additionalReserved,
    ).symbols;
  }

  SymbolResolutionResult resolveWithDiagnostics({
    required List<IconFile> files,
    required bool prefixWithSubdir,
    Set<String> additionalReserved = const {},
  }) {
    final used = <String, int>{};
    final issues = <NamingIssue>[];
    final assignedByBaseName = <String, List<String>>{};

    final symbols = files
        .map((file) {
          final baseName = namer.symbolFor(
            relativePath: file.relativePath,
            prefixWithSubdir: prefixWithSubdir,
          );
          if (baseName.isEmpty) {
            issues.add(
              NamingIssue(
                severity: NamingIssueSeverity.error,
                code: 'empty_name',
                message:
                    'Icon "${file.relativePath}" produced an empty symbol name. '
                    'Rename the file to include alphanumeric characters.',
              ),
            );
          }
          assignedByBaseName
              .putIfAbsent(baseName, () => [])
              .add(file.relativePath);

          final name = _uniqueName(baseName, used);
          if (_reservedIdentifiers.contains(name) ||
              additionalReserved.contains(name)) {
            issues.add(
              NamingIssue(
                severity: NamingIssueSeverity.error,
                code: 'reserved_identifier',
                message:
                    'Icon "${file.relativePath}" resolves to reserved name "$name". '
                    'Rename the source file.',
              ),
            );
          }
          return IconSymbol(file: file, name: name);
        })
        .toList(growable: false);

    for (final entry in assignedByBaseName.entries) {
      if (entry.value.length < 2) {
        continue;
      }
      issues.add(
        NamingIssue(
          severity: NamingIssueSeverity.warning,
          code: 'name_collision',
          message:
              'Files ${entry.value.join(', ')} collided on symbol "${entry.key}" '
              'and were suffixed numerically.',
        ),
      );
    }

    return SymbolResolutionResult(symbols: symbols, issues: issues);
  }

  String _uniqueName(String baseName, Map<String, int> used) {
    final key = baseName.toLowerCase();
    final count = used[key];
    if (count == null) {
      used[key] = 1;
      return baseName;
    }

    final next = count + 1;
    used[key] = next;
    return '$baseName$next';
  }

  static const Set<String> _reservedIdentifiers = {
    'fontFamily',
    'fontPackage',
    'runtimeType',
    'hashCode',
    'toString',
    'noSuchMethod',
    'operator',
    'class',
    'enum',
    'extension',
    'mixin',
    'static',
    'const',
    'final',
    'var',
    'switch',
    'case',
    'default',
    'new',
    'this',
    'super',
    'if',
    'else',
    'for',
    'while',
    'do',
    'try',
    'catch',
    'throw',
    'return',
    'void',
    'null',
    'true',
    'false',
  };
}
