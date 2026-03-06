import 'package:path/path.dart' as path;

import '../core/case_ext.dart';
import 'font_format.dart';

enum GlyphEmissionMode { all, basicShapesOnly }

class GenerationConfig {
  GenerationConfig({
    required this.packageName,
    required this.inputDir,
    required this.outClassFile,
    this.outFontFile,
    this.className = 'AppIcons',
    this.includeSubdirs = false,
    this.prefixWithSubdir = false,
    this.fontFormat = FontFormat.otf,
    this.glyphEmissionMode = GlyphEmissionMode.all,
    this.normalize = false,
    this.verbose = false,
    this.staticIconProvider = true,
    this.generateIconMap = false,
  }) : fontFamily = className,
       fontPackage = className {
    if (packageName.trim().isEmpty) {
      throw ArgumentError.value(packageName, 'packageName');
    }
    if (inputDir.trim().isEmpty) {
      throw ArgumentError.value(inputDir, 'inputDir');
    }
    _validateFontFileExtension();
    _validateFontFilePresence();
  }

  final String packageName;
  final String fontFamily;
  final String fontPackage;
  final String inputDir;
  final String outClassFile;
  final String? outFontFile;
  final String className;
  final bool includeSubdirs;
  final bool prefixWithSubdir;
  final FontFormat fontFormat;
  final GlyphEmissionMode glyphEmissionMode;
  final bool normalize;
  final bool verbose;
  final bool staticIconProvider;
  final bool generateIconMap;

  String get normalizedClassName => className.toUpperCamel();

  String relAssetPath(String filePath) {
    return path.relative(filePath, from: inputDir);
  }

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
