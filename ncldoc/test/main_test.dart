import 'dart:io';

import 'package:ncldoc/main.dart';
import 'package:test/test.dart';

void main() {
  group('CLI main.dart Tests', () {
    test('exits with code 1 when no arguments provided', () async {
      int? exitCode;
      final code = await runCli([], onExit: (c) => exitCode = c, silent: true);
      expect(code, equals(1));
      expect(exitCode, equals(1));
    });

    test('exits with code 1 when file extension is not .ncl', () async {
      int? exitCode;
      final code = await runCli(['invalid.txt'], onExit: (c) => exitCode = c, silent: true);
      expect(code, equals(1));
      expect(exitCode, equals(1));
    });

    test('parses arguments and starts document for valid .ncl file', () async {
      final tempDir = Directory.systemTemp.createTempSync('cli_test_');
      final nclFile = File('${tempDir.path}/test_app.ncl');
      nclFile.writeAsStringSync('<ncl><body id="body"><media id="m1" src="test.mp4"/></body></ncl>');

      int? exitCode;
      final code = await runCli([nclFile.path, '10'], onExit: (c) => exitCode = c, silent: true);
      tempDir.deleteSync(recursive: true);

      expect(code, equals(0));
      expect(exitCode, isNull);
    });
  });
}
