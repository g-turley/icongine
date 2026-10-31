import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../domain/config.dart';
import '../domain/config_parser.dart';
import '../domain/generation_sets.dart';
import 'init_font_registration.dart';
import 'init_options.dart';
import 'init_set_editor.dart';

/// Edits only icon setup and font registration, preserving unrelated YAML.
class InitPubspec {
  InitPubspec(String source, InitArguments args) {
    final root = loadYaml(source);
    if (root is! YamlMap || root['name'] is! String) {
      throw const FormatException('Expected a pubspec with a package name.');
    }
    final dependencies = root['dependencies'];
    final flutter = dependencies is YamlMap ? dependencies['flutter'] : null;
    if (flutter is! YamlMap || flutter['sdk'] != 'flutter') {
      throw const FormatException(
        '`init` sets up Flutter apps and packages. Run it in a project with '
        'a Flutter SDK dependency, or use `generate` for font-only workflows.',
      );
    }
    try {
      final target = InitSetEditor(source, args.setName);
      setName = target.name;
      final section = target.previous;
      final previous = section == null
          ? null
          : const GenerationConfigParser()
                .parseSets({
                  'name': root['name'],
                  'icongine': setName == null
                      ? section
                      : {
                          'sets': {setName: section},
                        },
                })
                .values
                .single;
      previousOutputs = {
        if (section is YamlMap)
          for (final key in const [
            'output_font',
            'out_font_file',
            'outFontFile',
            'output_class',
            'out_class_file',
            'outClassFile',
          ])
            if (section[key] is String) section[key] as String,
      };
      final editor = target.editor;
      _configure(editor, args, target.configPath);
      final updated = loadYaml(editor.toString()) as YamlMap;
      final configs = const GenerationConfigParser().parseSets(
        updated.map((key, value) => MapEntry(key.toString(), value)),
      );
      validateGenerationSets(
        configs,
        directory: path.absolute(path.dirname(args.pubspecPath)),
      );
      config = configs[setName ?? 'default']!;
      registerInitFont(
        editor,
        config,
        previousOutputs.contains(previous?.outFontFile) ? previous : null,
      );
      contents = editor.toString();
    } on AliasException {
      throw const FormatException(
        'Icon setup uses YAML aliases. Give `icongine` and `flutter.fonts` '
        'their own values before running init.',
      );
    }
  }

  late final String contents;
  late final GenerationConfig config;
  late final Set<String> previousOutputs;
  late final String? setName;

  void _configure(
    YamlEditor editor,
    InitArguments args,
    List<String> configPath,
  ) {
    final defaults = setName == null
        ? const <String, Object>{}
        : generationSetDefaults(setName!);
    void set(
      String key,
      Object value,
      List<String> aliases, {
      bool force = false,
    }) {
      final section = editor.parseAt(configPath);
      if (section is! YamlMap) {
        throw const FormatException('Expected "icongine" to be a map.');
      }
      if (force || ![key, ...aliases].any(section.containsKey)) {
        editor.update([...configPath, key], value);
      }
    }

    set('name', args.className ?? defaults['name'] ?? 'AppIcons', [
      'class_name',
      'className',
    ], force: args.className != null);
    set('input_dir', args.inputDir ?? defaults['input_dir'] ?? 'assets/icons', [
      'inputDir',
    ], force: args.inputDir != null);
    final existing = editor.parseAt(configPath) as YamlMap;
    final defaultFormat =
        existing['font_format'] ?? existing['fontFormat'] ?? 'otf';
    final fontDefault = defaults['output_font'] as String?;
    set(
      'output_font',
      args.outputFont ??
          (fontDefault == null
              ? 'assets/fonts/icons.$defaultFormat'
              : path.setExtension(fontDefault, '.$defaultFormat')),
      ['out_font_file', 'outFontFile'],
      force: args.outputFont != null,
    );
    set(
      'output_class',
      args.outputClass ?? defaults['output_class'] ?? 'lib/app_icons.dart',
      ['out_class_file', 'outClassFile'],
      force: args.outputClass != null,
    );
    final section = editor.parseAt(configPath) as YamlMap;
    final font =
        section['output_font'] ??
        section['out_font_file'] ??
        section['outFontFile'];
    if (font is! String) {
      throw const FormatException('Expected "output_font" to be a string.');
    }
    final extension = path.extension(font).toLowerCase();
    if (extension != '.otf' && extension != '.ttf') {
      throw const FormatException(
        'The font destination must end in .otf or .ttf.',
      );
    }
    set('font_format', extension.substring(1), [
      'fontFormat',
    ], force: args.outputFont != null);
    set('include_subdirs', true, ['includeSubdirs']);
    set('prefix_with_subdir', true, ['prefixWithSubdir']);
    set('png_tracing', 'smooth', ['pngTracing']);
    set('static_icon_provider', true, ['staticIconProvider']);
    // Flutter asset declarations use forward slashes relative to the pubspec.
    final configured = editor.parseAt(configPath) as YamlMap;
    for (final keys in const [
      ['input_dir', 'inputDir'],
      ['output_font', 'out_font_file', 'outFontFile'],
      ['output_class', 'out_class_file', 'outClassFile'],
    ]) {
      final key = keys.firstWhere(configured.containsKey);
      final value = configured[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Expected "$key" to be a non-empty path.');
      }
      final directory = path.absolute(path.dirname(args.pubspecPath));
      final absolute = path.normalize(path.join(directory, value));
      if (keys.first != 'input_dir' && !path.isWithin(directory, absolute)) {
        throw FormatException('"$key" must be inside the Flutter project.');
      }
      editor.update(
        [...configPath, key],
        path
            .relative(absolute, from: directory)
            .split(path.separator)
            .join('/'),
      );
    }
  }
}
