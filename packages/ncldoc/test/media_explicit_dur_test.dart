import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('explicitDur Property Tests', () {
    test('explicitDur stops media automatically after specified duration', () {
      const xmlString = '''
      <ncl>
        <body>
          <port id="init" component="m1"/>
          <media id="m1" src="video.mp4">
            <property name="explicitDur" value="2s"/>
          </media>
        </body>
      </ncl>
      ''';

      final doc = NCLDocument.fromContent(xmlString);
      doc.start();

      expect(doc.getBodyState(), NCLState.OCCURRING);
      final mediaNode = doc.getNodeById('m1')!;
      expect(mediaNode.getMainState(), NCLState.OCCURRING);

      doc.tick(1000);
      expect(mediaNode.getMainState(), NCLState.OCCURRING);

      doc.tick(1000);
      expect(
        mediaNode.getMainState(),
        NCLState.SLEEPING,
        reason: 'Media should stop after explicitDur of 2s',
      );
    });
  });
}
