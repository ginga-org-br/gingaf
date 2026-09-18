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
      expect(uri, equals(File('my folder/image with spaces.png').absolute.uri));
      expect(uri.toFilePath(), equals(File('my folder/image with spaces.png').absolute.path));
    });

    test('resolves percent-encoded path correctly without double-encoding', () {
      final gingacc = GingaCC();
      final uri = gingacc.resolveUri('my%20folder/image%20with%20spaces.png');

      expect(uri.isScheme('file'), isTrue);
      expect(uri.toString(), startsWith('file://'));
      expect(uri, equals(File('my folder/image with spaces.png').absolute.uri));
      expect(uri.toFilePath(), equals(File('my folder/image with spaces.png').absolute.path));
    });

    test('resolves relative path against baseDirSrc', () {
      final gingacc = GingaCC();
      final baseDir = Directory.systemTemp.createTempSync('ginga_base_test_');
      try {
        final baseApp = File('${baseDir.path}/nested/app.ncl');
        final uri = gingacc.resolveUri('assets/logo.png', baseApp.path);

        expect(uri.isScheme('file'), isTrue);
        expect(uri.toString(), startsWith('file://'));
        expect(uri, equals(File('${baseDir.path}/nested/assets/logo.png').absolute.uri));
        expect(uri.toFilePath(), equals(File('${baseDir.path}/nested/assets/logo.png').path));
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
        expect(uri, equals(File('${baseDir.path}/sub folder/logo.png').absolute.uri));
        expect(uri.toFilePath(), equals(File('${baseDir.path}/sub folder/logo.png').path));
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
      final gingacc = GingaCC();
      expect(gingacc.isXmlString(null), isFalse);
      expect(gingacc.isXmlString(''), isFalse);
      expect(gingacc.isXmlString('  '), isFalse);
      expect(gingacc.isXmlString('image.png'), isFalse);
      expect(gingacc.isXmlString('<ncl><head/><body/></ncl>'), isTrue);
      expect(gingacc.isXmlString(' <ncl>content</ncl>'), isTrue);
    });
  });
}
