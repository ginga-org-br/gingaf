import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCL Editing Commands Body Tests', () {

test('routes and executes addNode and removeNode', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      expect(doc.getNodeById('m1'), isNull);

      doc.doNclEditingCommand('addNode("c1", "<media id=\\"m1\\" src=\\"video.mp4\\" />")');
      expect(doc.getNodeById('m1'), isNotNull);

      doc.doNclEditingCommand('removeNode("c1", "m1")');
      expect(doc.getNodeById('m1'), isNull);
    });

test('routes and executes setPropertyValue', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <body>
          <media id="m1" src="video.mp4">
            <property name="p1" value="old" />
          </media>
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      final media = doc.getNodeById('m1')!;
      expect(media.children.whereType<Property>().first.value, equals('old'));

      doc.doNclEditingCommand('setPropertyValue("m1", "p1", "new")');
      expect(media.children.whereType<Property>().first.value, equals('new'));
    });

test('routes and executes addInterface and removeInterface', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <body>
          <media id="m1" src="video.mp4" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      final media = doc.getNodeById('m1')!;
      expect(media.children.isEmpty, isTrue);

      doc.doNclEditingCommand('addInterface("m1", "<area id=\\"area1\\" begin=\\"1s\\" />")');
      expect(media.children.isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeInterface("m1", "area1")');
      expect(media.children.isEmpty, isTrue);
    });

test('routes and executes addLink and removeLink', () {
      final xmlString = '''
      <ncl id="ncl_doc">
        <body>
          <context id="c1" />
        </body>
      </ncl>
      ''';
      final doc = NCLDocument.fromXML(xmlString);
      final context = doc.getNodeById('c1')!;
      expect(context.children.isEmpty, isTrue);

      doc.doNclEditingCommand('addLink("c1", "<link id=\\"link1\\" xconnector=\\"onBeginStart\\" />")');
      expect(context.children.isNotEmpty, isTrue);

      doc.doNclEditingCommand('removeLink("c1", "link1")');
      expect(context.children.isEmpty, isTrue);
    });
  });
}
