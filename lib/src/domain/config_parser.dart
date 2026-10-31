import 'config.dart';
import 'font_format.dart';
import 'generation_sets.dart';
import 'png_tracing_mode.dart';

/// Parses `pubspec.yaml` input into a [GenerationConfig].
class GenerationConfigParser {
  const GenerationConfigParser();

  /// Reads named sets, or exposes the original single configuration as default.
  Map<String, GenerationConfig> parseSets(Map<String, Object?> pubspec) {
    final section = _readMap(pubspec, 'icongine');
    if (section == null || !section.containsKey('sets')) {
      return {'default': parsePubspec(pubspec)};
    }
    if (section.length != 1) {
      throw const FormatException(
        'With named sets, put generation options inside each `icongine.sets` entry.',
      );
    }
    final rawSets = section['sets'];
    if (rawSets is Map<Object?, Object?> &&
        rawSets.keys.any((key) => key is! String)) {
      throw const FormatException('Icon set names must be strings.');
    }
    final sets = _readMap(section, 'sets');
    if (sets == null || sets.isEmpty) {
      throw const FormatException('"icongine.sets" must be a non-empty map.');
    }
    final result = <String, GenerationConfig>{};
    for (final entry in sets.entries) {
      validateSetName(entry.key);
      final values = _readMap(sets, entry.key);
      if (values == null || values.containsKey('sets')) {
        throw FormatException(
          'Set "${entry.key}" must contain generation options.',
        );
      }
      final merged = <String, Object?>{...values};
      // Fill each alias group only when no spelling was supplied.
      final defaults = generationSetDefaults(entry.key);
      final format = values['font_format'] ?? values['fontFormat'];
      if (format is String &&
          format.trim().toLowerCase() == 'ttf' &&
          defaults['output_font'] is String) {
        defaults['output_font'] = (defaults['output_font']! as String)
            .replaceFirst(RegExp(r'\.otf$'), '.ttf');
      }
      for (final keys in const [
        ['name', 'class_name', 'className'],
        ['input_dir', 'inputDir'],
        ['output_font', 'out_font_file', 'outFontFile'],
        ['output_class', 'out_class_file', 'outClassFile'],
      ]) {
        if (!keys.any(merged.containsKey) && defaults.containsKey(keys.first)) {
          merged[keys.first] = defaults[keys.first];
        }
      }
      if (!merged.containsKey('font_format') &&
          !merged.containsKey('fontFormat')) {
        final output =
            merged['output_font'] ??
            merged['out_font_file'] ??
            merged['outFontFile'];
        if (output is String && output.toLowerCase().endsWith('.ttf')) {
          merged['font_format'] = 'ttf';
        }
      }
      result[entry.key] = parsePubspec({...pubspec, 'icongine': merged});
    }
    return result;
  }

  /// Reads the `icongine` section from a decoded pubspec map.
  GenerationConfig parsePubspec(Map<String, Object?> pubspec) {
    final packageName = _read<String>(pubspec, 'name') ?? 'icongine_app';
    final section = _readMap(pubspec, 'icongine') ?? const <String, Object?>{};
    if (section.containsKey('sets')) {
      throw const FormatException(
        'This pubspec has named sets. Use parseSets() or runAll().',
      );
    }

    final fontFormat = _parseFontFormat(
      _read<String>(section, 'font_format') ??
          _read<String>(section, 'fontFormat'),
    );
    final className = _readAliasedKeys(section, <String>[
      'name',
      'class_name',
      'className',
    ], 'AppIcons');

    return GenerationConfig(
      packageName: packageName,
      inputDir: _readAliased(section, 'input_dir', 'inputDir', 'assets/icons'),
      outFontFile: _readAliasedKeys(section, <String>[
        'output_font',
        'out_font_file',
        'outFontFile',
      ], _defaultFontFile(fontFormat)),
      outClassFile: _readAliasedKeys(section, <String>[
        'output_class',
        'out_class_file',
        'outClassFile',
      ], 'lib/app_icons.dart'),
      className: className,
      fontPackage: _readAliasedNullableString(
        section,
        'font_package',
        'fontPackage',
      ),
      includeSubdirs: _readAliased(
        section,
        'include_subdirs',
        'includeSubdirs',
        false,
      ),
      prefixWithSubdir: _readAliased(
        section,
        'prefix_with_subdir',
        'prefixWithSubdir',
        false,
      ),
      fontFormat: fontFormat,
      pngTracing: PngTracingMode.parse(
        _readAliased(section, 'png_tracing', 'pngTracing', 'smooth'),
      ),
      normalize: _readAliased(section, 'normalize', 'normalize', false),
      verbose: _readAliased(section, 'verbose', 'verbose', false),
      staticIconProvider: _readAliased(
        section,
        'static_icon_provider',
        'staticIconProvider',
        true,
      ),
      generateIconMap: _readAliased(
        section,
        'generate_icon_map',
        'generateIconMap',
        false,
      ),
    );
  }

  String _defaultFontFile(FontFormat format) => switch (format) {
    FontFormat.ttf => 'assets/fonts/icons.ttf',
    FontFormat.otf => 'assets/fonts/icons.otf',
  };

  T _readAliased<T>(
    Map<String, Object?> map,
    String snake,
    String camel,
    T fallback,
  ) {
    return _read<T>(map, snake) ?? _read<T>(map, camel) ?? fallback;
  }

  String? _readAliasedNullableString(
    Map<String, Object?> map,
    String snake,
    String camel,
  ) {
    final value = _read<String>(map, snake) ?? _read<String>(map, camel);
    if (value == null) {
      return null;
    }

    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : value;
  }

  T _readAliasedKeys<T>(
    Map<String, Object?> map,
    List<String> keys,
    T fallback,
  ) {
    for (final key in keys) {
      final value = _read<T>(map, key);
      if (value != null) {
        return value;
      }
    }
    return fallback;
  }

  T? _read<T>(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is T) return value as T;
    throw FormatException(
      'Expected "$key" to be a ${T.toString().toLowerCase()}.',
    );
  }

  Map<String, Object?>? _readMap(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is Map<Object?, Object?>) {
      return value.map(
        (childKey, childValue) => MapEntry(childKey.toString(), childValue),
      );
    }
    throw FormatException('Expected "$key" to be a map.');
  }

  FontFormat _parseFontFormat(String? value) {
    if (value == null) return FontFormat.otf;
    return switch (value.trim().toLowerCase()) {
      'ttf' => FontFormat.ttf,
      'otf' => FontFormat.otf,
      _ => throw FormatException('Unsupported font format "$value".'),
    };
  }
}
