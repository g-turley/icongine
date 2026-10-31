# Configuration reference

Configure a single font under `icongine` in `pubspec.yaml`, or multiple fonts
under `icongine.sets.<name>`. Paths are relative to that pubspec; CLI options
override saved values.

## Options

These are the underlying defaults. New `init` setups also enable
`include_subdirs` and `prefix_with_subdir`.

| Option | Default | Purpose |
| --- | --- | --- |
| `name` | `AppIcons` | Dart class name and Flutter font family. |
| `input_dir` | `assets/icons` | Source SVG/PNG folder. |
| `output_font` | `assets/fonts/icons.otf` | Generated `.otf` or `.ttf` file. |
| `output_class` | `lib/app_icons.dart` | Generated Dart API. |
| `font_format` | `otf` | `otf` or `ttf`; must match the destination extension. |
| `font_package` | unset | Dependency package hosting the font; see below. |
| `include_subdirs` | `false` | Scan nested folders. |
| `prefix_with_subdir` | `false` | Include folder names in icon identifiers. |
| `png_tracing` | `smooth` | `smooth`, `pixel`, or `legacy`; SVGs are unaffected. |
| `normalize` | `false` | Recenter visible artwork; see [normalization](#normalization). |
| `static_icon_provider` | `true` | Enable Flutter icon tree shaking. |
| `generate_icon_map` | `false` | Add an `all` map for searchable catalogs. |
| `verbose` | `false` | Print pipeline details and diagnostics. |

For manual setup, register the generated font as well as its generation settings:

```yaml
flutter:
  fonts:
    - family: AppIcons
      fonts:
        - asset: assets/fonts/icons.otf

icongine:
  name: AppIcons
  input_dir: assets/icons
  output_font: assets/fonts/icons.otf
  output_class: lib/app_icons.dart
```

## Init behavior

`dart run icongine init` uses the default paths above. Override them with
`--input-dir`, `--output-font`, `--output-class`, and `--class-name`.
`init` infers the format from the font extension and registers it with Flutter.

- An empty or missing source folder is created; add icons and run generation.
- `--no-generate` saves setup without generating files.
- Existing settings are retained unless explicitly overridden. Unrelated pubspec
  content and comments are preserved, and font registration is not duplicated.
- Existing output files are replaced only when already configured for icongine.
- `--config path/to/pubspec.yaml` selects another Flutter project.

## Named sets

`init --set <name>` adds or updates one set. Names must start with a lowercase
letter and contain only lowercase letters, digits, hyphens, or underscores.
For example, the configuration for two TTF sets can be written as:

```yaml
icongine:
  sets:
    ui:
      input_dir: assets/ui
      output_font: assets/fonts/ui.ttf
    brands:
      input_dir: assets/brands
      output_font: assets/fonts/brands.ttf
```

Each set gets its own defaults: `ui` uses `UiIcons`, `lib/ui_icons.dart`,
`assets/icons/ui`, and `assets/fonts/ui.otf` unless overridden. Named sets infer
TTF from a `.ttf` destination when `font_format` is omitted. Put generation
options inside each set, rather than alongside `sets`.

Run `dart run icongine` for all sets or `dart run icongine --set brands` for one.
When several sets exist, `init` requires `--set`. Adding a named set to an
existing single-set configuration preserves the original as `default`, with its
existing family and output paths.

Families, generated class names, and output files must be distinct; collisions
are checked before generation. Path or class-name overrides require `--set`
when multiple sets exist. Use separate source folders for independent sets:
recursive scanning includes nested folders.

Generation runs in pubspec order and stops on a source error. Completed sets
are reported and their files remain; fix the failing source and rerun its set.

## Fonts hosted by a package

Leave `font_package` unset for app-local fonts. Set it to the dependency's package
name when another app imports an icon API whose font is bundled by that package:

```yaml
icongine:
  name: BrandIcons
  output_font: assets/fonts/brand.otf
  output_class: lib/brand_icons.dart
  font_package: my_icon_package
```

The generated `IconData` then passes `fontPackage: 'my_icon_package'` to Flutter.

## Normalization

Leave `normalize` off to preserve source padding and placement. Every source
already scales into the font, including mixed PNG resolutions. Enabling it
recenters visible artwork; this can correct an accidental offset but changes
intentional positioning. It does not improve tracing or recover detail.
The [README comparison](../README.md#configuration) shows both cases.

With mixed source dimensions, normalization uses the majority canvas size
(more than half the icons), or the largest canvas area if there is no majority.
It rescales sources to that reference before centering, preserves aspect ratios,
and does not make every visible shape the same size.

## Source support

PNGs produce a monochrome silhouette from transparency, ignoring RGB colors.
Opaque white backgrounds are filled too. Antialiased transparency gives smooth
tracing the most edge information; lost details cannot be recovered.

| PNG mode | Use |
| --- | --- |
| `smooth` | Default alpha-aware curves, retaining safe line contours when fitting would damage the shape. |
| `pixel` | Exact edges at alpha ≥50%, including separate diagonally touching pixels. |
| `legacy` | Reproduce the earlier thresholded tracing and smoothing. |

See the [PNG scale study](png-tracing-study.md) for source-size comparisons.

| SVG feature | Support |
| --- | --- |
| Basic shapes and path commands, including curves and arcs | Supported. |
| Fill rules and element/group transforms | Supported. |
| Strokes | Converted to outlines; curved strokes are approximated. |
| Styles and presentation attributes | Geometry-related paint properties and inheritance are supported. |
| Clipping | Rectangular `clipPath` geometry only. |
| Viewports | `viewBox`, then `width`/`height`, falling back to 24×24. |
| Gradients, patterns, masks, filters, and blend effects | Not rendered; convert artwork to plain paths. |
| Text, embedded images, and `use` references | Not converted; expand them into paths first. |

Output is monochrome geometry. Color and rendering effects are not preserved;
advanced CSS units are not fully modeled.

## CLI

`generate` is optional: `dart run icongine` and `dart run icongine generate`
both use the saved configuration. Use `--config` or a positional pubspec path
to select another project. Run `generate --help` for all overrides, including
`--png-tracing`, `--generate-icon-map`, and their matching configuration options.

For a global executable:

```sh
dart pub global activate icongine
icongine --help
```

To inspect a broken SVG, use `dart run icongine debug-shape path/to/icon.svg`.
It prints extracted paths, stroke diagnostics, and compiled contour details
for bug reports.

## Programmatic generation

```dart
import 'package:icongine/icongine.dart';

final command = GenerateIconsCommand();
final report = await command.run(pubspecPath: 'pubspec.yaml');
print(report.fontOutputPath);
```

For named sets, `await command.runAll(pubspecPath: 'pubspec.yaml')` returns a
map of reports keyed by set name. To generate one through `run`, pass
`overrides: const GenerateConfigOverrides(setName: 'brands')`.
