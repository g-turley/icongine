# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added
- Added CI for formatting, strict analysis, package tests, Flutter example tests, and deterministic example generation.
- Added contributor and architecture guides plus a responsive example catalog widget test.

### Changed
- Split generate argument parsing from CLI dispatch and replaced expected failure stack traces with actionable messages.
- Made artifact replacement atomic per file and kept generated font setup paths relative to the selected pubspec.
- Enabled strict analyzer casts, inference, and raw-type checks.

### Fixed
- Reject icon and class names that cannot produce valid Dart identifiers, including reserved keywords.
- Escape configured font family and package strings in generated Dart source.
- Prevent font and Dart class outputs from targeting the same file.

## [1.1.0] - 2026-03-06

### Added
- Added PNG asset support to the icon generation pipeline.
- Added raster comparison fixtures and a helper tool for validating generated example assets.

### Changed
- Reorganized the processing pipeline to separate contour generation from SVG input handling.
- Moved the example icon sources under `example/assets/icons/` and refreshed the example documentation to match the new asset layout.
- Expanded and updated the test suite to cover the restructured pipeline and PNG workflows.

## [1.0.1] - 2026-03-05

### Fixed
- Default generated `fontPackage` to `null` for app-local Flutter font assets.
- Added optional `font_package` config for dependency-hosted fonts.
- Regenerated the example icon font so `example/assets/fonts/example_icons.otf` is present in the repo.

## [1.0.0] - 2026-03-04

### Added
- Initial public release of `icongine`.
