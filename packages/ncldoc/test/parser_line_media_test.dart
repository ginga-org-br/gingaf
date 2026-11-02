import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NclParser and NclDocument line and media association', () {
    const videoNcl = '''<ncl>
  <body>
    <port id="init" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4">
      <area id="a1" begin="2s" end="4s"/>
    </media>
    <media id="green_bg">
      <property name="background" value="green"/>
      <property name="bounds" value="0%,80%,20%,20%"/>
    </media>
    <media id="red_bg">
      <property name="background" value="red"/>
      <property name="bounds" value="80%,80%,20%,20%"/>
      <property name="explicitDur" value="2s"/>
    </media>
    <link id="l1">
      <bind role="onBegin" component="video" interface="a1"/>
      <bind role="start" component="green_bg"/>
    </link>
    <link id="l2">
      <bind role="onEnd" component="video" interface="a1"/>
      <bind role="stop" component="green_bg"/>
      <bind role="start" component="red_bg"/>
    </link>
  </body>
</ncl>''';

    test('saves line numbers for elements when parsing NCL', () {
      final doc = NclDocument.fromContent(videoNcl);

      final port = doc.body.children.whereType<Port>().first;
      expect(port.line, equals(3));

      final videoMedia = doc.getNodeById('video') as Media;
      expect(videoMedia.line, equals(4));
      expect(videoMedia.endLine, equals(6));

      final areaA1 = videoMedia.children.whereType<Area>().first;
      expect(areaA1.line, equals(5));

      final greenMedia = doc.getNodeById('green_bg') as Media;
      expect(greenMedia.line, equals(7));
      expect(greenMedia.endLine, equals(10));

      final redMedia = doc.getNodeById('red_bg') as Media;
      expect(redMedia.line, equals(11));
      expect(redMedia.endLine, equals(15));

      final link1 = doc.body.children.whereType<Link>().first;
      expect(link1.line, equals(16));
      expect(link1.endLine, equals(19));

      final bindStartGreen = link1.binds.last;
      expect(bindStartGreen.line, equals(18));
    });

    test('finds innermost element by line number', () {
      final doc = NclDocument.fromContent(videoNcl);

      expect(doc.findElementByLine(3), isA<Port>());
      expect(doc.findElementByLine(4), isA<Media>());
      expect(doc.findElementByLine(4)?.id, equals('video'));
      expect(doc.findElementByLine(5), isA<Area>());
      expect(doc.findElementByLine(5)?.id, equals('a1'));
      expect(doc.findElementByLine(7)?.id, equals('green_bg'));
      expect(doc.findElementByLine(8), isA<Property>());
      expect(doc.findElementByLine(11)?.id, equals('red_bg'));
      expect(doc.findElementByLine(18), isA<Bind>());
      expect(doc.findElementByLine(22), isA<Bind>());
      expect(doc.findElementByLine(23), isA<Bind>());
    });

    test('finds related media given line number', () {
      final doc = NclDocument.fromContent(videoNcl);

      expect(doc.findRelatedMedia(3)?.id, equals('video'));
      expect(doc.findRelatedMedia(4)?.id, equals('video'));
      expect(doc.findRelatedMedia(5)?.id, equals('video'));
      expect(doc.findRelatedMedia(7)?.id, equals('green_bg'));
      expect(doc.findRelatedMedia(8)?.id, equals('green_bg'));
      expect(doc.findRelatedMedia(9)?.id, equals('green_bg'));
      expect(doc.findRelatedMedia(11)?.id, equals('red_bg'));
      expect(doc.findRelatedMedia(14)?.id, equals('red_bg'));

      expect(doc.findRelatedMedia(18)?.id, equals('green_bg'));
      expect(doc.findRelatedMedia(22)?.id, equals('green_bg'));
      expect(doc.findRelatedMedia(23)?.id, equals('red_bg'));

      final link1Media = doc.findRelatedMediaList(16).map((m) => m.id).toList();
      expect(link1Media, isEmpty);

      expect(doc.findRelatedMediaIds(4), contains('video'));
      expect(doc.findRelatedMediaIds(18), contains('green_bg'));
      expect(doc.findRelatedMediaIds(23), contains('red_bg'));
    });

    test('pauses execution when breakpoint media starts', () {
      final doc = NclDocument.fromContent(videoNcl);

      final hits = <({String mediaId, NclActionType action, int line})>[];
      doc.onBreakpointHit = (media, action, line) {
        hits.add((mediaId: media.id!, action: action, line: line));
      };

      doc.setBreakpoints([4]);
      expect(doc.breakpointMediaIds, contains('video'));

      doc.start();

      expect(doc.isPaused, isTrue);
      expect(hits.length, equals(1));
      expect(hits.first.mediaId, equals('video'));
      expect(hits.first.action, equals(NclActionType.start));

      doc.resume();
      expect(doc.isPaused, isFalse);
    });

    test('pauses execution when subsequent breakpoint media starts on link trigger', () {
      final doc = NclDocument.fromContent(videoNcl);

      final hits = <({String mediaId, NclActionType action, int line})>[];
      doc.onBreakpointHit = (media, action, line) {
        hits.add((mediaId: media.id!, action: action, line: line));
      };

      doc.setBreakpoints([7]);
      expect(doc.breakpointMediaIds, contains('green_bg'));

      doc.start();
      expect(doc.isPaused, isFalse);
      expect(hits, isEmpty);

      doc.tick(2500);

      expect(doc.isPaused, isTrue);
      expect(hits.any((h) => h.mediaId == 'green_bg' && h.action == NclActionType.start), isTrue);
    });

    test('pauses execution when breakpoint media stops on link trigger', () {
      final doc = NclDocument.fromContent(videoNcl);

      final hits = <({String mediaId, NclActionType action, int line})>[];
      doc.onBreakpointHit = (media, action, line) {
        hits.add((mediaId: media.id!, action: action, line: line));
      };

      doc.setBreakpoints([22]);
      expect(doc.breakpointMediaIds, contains('green_bg'));

      doc.start();
      expect(doc.isPaused, isFalse);

      doc.tick(2500);
      expect(doc.isPaused, isTrue);
      expect(hits.any((h) => h.mediaId == 'green_bg' && h.action == NclActionType.start), isTrue);
      expect(hits.first.line, equals(22));
      expect(hits.where((h) => h.action == NclActionType.stop), isEmpty);

      doc.resume();
      expect(doc.isPaused, isFalse);

      doc.tick(2000);
      expect(doc.isPaused, isTrue);
      expect(hits.any((h) => h.mediaId == 'green_bg' && h.action == NclActionType.stop), isTrue);
    });

    test('pauses on green media start then red media start when continuing without pausing on media stop', () {
      final doc = NclDocument.fromContent(videoNcl);

      final hits = <({String mediaId, NclActionType action, int line})>[];
      doc.onBreakpointHit = (media, action, line) {
        hits.add((mediaId: media.id!, action: action, line: line));
      };

      doc.setBreakpoints([7, 11]);

      doc.start();
      expect(doc.isPaused, isFalse);

      doc.tick(2500);
      expect(doc.isPaused, isTrue);
      expect(hits.length, equals(1));
      expect(hits.first.mediaId, equals('green_bg'));
      expect(hits.first.action, equals(NclActionType.start));
      expect(hits.first.line, equals(7));

      doc.resume();
      expect(doc.isPaused, isFalse);

      doc.tick(2000);
      expect(doc.isPaused, isTrue);
      expect(hits.length, equals(2));
      expect(hits.last.mediaId, equals('red_bg'));
      expect(hits.last.action, equals(NclActionType.start));
      expect(hits.last.line, equals(11));
    });

    test('ignores breakpoint set on link element without pausing', () {
      final doc = NclDocument.fromContent(videoNcl);
      final hits = <({String mediaId, NclActionType action, int line})>[];
      doc.onBreakpointHit = (media, action, line) {
        hits.add((mediaId: media.id!, action: action, line: line));
      };

      doc.setBreakpoints([16, 20]);
      doc.start();
      expect(doc.isPaused, isFalse);
      expect(hits, isEmpty);
    });
  });
}
