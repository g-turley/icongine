import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../domain/config.dart';

/// Adds a font family or updates only the registration owned by this set.
void registerInitFont(
  YamlEditor editor,
  GenerationConfig config,
  GenerationConfig? previous,
) {
  var root = editor.parseAt([]) as YamlMap;
  if (root['flutter'] == null) {
    editor.update(['flutter'], <String, Object?>{});
    root = editor.parseAt([]) as YamlMap;
  }
  final flutter = root['flutter'];
  if (flutter is! YamlMap) {
    throw const FormatException('Expected "flutter" to be a map.');
  }
  final fonts = flutter['fonts'];
  if (fonts != null && fonts is! YamlList) {
    throw const FormatException('Expected "flutter.fonts" to be a list.');
  }
  final entries = fonts as YamlList?;
  int? matching;
  int? owned;
  for (var i = 0; i < (entries?.length ?? 0); i++) {
    final entry = entries![i];
    if (entry is! YamlMap) {
      throw const FormatException('Expected each font family to be a map.');
    }
    final assets = entry['fonts'];
    if (entry['family'] == config.fontFamily) {
      if (matching != null) {
        throw FormatException('Duplicate font family ${config.fontFamily}.');
      }
      matching = i;
    }
    if (previous != null &&
        entry['family'] == previous.fontFamily &&
        assets is YamlList &&
        assets.length == 1 &&
        _hasAsset(assets, previous.outFontFile!)) {
      owned = i;
    }
  }
  final asset = config.outFontFile!;
  if (matching != null) {
    final entry = entries![matching] as YamlMap;
    if (_hasAsset(entry['fonts'], asset)) return;
    if (matching != owned) {
      throw FormatException(
        'Font family ${config.fontFamily} already uses a different asset. '
        'Choose another --class-name or update that family manually.',
      );
    }
  }
  final index = matching ?? owned;
  if (index != null) {
    editor.update(['flutter', 'fonts', index, 'family'], config.fontFamily);
    editor.update(['flutter', 'fonts', index, 'fonts', 0, 'asset'], asset);
    return;
  }
  final entry = <String, Object>{
    'family': config.fontFamily,
    'fonts': [
      <String, String>{'asset': asset},
    ],
  };
  if (entries == null) {
    editor.update(['flutter', 'fonts'], [entry]);
  } else {
    editor.appendToList(['flutter', 'fonts'], entry);
  }
}

bool _hasAsset(Object? fonts, String asset) =>
    fonts is YamlList &&
    fonts.any(
      (entry) =>
          entry is YamlMap &&
          entry['asset'] is String &&
          path.equals(
            path.normalize(entry['asset'] as String),
            path.normalize(asset),
          ),
    );
