import 'dart:io';

import 'package:ncldoc/elements.dart';
import 'package:ncldoc/parser.dart';
import 'package:test/test.dart';

void main() {
  group('NCLParser Tests', () {
    late NCLParser parser;
    final dummyFiles = ['video.mp4', 'video1.mp4', 'video2.mp4', 'image.png', 'a.mp4', 'main.lua', 'index.html'];

    setUp(() {
      parser = NCLParser();
      for (final name in dummyFiles) {
        File(name).writeAsStringSync('dummy content');
      }
    });

    tearDown(() {
      for (final name in dummyFiles) {
        final f = File(name);
        if (f.existsSync()) f.deleteSync();
      }
    });

    test('parseString parses all NCL node types successfully', () {
      const xmlString = '''
      <ncl id="ncl_doc">
        <body>
          <port id="p1" component="c1" />
          <context id="c1">
            <media id="m1" src="video.mp4">
              <area id="area1" begin="10s" />
              <property id="prop2" name="fontColor" value="blue" />
            </media>
          </context>
          <link id="l1">
            <bind role="onBegin" component="m1" />
          </link>
        </body>
      </ncl>
      ''';

      final (head, body) = parser.parseString(xmlString);
      expect(head, isEmpty);

      final port = body.children.firstWhere((e) => e.id == 'p1') as Port;
      expect(port, isA<Port>());
      expect(port.component, 'c1');

      final context = body.children.firstWhere((e) => e.id == 'c1') as Context;
      expect(context, isA<Context>());

      final media = context.children.firstWhere((e) => e.id == 'm1') as Media;
      expect(media, isA<Media>());

      final area = media.children.firstWhere((e) => e.id == 'area1') as Area;
      expect(area, isA<Area>());
      expect(area.begin, '10s');

      final prop2 =
          media.children.firstWhere((e) => e.id == 'prop2') as Property;
      expect(prop2, isA<Property>());
      expect(prop2.name, 'fontColor');
      expect(prop2.value, 'blue');

      final link = body.children.firstWhere((e) => e.id == 'l1') as Link;
      expect(link, isA<Link>());

      final bind = link.children.whereType<Bind>().first;
      expect(bind, isA<Bind>());
      expect(bind.role, 'onBegin');
      expect(bind.component, 'm1');
    });

    test('validate catches missing required attributes', () {
      final xmlString = '''
      <?xml version="1.0" encoding="UTF-8"?>
      <ncl>
        <body>
          <media src="video.mp4" />
        </body>
      </ncl>
      ''';

      final errors = parser.validate(xmlString);
      expect(errors.isNotEmpty, true);
      expect(
        errors.any(
          (e) =>
              e.contains('Missing required attribute "id" for element <media>'),
        ),
        true,
      );
    });

    test('validate catches unknown attributes', () {
      final xmlString = '''
      <?xml version="1.0" encoding="UTF-8"?>
      <ncl>
        <body>
          <media id="video1" src="video.mp4" unknown="123" />
        </body>
      </ncl>
      ''';

      final errors = parser.validate(xmlString);
      expect(errors.isNotEmpty, true);
      expect(
        errors.any(
          (e) => e.contains('Unknown attribute "unknown" for element <media>'),
        ),
        true,
      );
    });

    test('Should parse multiple entry ports and media correctly', () {
      const ncl = '''
<ncl>
  <body>
    <port id="init1" component="lua_media"/>
    <port id="init2" component="html_media"/>
    <media id="lua_media" src="main.lua"/>
    <media id="html_media" src="index.html" type="text/html"/>
  </body>
</ncl>
''';
      final (head, body) = parser.parseString(ncl);
      final ports = body.children.whereType<Port>().toList();
      final mediaList = body.children.whereType<Media>().toList();

      expect(ports.length, equals(2));
      expect(mediaList.length, equals(2));

      expect(ports[0].id, equals('init1'));
      expect(ports[0].component, equals('lua_media'));

      expect(mediaList[0].id, equals('lua_media'));
      expect(mediaList[0].rawAttributes['src'], equals('main.lua'));
      expect(mediaList[1].rawAttributes['src'], equals('index.html'));
    });

    test('instantiates Media and Settings correctly', () {
      const xml = '''
<ncl>
  <body>
    <media id="content" src="video.mp4" />
    <media id="time" />
    <media id="settings" type="application/x-ginga-settings" />
  </body>
</ncl>
''';
      final (_, body) = parser.parseString(xml);
      final mediaList = body.children.whereType<Media>().toList();

      expect(mediaList.length, 3);

      final contentNode = mediaList.firstWhere((e) => e.id == 'content');
      expect(contentNode, isA<Media>());
      expect(contentNode.uri, isNotEmpty);
      expect(contentNode.mimeType, 'video/mp4');

      final timeNode = mediaList.firstWhere((e) => e.id == 'time');
      expect(timeNode, isA<Media>());
      expect(timeNode.uri, isEmpty);
      expect(timeNode.mimeType, 'application/x-ginga-time');

      final settingsNode = mediaList.firstWhere((e) => e.id == 'settings');
      expect(settingsNode, isA<Settings>());
    });

    test('validate and parse sbtvd:// media with id="mainAV" successfully', () {
      const xml = '''
<ncl>
  <body>
    <media id="mainAV" src="sbtvd://" />
  </body>
</ncl>
''';
      final errors = parser.validate(xml);
      expect(errors, isEmpty);

      final (_, body) = parser.parseString(xml);
      final media = body.children.whereType<Media>().first;
      expect(media.id, 'mainAV');
      expect(media.uri, 'sbtvd://');
    });

    test('re-parses NCL XML', () {
      const initialXml = '''
<ncl id="playground">
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="video1.mp4"/>
  </body>
</ncl>
''';
      final (_, initialBody) = parser.parseString(initialXml);
      expect(
        initialBody.children.whereType<Media>().first.uri,
        equals('video1.mp4'),
      );

      const editedXml = '''
<ncl id="playground">
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="video2.mp4"/>
    <media id="m2" src="image.png"/>
  </body>
</ncl>
''';
      final (_, editedBody) = parser.parseString(editedXml);
      final mediaNodes = editedBody.children.whereType<Media>().toList();
      expect(mediaNodes.length, equals(2));
      expect(mediaNodes[0].uri, equals('video2.mp4'));
      expect(mediaNodes[1].uri, equals('image.png'));
    });
  });
}
