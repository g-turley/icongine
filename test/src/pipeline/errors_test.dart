import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  test('NamingDiagnosticsError formats messages', () {
    final error = NamingDiagnosticsError(['first failure', 'second failure']);

    expect(error.messages, hasLength(2));
    expect(error.toString(), contains('2 error(s)'));
    expect(error.toString(), contains('first failure | second failure'));
  });
}
