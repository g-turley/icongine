import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  group('CaseExt', () {
    test('converts kebab, spaced, snake to lower camel', () {
      expect('arrow-right-icon'.toLowerCamel(), 'arrowRightIcon');
      expect('arrow_right_icon'.toLowerCamel(), 'arrowRightIcon');
      expect('arrow right icon'.toLowerCamel(), 'arrowRightIcon');
      expect('arrow right-icon'.toLowerCamel(), 'arrowRightIcon');
    });

    test('converts kebab, spaced, snake to upper camel', () {
      expect('arrow-right-icon'.toUpperCamel(), 'ArrowRightIcon');
      expect('arrow_right_icon'.toUpperCamel(), 'ArrowRightIcon');
      expect('arrow right icon'.toUpperCamel(), 'ArrowRightIcon');
      expect('arrow right-icon'.toUpperCamel(), 'ArrowRightIcon');
    });

    test('handles existing camel and acronym boundaries', () {
      expect('myHTTPServer'.toLowerCamel(), 'myHttpServer');
      expect('XMLHttpRequest'.toUpperCamel(), 'XmlHttpRequest');
    });
  });
}
