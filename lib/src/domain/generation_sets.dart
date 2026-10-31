import 'package:path/path.dart' as path;

import '../core/case_ext.dart';
import 'config.dart';

/// Stable defaults for named sets; `default` retains the single-set paths.
Map<String, Object> generationSetDefaults(String name) {
  validateSetName(name);
  if (name == 'default') return const {};
  final stem = name.replaceAll('-', '_');
  final classStem = name.toUpperCamel();
  final className = classStem.endsWith('Icons')
      ? classStem
      : '${classStem}Icons';
  final dartStem = stem.endsWith('_icons') ? stem : '${stem}_icons';
  return {
    'name': className,
    'input_dir': 'assets/icons/$name',
    'output_font': 'assets/fonts/$name.otf',
    'output_class': 'lib/$dartStem.dart',
  };
}

void validateSetName(String name) {
  if (!RegExp(r'^[a-z][a-z0-9_-]*$').hasMatch(name)) {
    throw const FormatException(
      'Set names must start with a lowercase letter and contain only '
      'lowercase letters, digits, underscores, or hyphens.',
    );
  }
}

/// Every set owns distinct font families, Dart classes, and output files.
void validateGenerationSets(
  Map<String, GenerationConfig> configs, {
  String? directory,
}) {
  final outputs = <String, String>{};
  final families = <String, String>{};
  final classes = <String, String>{};
  void claim(
    Map<String, String> owners,
    String value,
    String name,
    String kind,
  ) {
    final other = owners[value];
    if (other != null) {
      throw FormatException(
        'Sets "$other" and "$name" share $kind "$value". '
        'Choose distinct families, classes, and output files.',
      );
    }
    owners[value] = name;
  }

  for (final entry in configs.entries) {
    final config = entry.value;
    claim(families, config.fontFamily, entry.key, 'font family');
    claim(classes, config.normalizedClassName, entry.key, 'Dart class');
    for (final output in [config.outFontFile!, config.outClassFile]) {
      final absolute = path.absolute(directory ?? '.', output);
      claim(outputs, path.canonicalize(absolute), entry.key, 'output file');
    }
  }
}
