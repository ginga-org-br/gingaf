import 'dart:io';

import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('src_resolver Uri resolution Tests', () {
    test('Standard Dart Uri resolves relative and absolute URIs correctly', () {
      final base = Uri.parse('http://example.com/app/main.ncl');
      final relativeUri = base.resolve('video.mp4');
      expect(relativeUri.toString(), equals('http://example.com/app/video.mp4'));

      final absoluteUri = base.resolve('http://other.org/asset.png');
      expect(absoluteUri.toString(), equals('http://other.org/asset.png'));
    });

    test('Top-level exists and load for file and data URIs', () async {
      final httpUri = resolveUri('http://example.com/file.ncl');
      expect(exists(httpUri), isTrue);

      final tempDir = Directory.systemTemp.createTempSync('ncldoc_test_');
      final tempFile = File('${tempDir.path}/sample.ncl');
      tempFile.writeAsStringSync('<ncl>test</ncl>');

      final fileUri = resolveUri(tempFile.absolute.uri.toString());
      expect(exists(fileUri), isTrue);

      final content = await loadContent(fileUri);
      expect(content, equals('<ncl>test</ncl>'));

      tempFile.deleteSync();
      expect(exists(fileUri), isFalse);
      expect(await loadContent(fileUri), isNull);

      tempDir.deleteSync();
    });

    test('NCLParser handles non-existent local file src gracefully', () {
      final parser = NCLParser(
        docUri: Uri.parse('file:///non_existent_dir/doc.ncl'),
      );
      const xml = '<ncl><body><media id="m1" src="non_existent_file.mp4"/></body></ncl>';
      expect(() => parser.parseString(xml), throwsA(anything));
    });
  });
}
