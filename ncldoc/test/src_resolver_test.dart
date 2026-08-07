import 'dart:io';

import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('BaseSrcResolver and Uri resolution Tests', () {
    test('Standard Dart Uri resolves relative and absolute URIs correctly', () {
      final base = Uri.parse('http://example.com/app/main.ncl');
      final relativeUri = base.resolve('video.mp4');
      expect(relativeUri.toString(), equals('http://example.com/app/video.mp4'));

      final absoluteUri = base.resolve('http://other.org/asset.png');
      expect(absoluteUri.toString(), equals('http://other.org/asset.png'));
    });

    test('BaseSrcResolver exists and load for file and data URIs', () async {
      const loader = BaseSrcResolver();

      final httpUri = loader.resolveUri('http://example.com/file.ncl');
      expect(loader.exists(httpUri), isTrue);

      final tempDir = Directory.systemTemp.createTempSync('ncldoc_test_');
      final tempFile = File('${tempDir.path}/sample.ncl');
      tempFile.writeAsStringSync('<ncl>test</ncl>');

      final fileUri = loader.resolveUri(tempFile.absolute.uri.toString());
      expect(loader.exists(fileUri), isTrue);

      final content = await loader.load(fileUri);
      expect(content, equals('<ncl>test</ncl>'));

      tempFile.deleteSync();
      expect(loader.exists(fileUri), isFalse);
      expect(await loader.load(fileUri), isNull);

      tempDir.deleteSync();
    });

    test('Custom SrcResolver subclass can override exists and load', () async {
      final customLoader = _CustomTestSrcResolver();
      final customUri = customLoader.resolveUri('custom://app/data.xml');

      expect(customLoader.exists(customUri), isTrue);
      expect(await customLoader.load(customUri), equals('<data>custom</data>'));

      final otherUri = customLoader.resolveUri('http://example.com/other');
      expect(customLoader.exists(otherUri), isFalse);
      expect(await customLoader.load(otherUri), isNull);
    });

    test('NCLParser with BaseSrcResolver handles non-existent local file src gracefully', () {
      final parser = NCLParser(
        docUri: Uri.parse('file:///non_existent_dir/doc.ncl'),
        contentLoader: const BaseSrcResolver(),
      );
      const xml = '<ncl><body><media id="m1" src="non_existent_file.mp4"/></body></ncl>';
      expect(() => parser.parseString(xml), throwsA(anything));
    });
  });
}

class _CustomTestSrcResolver extends BaseSrcResolver {
  const _CustomTestSrcResolver();

  @override
  bool exists(Uri uri) => uri.toString().startsWith('custom');

  @override
  Future<String?> load(Uri uri) async {
    if (exists(uri)) {
      return '<data>custom</data>';
    }
    return null;
  }
}
