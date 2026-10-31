import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../domain/generation_sets.dart';

/// Selects an init target and preserves a prior single set as `default`.
class InitSetEditor {
  InitSetEditor(String source, String? requested) {
    if (requested != null) validateSetName(requested);
    final root = loadYaml(source) as YamlMap;
    final original = root['icongine'];
    if (original != null && original is! YamlMap) {
      throw const FormatException('Expected "icongine" to be a map.');
    }
    if (requested != null &&
        original is YamlMap &&
        original.isNotEmpty &&
        !original.containsKey('sets')) {
      source = _nestSingleSet(source, original);
    }
    editor = YamlEditor(source);
    var section = (editor.parseAt([]) as YamlMap)['icongine'];
    if (section == null) {
      editor.update(['icongine'], <String, Object?>{});
      section = (editor.parseAt([]) as YamlMap)['icongine'];
    }
    final current = section as YamlMap;
    if (requested != null && !current.containsKey('sets')) {
      editor.update(['icongine', 'sets'], <String, Object?>{});
    }
    final sets = (editor.parseAt(['icongine']) as YamlMap)['sets'];
    if (requested != null || current.containsKey('sets')) {
      if (sets is! YamlMap) {
        throw const FormatException('Expected "icongine.sets" to be a map.');
      }
      name = requested;
      if (name == null) {
        if (sets.length != 1 || sets.keys.single is! String) {
          throw const FormatException(
            'Use --set <name> to add or update a named icon set.',
          );
        }
        name = sets.keys.single as String;
      }
      validateSetName(name!);
      configPath = ['icongine', 'sets', name!];
      previous = sets[name];
      if (!sets.containsKey(name) || sets[name] == null) {
        editor.update(configPath, <String, Object?>{});
      }
    } else {
      name = null;
      configPath = ['icongine'];
      previous = original;
    }
    if (previous != null && previous is! YamlMap) {
      throw const FormatException(
        'Expected the icon set configuration to be a map.',
      );
    }
  }

  late final YamlEditor editor;
  late final List<String> configPath;
  late String? name;
  late final Object? previous;

  String _nestSingleSet(String source, YamlMap section) {
    // Ask yaml_edit to detect aliases before relocating any anchored values.
    final probe = YamlEditor(source);
    probe.update(['icongine', section.keys.first], section.values.first);
    if (section.style != CollectionStyle.BLOCK) {
      probe.update(
        ['icongine'],
        {
          'sets': {'default': _plainValue(section)},
        },
      );
      return probe.toString();
    }
    final start = section.span.start.offset;
    final end = section.span.end.offset;
    final original = source.substring(start, end);
    var indented = original.replaceAll('\n', '\n    ');
    if (original.endsWith('\n')) {
      indented = indented.substring(0, indented.length - 4);
    }
    final indent = ' ' * section.span.start.column;
    final newline = source.contains('\r\n') ? '\r\n' : '\n';
    return source.replaceRange(
      start,
      end,
      'sets:$newline$indent  default:$newline$indent    $indented',
    );
  }

  // Detach source spans before re-encoding a flow-style map at a new depth.
  Object? _plainValue(Object? value) {
    if (value is YamlMap) {
      return value.map((key, child) => MapEntry(key, _plainValue(child)));
    }
    if (value is YamlList) return value.map(_plainValue).toList();
    return value;
  }
}
