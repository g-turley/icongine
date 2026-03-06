import 'dart:io';

import 'package:path/path.dart' as path;

import '../domain/icon_file.dart';

abstract interface class IconScan {
  /// Lists supported icon source files in [inputDir].
  List<IconFile> listSvgFiles({
    required String inputDir,
    required bool includeSubdirs,
  });
}

class FileIconScan implements IconScan {
  const FileIconScan();

  @override
  List<IconFile> listSvgFiles({
    required String inputDir,
    required bool includeSubdirs,
  }) {
    final root = Directory(inputDir);
    if (!root.existsSync()) {
      return const [];
    }

    const supportedExtensions = {'.svg', '.png'};
    final sourceFiles =
        root
            .listSync(recursive: includeSubdirs)
            .whereType<File>()
            .where(
              (file) => supportedExtensions.contains(
                path.extension(file.path).toLowerCase(),
              ),
            )
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    return sourceFiles
        .map(
          (file) => IconFile(
            absolutePath: file.path,
            relativePath: path.relative(file.path, from: root.path),
          ),
        )
        .toList(growable: false);
  }
}
