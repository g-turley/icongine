import 'config.dart';
import 'font_format.dart';
import 'png_tracing_mode.dart';

/// Parses `pubspec.yaml` input into a [GenerationConfig].
class GenerationConfigParser {
  const GenerationConfigParser();

  /// Reads the `icongine` section from a decoded pubspec map.
  GenerationConfig parsePubspec(Map<String, Object?> pubspec) {
    final packageName = _read<String>(pubspec, 'name') ?? 'icongine_app';
    final section = _readMap(pubspec, 'icongine') ?? const <String, Object?>{};

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
