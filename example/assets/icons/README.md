# Example Icon Assets

This folder contains the example app's icon source inputs.

Layout:
- `svg/` contains vector source icons.
- `png/` contains raster source icons.

The example generator reads from the shared `assets/icons` root with subdirectory inclusion enabled, so keep source types in their own subfolders and preserve the folder prefixes in generated names.

The SVG files were copied from `test/test_shapes` to keep the example reproducible from local source assets. PNGs are raster counterparts used to exercise the PNG pipeline.

License: MIT (ionicons).
