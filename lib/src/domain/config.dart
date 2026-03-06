import 'package:path/path.dart' as path;

import '../core/case_ext.dart';
import 'font_format.dart';

/// Controls which glyphs are emitted by the generation pipeline.
enum GlyphEmissionMode { all, basicShapesOnly }

/// Immutable configuration used to generate an icon font and Dart API.
class GenerationConfig {
  GenerationConfig({
    required this.packageName,
    required this.inputDir,
    required this.outClassFile,
    this.outFontFile,
    this.className = 'AppIcons',
    this.fontPackage,
    this.includeSubdirs = false,
    this.prefixWithSubdir = false,
    this.fontFormat = FontFormat.otf,
    this.glyphEmissionMode = GlyphEmissionMode.all,
    this.normalize = false,
    this.verbose = false,
    this.staticIconProvider = true,
    this.generateIconMap = false,
  }) : fontFamily = className {
    if (packageName.trim().isEmpty) {
      throw ArgumentError.value(packageName, 'packageName');
    }
    if (inputDir.trim().isEmpty) {
      throw ArgumentError.value(inputDir, 'inputDir');
    }
    _validateFontFileExtension();
    _validateFontFilePresence();
  }

  /// Package name from `pubspec.yaml`.
  final String packageName;

  /// Flutter font family written into the generated icon class.
  final String fontFamily;

  /// Optional Flutter package name that hosts the generated font asset.
  final String? fontPackage;

  /// Directory containing the source SVG files.
  final String inputDir;

  /// Output path for the generated Dart icon class.
  final String outClassFile;

  /// Output path for the generated font file.
  final String? outFontFile;

  /// Requested Dart class name before normalization.
  final String className;

  /// Whether nested icon directories should be scanned.
  final bool includeSubdirs;

  /// Whether generated symbol names should include subdirectory prefixes.
  final bool prefixWithSubdir;

  /// Font container format used for the generated asset.
  final FontFormat fontFormat;

  /// Glyph emission mode used by low-level generators.
  final GlyphEmissionMode glyphEmissionMode;

  /// Whether glyphs should be normalized to a shared source box.
  final bool normalize;

  /// Whether the pipeline should report verbose diagnostics.
  final bool verbose;

  /// Whether to add Flutter's tree-shaking icon provider annotation.
  final bool staticIconProvider;

  /// Whether to emit an `all` lookup map in the generated icon class.
  final bool generateIconMap;

  /// Normalized Dart class name used by the emitter.
  String get normalizedClassName => className.toUpperCamel();

  /// Returns [filePath] relative to the configured [inputDir].
  String relAssetPath(String filePath) {
    return path.relative(filePath, from: inputDir);
  }

  /// Whether the current configuration writes a font file artifact.
  bool get generatesFontFile => true;

  void _validateFontFileExtension() {
    if (!generatesFontFile) {
      return;
    }

    final outputFontFile = outFontFile;
    if (outputFontFile == null || outputFontFile.trim().isEmpty) {
      return;
    }

    final extension = path.extension(outputFontFile).toLowerCase();
    if (extension != '.ttf' && extension != '.otf') {
      throw ArgumentError.value(
        outputFontFile,
        'outFontFile',
        'outFontFile must end with .ttf or .otf.',
      );
    }

    final expectedExtension = switch (fontFormat) {
      FontFormat.ttf => '.ttf',
      FontFormat.otf => '.otf',
    };
    if (extension != expectedExtension) {
      throw ArgumentError.value(
        outputFontFile,
        'outFontFile',
        'outFontFile extension ($extension) must match '
            'fontFormat ${fontFormat.name} ($expectedExtension).',
      );
    }
  }

  void _validateFontFilePresence() {
    if (generatesFontFile &&
        (outFontFile == null || outFontFile!.trim().isEmpty)) {
      throw ArgumentError.value(
        outFontFile,
        'outFontFile',
        'outFontFile is required when fontFormat is ${fontFormat.name}.',
      );
    }
  }
}
