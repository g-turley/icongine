import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  group('PathNamer', () {
    const namer = PathNamer();

    test('uses basename when prefixWithSubdir is off', () {
      final symbol = namer.symbolFor(
        relativePath: 'food/carrot-icon.svg',
        prefixWithSubdir: false,
      );

      expect(symbol, 'carrotIcon');
    });

    test('uses subdirectory segments when prefixWithSubdir is on', () {
      final symbol = namer.symbolFor(
        relativePath: 'food/carrot-icon.svg',
        prefixWithSubdir: true,
      );

      expect(symbol, 'foodCarrotIcon');
    });
  });
}
