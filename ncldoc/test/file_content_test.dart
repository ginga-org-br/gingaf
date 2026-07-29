import 'dart:io';

import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('FileContentLoader and Uri resolution Tests', () {
    test('Standard Dart Uri resolves relative and absolute URIs correctly', () {
      final base = Uri.parse('http://example.com/app/main.ncl');
      final relativeUri = base.resolve('video.mp4');
      expect(relativeUri.toString(), equals('http://example.com/app/video.mp4'));

      final absoluteUri = base.resolve('http://other.org/asset.png');
      expect(absoluteUri.toString(), equals('http://other.org/asset.png'));
    });

    test('FileContentLoader exists and load for file and non-file URIs', () async {
      const loader = FileContentLoader();

      final httpUri = Uri.parse('http://example.com/file.ncl');
      expect(loader.exists(httpUri), isFalse);
      expect(await loader.load(httpUri), isNull);

      final tempDir = Directory.systemTemp.createTempSync('ncldoc_test_');
      final tempFile = File('${tempDir.path}/sample.ncl');
      tempFile.writeAsStringSync('<ncl>test</ncl>');

      final fileUri = tempFile.absolute.uri;
      expect(loader.exists(fileUri), isTrue);

      final content = await loader.load(fileUri);
      expect(content, equals('<ncl>test</ncl>'));

      tempFile.deleteSync();
      expect(loader.exists(fileUri), isFalse);
      expect(await loader.load(fileUri), isNull);

      tempDir.deleteSync();
    });

    test('Custom ContentLoader subclass can override exists and load', () async {
      final customLoader = _CustomTestContentLoader();
      final customUri = Uri.parse('custom://app/data.xml');

      expect(customLoader.exists(customUri), isTrue);
      expect(await customLoader.load(customUri), equals('<data>custom</data>'));

      final otherUri = Uri.parse('http://example.com/other');
      expect(customLoader.exists(otherUri), isFalse);
      expect(await customLoader.load(otherUri), isNull);
    });
  });
}

class _CustomTestContentLoader extends ContentLoader {
  const _CustomTestContentLoader();

  @override
  bool exists(Uri uri) => uri.scheme == 'custom';

  @override
  Future<String?> load(Uri uri) async {
    if (exists(uri)) {
      return '<data>custom</data>';
    }
    return null;
  }
}
