import 'dart:io';

import 'package:gingacc/gingacc.dart';
import 'package:test/test.dart';

void main() {
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
        final expected = File('${baseDir.path}/nested/assets/logo.png').absolute;
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
        expect(uri, equals(File('${baseDir.path}/ginga_config.json').absolute.uri));
      } finally {
        baseDir.deleteSync(recursive: true);
      }
    });

    test('preserves http, https and data URIs', () {
      final gingacc = GingaCC();
      final httpUri = gingacc.resolveUri('https://example.com/video.mp4');
      expect(httpUri.scheme, equals('https'));
      expect(httpUri.toString(), equals('https://example.com/video.mp4'));

      final dataUri = gingacc.resolveUri('data:text/plain,hello');
      expect(dataUri.scheme, equals('data'));
    });

    test('preserves virtual files', () {
      final gingacc = GingaCC(virtualFiles: {
        'my_virtual.png': 'https://example.com/virtual.png',
      });
      final uri = gingacc.resolveUri('my_virtual.png');
      expect(uri.toString(), equals('https://example.com/virtual.png'));
    });

    test('resolves virtual files with spaces and percent encoding', () {
      final gingacc = GingaCC(virtualFiles: {
        'my image.png': 'blob:http://localhost:5173/blob-123',
        'folder with spaces/pic.png': 'https://example.com/pic.png',
      });

      expect(gingacc.resolveUri('my image.png').toString(),
          equals('blob:http://localhost:5173/blob-123'));
      expect(gingacc.resolveUri('my%20image.png').toString(),
          equals('blob:http://localhost:5173/blob-123'));
      expect(gingacc.resolveUri('my image.png', 'main.ncl').toString(),
          equals('blob:http://localhost:5173/blob-123'));
      expect(gingacc.resolveUri('my%20image.png', 'main.ncl').toString(),
          equals('blob:http://localhost:5173/blob-123'));
      expect(gingacc.resolveUri('pic.png', 'folder with spaces/main.ncl').toString(),
          equals('https://example.com/pic.png'));
      expect(gingacc.resolveUri('pic.png', 'folder%20with%20spaces/main.ncl').toString(),
          equals('https://example.com/pic.png'));
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

    test('loads virtual file content synchronously', () {
      final gingacc = GingaCC(virtualFiles: {
        'levels/1.txt': 'WWWWW\nW P W\nWWWWW',
        'config.lua': 'return { speed = 10 }',
      });

      expect(
        gingacc.loadContentSync('levels/1.txt'),
        equals('WWWWW\nW P W\nWWWWW'),
      );
      expect(
        gingacc.loadContentSync('config.lua'),
        equals('return { speed = 10 }'),
      );
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

        final content = gingacc.loadContentSync('scripts/logic.lua', mainNcl.path);
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
}
