import 'dart:io';

import 'package:gingacc/gingacc.dart';
import 'package:test/test.dart';

void main() {
  group('GingaCC resolution Tests', () {
    test('Standard Dart Uri resolves relative and absolute URIs correctly', () {
      final base = Uri.parse('http://example.com/app/main.ncl');
      final relativeUri = base.resolve('video.mp4');
      expect(
          relativeUri.toString(), equals('http://example.com/app/video.mp4'));

      final absoluteUri = base.resolve('http://other.org/asset.png');
      expect(absoluteUri.toString(), equals('http://other.org/asset.png'));
    });

    test('loadContent for file and data URIs', () async {
      final tempDir = Directory.systemTemp.createTempSync('gingacc_test_');
      try {
        final tempFile = File('${tempDir.path}/sample.ncl');
        tempFile.writeAsStringSync('<ncl>test</ncl>');

        final gingacc = GingaCC();
        final fileUri = gingacc.resolveUri(tempFile.absolute.uri.toString());
        final content = await gingacc.loadContent(fileUri);
        expect(content, equals('<ncl>test</ncl>'));

        tempFile.deleteSync();
        expect(await gingacc.loadContent(fileUri), isNull);

        final dataContent =
            await gingacc.loadContent('data:text/plain;utf-8,<ncl>data</ncl>');
        expect(dataContent, equals('<ncl>data</ncl>'));
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('loadContent fetches over HTTP and resolves relative URLs', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((req) {
        if (req.uri.path == '/app/main.ncl') {
          req.response
            ..statusCode = 200
            ..write('<ncl id="http_main"/>');
        } else if (req.uri.path == '/app/script.lua') {
          req.response
            ..statusCode = 200
            ..write('return 99');
        } else {
          req.response.statusCode = 404;
        }
        req.response.close();
      });

      final gingacc = GingaCC();
      final baseUrl = 'http://127.0.0.1:${server.port}/app/main.ncl';
      expect(await gingacc.loadContent(baseUrl), equals('<ncl id="http_main"/>'));
      expect(
        await gingacc.loadContent('script.lua', baseUrl),
        equals('return 99'),
      );
      expect(await gingacc.loadContent('missing.lua', baseUrl), isNull);
    });
  });

  group('GingaCC resolveUri tests', () {
    test('resolves relative path to absolute file URI on desktop', () {
      final gingacc = GingaCC();
      final uri = gingacc.resolveUri('image.png');

      expect(uri.isScheme('file'), isTrue);
      expect(uri.toString(), startsWith('file://'));
      expect(uri, equals(File('image.png').absolute.uri));
      expect(uri.toFilePath(), equals(File('image.png').absolute.path));
    });

    test('resolves path with spaces correctly without breaking toFilePath', () {
      final gingacc = GingaCC();
      final uri = gingacc.resolveUri('my folder/image with spaces.png');

      expect(uri.isScheme('file'), isTrue);
      expect(uri.toString(), startsWith('file://'));
      expect(uri.toString(), contains('my%20folder/image%20with%20spaces.png'));
      final expected = File('my folder/image with spaces.png').absolute;
      expect(uri, equals(expected.uri));
      expect(uri.toFilePath(), equals(File.fromUri(expected.uri).path));
    });

    test('resolves percent-encoded path correctly without double-encoding', () {
      final gingacc = GingaCC();
      final uri = gingacc.resolveUri('my%20folder/image%20with%20spaces.png');

      expect(uri.isScheme('file'), isTrue);
      expect(uri.toString(), startsWith('file://'));
      final expected = File('my folder/image with spaces.png').absolute;
      expect(uri, equals(expected.uri));
      expect(uri.toFilePath(), equals(File.fromUri(expected.uri).path));
    });

    test('resolves relative path against baseDirSrc', () {
      final gingacc = GingaCC();
      final baseDir = Directory.systemTemp.createTempSync('ginga_base_test_');
      try {
        final baseApp = File('${baseDir.path}/nested/app.ncl');
        final uri = gingacc.resolveUri('assets/logo.png', baseApp.path);

        expect(uri.isScheme('file'), isTrue);
        expect(uri.toString(), startsWith('file://'));
        final expected =
            File('${baseDir.path}/nested/assets/logo.png').absolute;
        expect(uri, equals(expected.uri));
        expect(uri.toFilePath(), equals(File.fromUri(expected.uri).path));
      } finally {
        baseDir.deleteSync(recursive: true);
      }
    });

    test('resolves relative path against baseDirSrc containing spaces', () {
      final gingacc = GingaCC();
      final baseDir = Directory.systemTemp.createTempSync('ginga base space_');
      try {
        final baseApp = File('${baseDir.path}/app.ncl');
        final uri = gingacc.resolveUri('sub folder/logo.png', baseApp.path);

        expect(uri.isScheme('file'), isTrue);
        expect(uri.toString(), startsWith('file://'));
        final expected = File('${baseDir.path}/sub folder/logo.png').absolute;
        expect(uri, equals(expected.uri));
        expect(uri.toFilePath(), equals(File.fromUri(expected.uri).path));
      } finally {
        baseDir.deleteSync(recursive: true);
      }
    });

    test('resolves relative path against directory baseDirSrc', () {
      final gingacc = GingaCC();
      final baseDir = Directory.systemTemp.createTempSync('ginga_dir_test_');
      try {
        final uri = gingacc.resolveUri('ginga_config.json', baseDir.path);
        expect(uri.isScheme('file'), isTrue);
        expect(uri.toString(), startsWith('file://'));
        expect(uri,
            equals(File('${baseDir.path}/ginga_config.json').absolute.uri));
      } finally {
        baseDir.deleteSync(recursive: true);
      }
    });

    test('preserves http, https, blob and data URIs', () {
      final gingacc = GingaCC();
      final httpUri = gingacc.resolveUri('https://example.com/video.mp4');
      expect(httpUri.scheme, equals('https'));
      expect(httpUri.toString(), equals('https://example.com/video.mp4'));

      final blobUri = gingacc.resolveUri('blob:http://localhost:5173/blob-123');
      expect(blobUri.scheme, equals('blob'));

      final dataUri = gingacc.resolveUri('data:text/plain,hello');
      expect(dataUri.scheme, equals('data'));
    });

    test('isXmlString detects XML markup correctly', () {
      expect(isXmlString(null), isFalse);
      expect(isXmlString(''), isFalse);
      expect(isXmlString('  '), isFalse);
      expect(isXmlString('image.png'), isFalse);
      expect(isXmlString('<ncl><head/><body/></ncl>'), isTrue);
      expect(isXmlString(' <ncl>content</ncl>'), isTrue);
    });

    test('isHttpUri detects HTTP and HTTPS schemes for String and Uri', () {
      expect(isHttpUri('http://example.com'), isTrue);
      expect(isHttpUri('https://example.com'), isTrue);
      expect(isHttpUri(Uri.parse('http://example.com')), isTrue);
      expect(isHttpUri(Uri.parse('https://example.com')), isTrue);
      expect(isHttpUri('file:///path/to/file'), isFalse);
      expect(isHttpUri('main.ncl'), isFalse);
      expect(isHttpUri(null), isFalse);
      expect(isHttpUri(123), isFalse);
    });
  });

  group('GingaCC loadContentSync tests', () {
    test('returns XML string directly', () {
      final gingacc = GingaCC();
      const xml = '<ncl><head/><body/></ncl>';
      expect(gingacc.loadContentSync(xml), equals(xml));
    });

    test('decodes data URIs synchronously', () {
      final gingacc = GingaCC();
      expect(
        gingacc.loadContentSync('data:text/plain;charset=utf-8,hello%20world'),
        equals('hello world'),
      );
      expect(
        gingacc.loadContentSync('data:text/plain;base64,aGVsbG8gd29ybGQ='),
        equals('hello world'),
      );
    });

    test('loads nested local files synchronously', () {
      final tempDir =
          Directory.systemTemp.createTempSync('ginga_nested_sync_test_');
      try {
        final levelsDir = Directory('${tempDir.path}/levels')..createSync();
        File('${levelsDir.path}/1.txt')
            .writeAsStringSync('WWWWW\nW P W\nWWWWW');
        File('${tempDir.path}/config.lua')
            .writeAsStringSync('return { speed = 10 }');

        final gingacc = GingaCC();
        expect(
          gingacc.loadContentSync('${tempDir.path}/levels/1.txt'),
          equals('WWWWW\nW P W\nWWWWW'),
        );
        expect(
          gingacc.loadContentSync('${tempDir.path}/config.lua'),
          equals('return { speed = 10 }'),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('reads local file synchronously from disk', () {
      final gingacc = GingaCC();
      final tempDir = Directory.systemTemp.createTempSync('ginga_sync_test_');
      try {
        final testFile = File('${tempDir.path}/sample.txt');
        testFile.writeAsStringSync('sample synchronous content');

        final content = gingacc.loadContentSync(testFile.path);
        expect(content, equals('sample synchronous content'));

        final uriContent = gingacc.loadContentSync(testFile.uri);
        expect(uriContent, equals('sample synchronous content'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('reads local file synchronously relative to baseDirSrc', () {
      final gingacc = GingaCC();
      final tempDir = Directory.systemTemp.createTempSync('ginga_sync_base_');
      try {
        final subDir = Directory('${tempDir.path}/scripts')..createSync();
        final mainNcl = File('${tempDir.path}/main.ncl');
        mainNcl.writeAsStringSync('<ncl/>');
        final scriptFile = File('${subDir.path}/logic.lua');
        scriptFile.writeAsStringSync('local x = 42');

        final content =
            gingacc.loadContentSync('scripts/logic.lua', mainNcl.path);
        expect(content, equals('local x = 42'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns null for empty input or non-existent file', () {
      final gingacc = GingaCC();
      expect(gingacc.loadContentSync(''), isNull);
      expect(gingacc.loadContentSync('   '), isNull);
      expect(
        gingacc.loadContentSync('non_existent_file_123456.txt'),
        isNull,
      );
    });
  });

  group('GingaCC loadConfig tests', () {
    test('loadConfig with GingaConfig instance', () {
      final gingacc = GingaCC();
      final newConfig = GingaConfig(startWithCCWS: true);
      final result = gingacc.loadConfig(newConfig);
      expect(result, equals(newConfig));
      expect(gingacc.config, equals(newConfig));
      expect(gingacc.config.startWithCCWS, isTrue);
    });

    test('loadConfig with JSON string', () async {
      final gingacc = GingaCC();
      final result = await gingacc.loadConfig('{"startWithCCWS": true}');
      expect(result.startWithCCWS, isTrue);
      expect(gingacc.config.startWithCCWS, isTrue);
    });

    test('loadConfig with null resets to default GingaConfig', () {
      final gingacc = GingaCC(config: GingaConfig(startWithCCWS: true));
      gingacc.loadConfig(null);
      expect(gingacc.config.startWithCCWS, isFalse);
    });

    test('loadConfig with GingaConfig and appSrc sets appSrc', () {
      final gingacc = GingaCC();
      final newConfig = GingaConfig(startWithCCWS: true);
      final result = gingacc.loadConfig(newConfig, 'main.ncl');
      expect((result as GingaConfig).appSrc, equals('main.ncl'));
      expect(gingacc.config.appSrc, equals('main.ncl'));
    });

    test('loadConfig with appSrc only resolves config and sets appSrc',
        () async {
      final gingacc = GingaCC();
      final result = await gingacc.loadConfig(null, 'main.ncl');
      expect(result.startWithCCWS, isTrue);
      expect(result.appSrc, equals('main.ncl'));
      expect(gingacc.config.appSrc, equals('main.ncl'));
    });

    test('loadConfig with configSrc and appSrc resolves both', () async {
      final savedCwd = Directory.current.path;
      final tempDir =
          Directory.systemTemp.createTempSync('ginga_loadcfg_test_');
      try {
        final cfgFile = File('${tempDir.path}/config.json')
          ..writeAsStringSync('{"appSrc": "main.ncl", "startWithCCWS": false}');
        final appFile = File('${tempDir.path}/main.ncl')
          ..writeAsStringSync('<ncl/>');
        final gingacc = GingaCC();
        final result = await gingacc.loadConfig(cfgFile.path, appFile.path);
        expect(result.startWithCCWS, isFalse);
        expect(result.appSrc, equals('main.ncl'));
        expect(gingacc.config.appSrc, equals('main.ncl'));
      } finally {
        Directory.current = savedCwd;
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
