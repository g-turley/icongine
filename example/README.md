# icongine example

This app demonstrates generated icon usage from SVG sources in `assets/svg`.

The example includes a small committed SVG set in `assets/svg` so generation can be reproduced out of the box.

What this example shows:
- generated icon class with typed constants (for example `ExampleIcons.add`)
- generated `ExampleIcons.all` map for catalog/search screens (`generate_icon_map: true`)
- generated docs with per-icon SVG previews inside `lib/generated/example_icons.dart`
- tree-shaking annotation enabled via `static_icon_provider: true`
- formatted generated Dart output (`dart format` style)

## Regenerate icons

From this directory:

```bash
dart run icongine
```

This updates:
- `assets/fonts/example_icons.otf`
- `lib/generated/example_icons.dart`

## Run app

```bash
flutter run
```

The app renders a searchable icon catalog using the generated `ExampleIcons.all` map.

## Example config

`example/pubspec.yaml` keeps every supported option explicit (including defaults where relevant):

```yaml
icongine:
  input_dir: assets/svg
  output_font: assets/fonts/example_icons.otf
  output_class: lib/generated/example_icons.dart
  name: ExampleIcons
  include_subdirs: true
  prefix_with_subdir: false
  font_format: otf
  normalize: false
  static_icon_provider: true
  generate_icon_map: true
```
