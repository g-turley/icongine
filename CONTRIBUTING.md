# Contributing to icongine

Thanks for improving icongine. The project favors small, test-backed changes
that keep font output deterministic and preserve the existing CLI shorthand.

## Prerequisites

- Dart 3.11 or newer for the package and CLI
- Flutter stable only when changing or running `example/`

## First setup

From the repository root:

```bash
dart pub get --no-example
dart test
```

The `--no-example` flag keeps core package setup independent of Flutter. To
work on the example as well:

```bash
cd example
flutter pub get
dart run icongine
flutter run
```

## Before opening a pull request

Run the same checks as CI:

```bash
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```

For example changes, also run these commands from `example/`:

```bash
flutter analyze
flutter test
dart run icongine
```

The final generation command must leave
`assets/fonts/example_icons.otf` and
`lib/generated/example_icons.dart` unchanged. Commit both files when an
intentional compiler change updates them.

## Where changes belong

- `lib/src/cli/`: argument parsing, command dispatch, and human-readable output
- `lib/src/domain/`: configuration, source-file identity, and symbol naming
- `lib/src/pipeline/`: discover, compile, and emit orchestration
- `lib/src/pipeline/svg_input/`: SVG parsing and transforms
- `lib/src/pipeline/contour/`: geometry and winding operations
- `lib/src/pipeline/font/`: TTF, OTF, CFF, and SFNT encoding
- `test/test_shapes/`: minimal regression fixtures for geometry behavior

Read [the architecture guide](doc/architecture.md) before changing the
compiler path. Prefer adding the smallest fixture that exposes a geometry bug;
assert structural invariants instead of brittle byte-for-byte output unless
the exact encoding is the behavior under test.

## Compatibility

`dart run icongine`, `dart run icongine generate`, positional pubspec paths,
and documented legacy configuration keys are supported behavior. New options
must have a safe default, work through both CLI and pubspec configuration when
appropriate, and include help text and tests.

Although most low-level types remain exported for compatibility, new product
integrations should enter through `GenerateIconsCommand` and
`GenerationConfig`. Avoid adding new exports unless callers genuinely need the
type.
