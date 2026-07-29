import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCLDocument Constructors Tests', () {
    test('NCLDocument.fromContent parses NCL XML string correctly', () {
      final xml = '<ncl><body id="body"><media id="m1" src="m1.mp4"/></body></ncl>';
      final doc = NCLDocument.fromContent(xml);
      expect(doc.getNodeById('m1'), isNotNull);
    });

    test('NCLDocument.fromURI resolves uri using uriResolver and userDataJsonURI', () {
      final uri = Uri.parse('http://example.com/main.ncl');
      final userUri = Uri.parse('http://example.com/user.json');

      NCLDocument.uriResolver = (resUri) {
        if (resUri == uri) {
          return '<ncl><body id="body"><media id="m1" src="m1.mp4"/></body></ncl>';
        }
        if (resUri == userUri) {
          return '[{"id":"u1","name":"User 1","properties":{"age":30}}]';
        }
        return null;
      };

      final doc = NCLDocument.fromURI(uri, userDataJsonURI: userUri);
      expect(doc.getNodeById('m1'), isNotNull);
      expect(doc.users.getUser('u1')?.name, equals('User 1'));

      NCLDocument.uriResolver = null;
    });
  });
}
