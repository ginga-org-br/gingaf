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

      const httpSrc = 'http://example.com/file.ncl';
      expect(loader.exists(httpSrc), isFalse);
      expect(() => loader.load(httpSrc), throwsA(isA<FileSystemException>()));

      final tempDir = Directory.systemTemp.createTempSync('ncldoc_test_');
      final tempFile = File('${tempDir.path}/sample.ncl');
      tempFile.writeAsStringSync('<ncl>test</ncl>');

      final fileSrc = tempFile.absolute.uri.toString();
      expect(loader.exists(fileSrc), isTrue);

      final content = await loader.load(fileSrc);
      expect(content, equals('<ncl>test</ncl>'));

      tempFile.deleteSync();
      expect(loader.exists(fileSrc), isFalse);
      expect(() => loader.load(fileSrc), throwsA(isA<FileSystemException>()));

      tempDir.deleteSync();
    });

    test('Custom ContentLoader subclass can override exists and load', () async {
      final customLoader = _CustomTestContentLoader();
      const customSrc = 'custom://app/data.xml';

      expect(customLoader.exists(customSrc), isTrue);
      expect(await customLoader.load(customSrc), equals('<data>custom</data>'));

      const otherSrc = 'http://example.com/other';
      expect(customLoader.exists(otherSrc), isFalse);
      expect(await customLoader.load(otherSrc), isNull);
    });

    test('NCLParser with FileContentLoader throws FileSystemException when media src does not exist', () {
      final parser = NCLParser(
        docUri: Uri.parse('file:///non_existent_dir/doc.ncl'),
        contentLoader: const FileContentLoader(),
      );
      const xml = '<ncl><body><media id="m1" src="non_existent_file.mp4"/></body></ncl>';
      expect(() => parser.parseString(xml), throwsA(isA<FileSystemException>()));
    });
  });
}

class _CustomTestContentLoader extends ContentLoader {
  const _CustomTestContentLoader();

  @override
  bool exists(String src, [String? baseDirSrc]) => src.startsWith('custom');

  @override
  Future<String?> load(String src, [String? baseDirSrc]) async {
    if (exists(src, baseDirSrc)) {
      return '<data>custom</data>';
    }
    return null;
  }
}
