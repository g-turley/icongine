# Example Icon Assets

This folder contains the example app's icon source inputs.

Layout:
- `svg/` contains vector source icons.

The example generator reads from the shared `assets/icons` root with subdirectory inclusion enabled, so keep source types in their own subfolders and preserve the folder prefixes in generated names.

The SVG files were copied from `test/test_shapes` to keep the example reproducible from local source assets. PNG comparison snapshots live under `assets/raster_compare/`; they are not generator inputs.

License: MIT (ionicons).
