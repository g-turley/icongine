import 'dart:io';

import 'package:test/test.dart';
import 'package:icongine/icongine.dart';
import 'package:path/path.dart' as path;

void main() {
  group('FileIconScan', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('icongine_scan_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('lists supported icon files in deterministic path order', () async {
      final root = Directory(path.join(tempDir.path, 'icons'));
      await root.create(recursive: true);

      await File(path.join(root.path, 'zeta.svg')).writeAsString('<svg/>');
      await File(path.join(root.path, 'alpha.svg')).writeAsString('<svg/>');
      await File(path.join(root.path, 'beta.png')).writeAsBytes([0]);
      await File(path.join(root.path, 'ignore.txt')).writeAsString('x');

      const scan = FileIconScan();
      final files = scan.listSvgFiles(
        inputDir: root.path,
        includeSubdirs: false,
      );

      expect(files.map((file) => file.relativePath).toList(), [
        'alpha.svg',
        'beta.png',
        'zeta.svg',
      ]);
    });

    test('includes nested files only when includeSubdirs is true', () async {
      final root = Directory(path.join(tempDir.path, 'icons'));
      final nested = Directory(path.join(root.path, 'a', 'b'));
      await nested.create(recursive: true);

      await File(path.join(root.path, 'top.svg')).writeAsString('<svg/>');
      await File(path.join(nested.path, 'deep.svg')).writeAsString('<svg/>');

      const scan = FileIconScan();

      final flat = scan.listSvgFiles(
        inputDir: root.path,
        includeSubdirs: false,
      );
      final deep = scan.listSvgFiles(inputDir: root.path, includeSubdirs: true);

      expect(flat.map((file) => file.relativePath).toList(), ['top.svg']);
      expect(deep.map((file) => file.relativePath).toList(), [
        path.join('a', 'b', 'deep.svg'),
        'top.svg',
      ]);
    });
  });
}
