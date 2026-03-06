import 'dart:io';

import 'package:path/path.dart' as path;

import '../domain/icon_file.dart';

abstract interface class IconScan {
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

    final svgFiles =
        root
            .listSync(recursive: includeSubdirs)
            .whereType<File>()
            .where((file) => path.extension(file.path).toLowerCase() == '.svg')
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    return svgFiles
        .map(
          (file) => IconFile(
            absolutePath: file.path,
            relativePath: path.relative(file.path, from: root.path),
          ),
        )
        .toList(growable: false);
  }
}
