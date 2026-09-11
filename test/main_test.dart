import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/gingacc.dart';
import 'package:gingaf/main.dart';
import 'package:path/path.dart' as path;

void main() {
  group('resolveGingaConfig', () {
    test('resolves default configuration when inputs are null', () async {
      final config = await resolveGingaConfig();
      expect(config.startWithCCWS, isTrue);
      expect(config.appSrc, isNull);
    });

    test('resolves configuration with custom GingaCC', () async {
      final gingacc = GingaCC(
        virtualFiles: {
          'config.json': '{"appSrc": "main.ncl", "startWithCCWS": false}',
        },
      );
      final config = await resolveGingaConfig(
        appSrc: 'main.ncl',
        configSrc: 'config.json',
        gingacc: gingacc,
      );
      expect(config.startWithCCWS, isFalse);
      expect(config.appSrc, equals('main.ncl'));
    });

    test('resolves relative app and config files', () async {
      final prevCwd = Directory.current;
      final tempDir = Directory.systemTemp.createTempSync('main_test_');
      try {
        final subDir = Directory(path.join(tempDir.path, 'sub'))..createSync();
        File(path.join(subDir.path, 'main.ncl')).writeAsStringSync('<ncl/>');
        File(path.join(tempDir.path, 'users.json')).writeAsStringSync('[{"id": "u1", "name": "User 1"}]');
        final configFile = File(path.join(tempDir.path, 'config.json'))
          ..writeAsStringSync('{"appSrc": "sub/main.ncl", "usersDataJson": "users.json"}');

        final config = await resolveGingaConfig(configSrc: configFile.path);
        expect(config.appSrc, equals('main.ncl'));
        expect(config.users.allUsers.length, equals(1));
        expect(config.users.allUsers.first.name, equals('User 1'));
      } finally {
        Directory.current = prevCwd;
        tempDir.deleteSync(recursive: true);
      }
    });

    test('handles HTTP URLs without file resolution', () async {
      final config = await resolveGingaConfig(
        appSrc: 'http://example.com/app.ncl',
      );
      expect(config.appSrc, equals('http://example.com/app.ncl'));
    });
  });
}
