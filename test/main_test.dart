import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/main.dart';

void main() {
  test('main module exports args functions', () {
    expect(parseArgsCliAndEnv, isNotNull);
    expect(resolveGingaConfig, isNotNull);
  });
}
