import 'dart:io';

import 'package:icongine/icongine.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('package version matches pubspec version', () {
    final pubspecContents = File('pubspec.yaml').readAsStringSync();
    final pubspecDocument = loadYaml(pubspecContents) as YamlMap;
    final pubspecVersion = pubspecDocument['version'] as String;

    expect(icongineVersion, pubspecVersion);
  });
}
