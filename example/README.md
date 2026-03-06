# icongine example

This app demonstrates generated icon usage from mixed icon sources under `assets/icons`.

The example keeps committed source assets in sibling subfolders:
- `assets/icons/svg` for SVG sources
- `assets/icons/png` for PNG sources

Generation intentionally points at the shared `assets/icons` root and relies on subdirectory prefixes to keep names distinct.

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
  input_dir: assets/icons
  output_font: assets/fonts/example_icons.otf
  output_class: lib/generated/example_icons.dart
  name: ExampleIcons
  include_subdirs: true
  prefix_with_subdir: true
  font_format: otf
  normalize: false
  static_icon_provider: true
  generate_icon_map: true
```
