# icongine

`icongine` generates icon fonts and typed `IconData` APIs from SVG and PNG assets.

It is built for repeatable Flutter icon pipelines:

- Generates OTF or TTF icon fonts from a folder of SVG or PNG files
- Produces a typed Dart API with one icon constant per glyph
- Optionally generates an `all` map for searchable icon catalogs
- Adds per-glyph SVG preview docs to the generated API
- Keeps naming stable with deterministic collision handling
- Works from `pubspec.yaml`, CLI flags, or programmatic invocation

## Quick start

Add `icongine` as a `dev_dependency`:

```bash
dart pub add dev:icongine
```

Configure your Flutter package or app:

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
  font_format: otf
```

The `flutter.fonts` entry is required so Flutter bundles the generated font.

Generate the font and Dart class:

```bash
dart run icongine
```

Use the generated icons in Flutter:

```dart
import 'package:flutter/widgets.dart';
import 'app_icons.dart';

class DemoIcon extends StatelessWidget {
  const DemoIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(AppIcons.home, size: 20);
  }
}
```

## How it works

1. Reads the `icongine` section from `pubspec.yaml`.
2. Scans supported icon source files from `input_dir`.
3. Converts supported SVG geometry or PNG alpha masks into font glyphs.
4. Writes the font file and a generated Dart icon class.

## Configuration

All options can be set in `pubspec.yaml`. CLI flags override the matching
`pubspec.yaml` value.

| Option | Default | Description |
| --- | --- | --- |
| `name` | `AppIcons` | Generated Dart class name and font family. |
| `input_dir` | `assets/icons` | Directory containing source SVG or PNG files. |
| `output_font` | `assets/fonts/icons.otf` | Generated font output path. |
| `output_class` | `lib/app_icons.dart` | Generated Dart API output path. |
| `font_package` | unset | Optional Flutter package name to use when the generated font is bundled by a dependency instead of the local app. |
| `font_format` | `otf` | Font format: `otf` or `ttf`. |
| `include_subdirs` | `false` | Recurse into nested icon directories. |
| `prefix_with_subdir` | `false` | Prefix generated icon names with relative subdirectory names. |
| `normalize` | `false` | Normalize icons to a shared source box before fitting to the em square. |
| `verbose` | `false` | Print more generation details. |
| `static_icon_provider` | `true` | Add Flutter's tree-shaking annotation to the generated icon class. |
| `generate_icon_map` | `false` | Generate `static const Map<String, IconData> all` for catalog-style UIs. |

Example with more options enabled:

```yaml
icongine:
  name: AppIcons
  input_dir: assets/icons
  output_font: assets/fonts/icons.otf
  output_class: lib/app_icons.dart
  # Set only when the generated font lives in a dependency package.
  # font_package: my_icon_package
  include_subdirs: true
  prefix_with_subdir: false
  normalize: false
  verbose: false
  font_format: otf
  static_icon_provider: true
  generate_icon_map: true
```

## CLI usage

Run from your package root:

```bash
dart run icongine
dart run icongine generate --config path/to/pubspec.yaml
```

Or activate it globally:

```bash
dart pub global activate icongine
icongine --version
icongine generate --help
icongine debug-shape --help
```

Common overrides:

```bash
icongine generate \
  --input-dir assets/icons \
  --output-font assets/fonts/icons.otf \
  --output-class lib/app_icons.dart \
  --class-name AppIcons \
  --font-format otf \
  --generate-icon-map
```

Debug an SVG shape when a user reports broken icon output:

```bash
icongine debug-shape walk-outline
icongine debug-shape path/to/problem_icon.svg
```

This prints the raw extracted paths, stroke-expansion diagnostics, and the final
compiled contour summary so users can attach the output to bug reports.

`normalize` changes how glyphs are fit before output:

- `false`: keep each icon's own source bounds and fit directly to the em square.
- `true`: normalize icons to a shared source reference box first, then fit to the em square.

When normalization is enabled and the source SVG dimensions differ, `icongine`
prints a warning with the chosen source reference size and output coordinate
system. If `verbose` is enabled, it also reports which glyphs were modified.

## PNG support

PNG input is supported for monochrome-style source art with transparency:

- Opaque or semi-opaque pixels are treated as filled geometry.
- Raster fills are converted into merged pixel-aligned rectangles before font compilation.
- Transparent pixels are ignored.
- A resolution of 512x512 is recommended, but depending on your icon a lower resolution may still produce satisfactory results.

PNG sources work best for crisp silhouette assets with transparent backgrounds.
Because fonts are vector outlines, raster antialiasing is not preserved, and
low-resolution PNGs will produce visibly blocky glyphs.

## Programmatic usage

For tool integrations or custom orchestration, call the command layer directly:

```dart
import 'package:icongine/icongine.dart';

final command = GenerateIconsCommand();
final report = await command.run(pubspecPath: 'pubspec.yaml');

print('Font output: ${report.fontOutputPath}');
print('Class output: ${report.classOutputPath}');
```

## SVG support matrix

Legend: ✅ fully supported, ⚠️ partially supported, ❌ not supported

| SVG feature | Status | Notes |
| --- | --- | --- |
| Basic shape elements (`path`, `rect`, `circle`, `ellipse`, `line`, `polyline`, `polygon`) | ✅ | Converted to contour paths before font compilation. |
| Path commands (`M/L/H/V/C/S/Q/T/A/Z`, absolute and relative) | ✅ | Parsed directly from `d` data. |
| Fill rules (`nonzero`, `evenodd`) | ✅ | Applied and normalized for font winding semantics. |
| Element and group transforms | ✅ | Supports `matrix`, `translate`, `scale`, `rotate`, `skewX`, and `skewY`, including inherited composition. |
| Stroke conversion to filled outlines | ⚠️ | Supports common stroke properties; curved and arc-heavy strokes are approximated during expansion. |
| Style and presentation attributes | ⚠️ | Reads inherited `style` and relevant geometry paint attributes such as `fill`, `fill-opacity`, and stroke properties. |
| `clip-path` | ⚠️ | Supports `clip-path: url(#id)` when the referenced `<clipPath>` resolves to a `<rect>`. |
| Viewport sizing | ⚠️ | Uses `viewBox` when present, otherwise falls back to `width` and `height`, then `24x24`. |
| Paint servers (`linearGradient`, `radialGradient`, `pattern`) | ❌ | Not used for geometry generation. |
| `mask`, `filter`, compositing, blend effects | ❌ | Not applied in geometry compilation. |
| `<text>`, `<image>`, `<use>` indirection | ❌ | Not converted into glyph geometry. |
| Non-rectangular clip paths | ❌ | Only rectangular clip paths are supported. |

## Known limitations

- Output glyphs are monochrome geometry, so color, gradients, and similar paint effects are not preserved.
- PNG input is alpha-thresholded into pixel-aligned geometry rather than bezier-traced outlines.
- Units are treated numerically for supported attributes; advanced CSS unit semantics are not fully modeled.
- Stroke expansion is geometric approximation, so tiny visual differences from the source SVG can occur.
- SVG features that depend on rendering effects instead of explicit paths should be converted to paths before running `icongine`.

## Example

`example/` contains a complete Flutter integration with:

- generated icon font assets
- a generated Dart icon class
- an optional searchable `all` icon map
