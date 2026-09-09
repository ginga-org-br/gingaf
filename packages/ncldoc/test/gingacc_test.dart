import 'dart:io';

import 'package:ncldoc/ncl_document.dart';
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

    test('loadContent for file, data URIs and virtualFiles', () async {
      final tempDir = Directory.systemTemp.createTempSync('ncldoc_test_');
      final tempFile = File('${tempDir.path}/sample.ncl');
      tempFile.writeAsStringSync('<ncl>test</ncl>');

      final gingacc = GingaCC(virtualFiles: {
        'app.ncl': '<ncl>virtual</ncl>',
      });
      final fileUri = gingacc.resolveUri(tempFile.absolute.uri.toString());
      final content = await gingacc.loadContent(fileUri);
      expect(content, equals('<ncl>test</ncl>'));

      tempFile.deleteSync();
      expect(await gingacc.loadContent(fileUri), isNull);
      tempDir.deleteSync();

      final dataContent =
          await gingacc.loadContent('data:text/plain;utf-8,<ncl>data</ncl>');
      expect(dataContent, equals('<ncl>data</ncl>'));

      expect(await gingacc.loadContent('app.ncl'), equals('<ncl>virtual</ncl>'));
    });

    test('NclParser parses media node without crashing on non-existent file', () {
      final parser = NclParser(
        docUri: Uri.parse('file:///non_existent_dir/doc.ncl'),
      );
      const xml =
          '<ncl><body><media id="m1" src="non_existent_file.mp4"/></body></ncl>';
      final (head, body) = parser.parseString(xml);
      expect(body.children.length, equals(1));
    });
  });
}
