# icongine

`icongine` is an icon font generator that turns SVG and PNG assets into
TTF or OTF fonts plus typed `IconData` APIs.

It is built for repeatable icon pipelines:

- Generates OTF or TTF icon fonts from a folder of SVG or PNG files
- Smooths PNG alpha edges by default, including small antialiased icons
- Produces a typed Dart API with one icon constant per glyph
- Optionally generates an `all` map for searchable icon catalogs
- Adds per-glyph SVG preview docs to the generated API
- Keeps naming stable with deterministic collision handling
- Works from `pubspec.yaml`, CLI flags, or programmatic invocation

## From source art to a font

Curves, sharp corners, strokes, organic shapes, radial patterns, and cutouts
can all become monochrome font glyphs. These are actual renders from generated
OTF and TTF files, alongside independently rendered source previews:

![SVG and PNG inputs converted into rendered OTF and TTF glyphs, including thin strokes, basket outlines, continents, a radial pattern, and 25 cutouts.](doc/images/source-to-font.png)

Most PNG inputs above are 64×64. The fine radial pattern uses 256×256 so its
narrow gaps survive. OTF and TTF share the same design; minor rasterization
differences are possible. Source colors become a single silhouette defined by
transparency.

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

## Why use icongine

`icongine` focuses on the package workflow teams usually mean when they search
for a Flutter font generator:

- Generate an icon font from SVG assets
- Generate an icon font from PNG assets
- Generate a typed Dart `IconData` class for Flutter
- Keep icon names deterministic across repeated builds
- Check generated output into your package or app repository

That makes it useful for design-system icon packages, app-local icon fonts, and
internal packages that need a consistent icon generation step.

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
| `png_tracing` | `smooth` | PNG outlines: alpha-aware curves by default, `pixel` for exact pixel edges, or `legacy` to reproduce older output. SVGs are unaffected. |
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

## FAQ

### Do I need `font_package`?

Usually no.

Leave `font_package` unset when your app or package bundles the generated font
itself in its own `flutter.fonts` section. In that case Flutter resolves the
font locally and the generated `IconData` should keep `fontPackage: null`.

Set `font_package` only when the generated font asset lives in a dependency
package and another app imports that package's generated icon class. In Flutter,
dependency-hosted font assets are loaded with the package name, so the generated
icons must pass that package name through `IconData(..., fontPackage: ...)`.

Example for a dependency package:

```yaml
icongine:
  name: ExampleIcons
  output_font: assets/fonts/example_icons.otf
  output_class: lib/src/example_icons.dart
  font_package: my_icon_package
```

Then the consuming app can use `ExampleIcons.home`, and Flutter will look up the
font from package `my_icon_package` instead of the local app bundle.

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

PNG input uses transparency as a monochrome silhouette; RGB colors are ignored.
Use a transparent background: opaque white pixels are filled too.
**Smooth tracing is the default in 1.2.0**, so no extra configuration is needed. It uses
partial alpha values to locate edges between pixels, then fits corner-aware
curves. It protects holes, thin strokes, and separated regions while retaining
safe line contours when a curve would damage the shape.

### Choosing a source size

**Start with a real 64×64 source for ordinary icons.** Simple shapes can work
well at 16–32px; detailed shapes benefit from 128px. Dense linework and very
narrow gaps can still require 256–512px or SVG. Upscaling an existing tiny PNG
cannot restore missing detail.

![Actual font renders from 16, 32, 64, 128 and 512 pixel PNG inputs, showing simple shapes, thin strokes, organic detail, radial patterns and cutouts.](doc/images/png-resolution.png)

We tested eight designs at nine sizes from 16px to 512px. At 64px, median
silhouette overlap against independent SVG references was **99.1% for simple
designs** and **96.6% for detailed designs**; detailed designs reached **98.1%
at 128px**. These results describe this fixture set at a 256px render size,
not a guarantee for every PNG. Tiny gaps can disappear even when an overall
shape looks close. See the [scale study and reproduction steps](doc/png-tracing-study.md)
for measurements, topology checks, limitations, and source provenance.

The library adjusts fitting tolerances for larger source canvases automatically.
It does not resize your image or add an external tracing dependency.

### Tracing modes

The default can be written explicitly:

```yaml
icongine:
  png_tracing: smooth
```

Or run `dart run icongine --png-tracing smooth`.

- `smooth` interpolates alpha boundaries and fits cubic curves. Confident
  interior/exterior samples, nesting, winding, bounds, and sampled crossings
  guard against damaged shapes. Ambiguous antialiased edge samples may move
  within the fit tolerance. Diagonal stroke samples can connect while thick
  nearby regions stay separate. Unsafe or excessively complex fits retain
  interpolated line contours.
- `pixel` traces exact boundaries of pixels with alpha ≥50%, without smoothing;
  use it for intentional pixel art. Diagonally touching pixels remain separate.
- `legacy` keeps the original thresholded tracing and smoothing. Set
  `png_tracing: legacy` or use `--png-tracing legacy` to reproduce older PNG
  output when upgrading.

Smooth tracing works best with antialiased transparency. Binary alpha can also
be smoothed, but missing details cannot be recovered. Use `pixel` for intentional
pixel art. SVGs enter through their vector geometry and do not use PNG tracing.

To inspect actual OTF and TTF output from generated 16×16 fixtures, run
`dart run tool/compare_png_tracing.dart --serve` and open
`http://127.0.0.1:5174`. The fixtures and fonts are written to `build/png_tracing/`.

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
- PNG outlines depend on `png_tracing`; smooth tracing uses interpolated alpha contours and cubic curves, while pixel mode retains the raster grid.
- Units are treated numerically for supported attributes; advanced CSS unit semantics are not fully modeled.
- Stroke expansion is geometric approximation, so tiny visual differences from the source SVG can occur.
- SVG features that depend on rendering effects instead of explicit paths should be converted to paths before running `icongine`.

## Example

`example/` contains a complete Flutter integration with:

- generated icon font assets
- a generated Dart icon class
- an optional searchable `all` icon map

## Development

The core package requires only Dart; Flutter is needed for the example app.
See [CONTRIBUTING.md](CONTRIBUTING.md) for first setup, verification commands,
fixture guidance, and compatibility expectations. The compiler boundaries and
invariants are documented in [doc/architecture.md](doc/architecture.md).

CI checks formatting, static analysis, the full package test suite, the Flutter
example, and that running the documented example generation command leaves its
committed artifacts unchanged.
