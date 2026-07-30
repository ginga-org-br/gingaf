import 'dart:io';

import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCLDocument from nodes Tests', () {
    test('tick increments virtual clock', () {
      final doc = NCLDocument.fromContent('<ncl><body id="body"></body></ncl>');
      expect(doc.virtualClock, 0);
      doc.start();
      final changed1 = doc.tick(10);
      expect(changed1, isEmpty);
      expect(doc.virtualClock, 10);
      final changed2 = doc.tick(1);
      expect(changed2, isEmpty);
      expect(doc.virtualClock, 11);
    });

    test('tick does not go backwards', () {
      final doc = NCLDocument.fromContent('<ncl><body id="body"></body></ncl>');
      doc.start();
      final changed3 = doc.tick(100);
      expect(changed3, isEmpty);
      expect(doc.virtualClock, 100);
      final changed4 = doc.tick(0);
      expect(changed4, isEmpty);
      expect(doc.virtualClock, 100);
    });

    test('automatic start via Port', () {
      final doc = NCLDocument.fromContent(
        '<ncl><body id="body"><media id="m1"/><port id="p1" component="m1"/></body></ncl>',
      );
      doc.start();
      expect(doc.getBodyState(), NCLState.OCCURRING);
      expect(doc.getNodeById('m1')?.getMainState(), NCLState.OCCURRING);
      doc.stop();
      expect(doc.getNodeById('m1')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getBodyState(), NCLState.SLEEPING);
    });

    test('causal link between two media', () {
      final doc = NCLDocument.fromContent('''
<ncl>
<body id="body">
  <media id="m1"/>
  <media id="m2"/>
  <port id="p1" component="m1"/>
  <link id="l1">
    <bind role="onBegin" component="m1"/>
    <bind role="start" component="m2"/>
  </link>
</body>
</ncl>
''');
      doc.start();
      expect(doc.getBodyState(), NCLState.OCCURRING);
      expect(doc.getNodeById('m1')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('m2')?.getMainState(), NCLState.OCCURRING);
      doc.stop();
      expect(doc.getNodeById('m1')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('m2')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getBodyState(), NCLState.SLEEPING);
    });

    test('default Settings is created if none is provided', () {
      final doc = NCLDocument.fromContent('<ncl><body id="body"></body></ncl>');
      doc.start();
      final settings = doc.getSettings();
      expect(settings, isNotNull);
      expect(settings.id, '__settings__');
    });

    test('NCLDocument Composition', () {
      final doc = NCLDocument.fromContent(
        '<ncl><body id="body"><media id="m1" src="v.mp4"/><port id="p1" component="m1"/></body></ncl>',
      );
      doc.start();

      expect(doc.body.getMedias().length, 2);
      expect(doc.body.getPorts().length, 1);
      expect(doc.body.getMedias().first.id, 'm1');
      expect(doc.body.getPorts().first.id, 'p1');
    });

    test('getSettings is returned correctly when provided', () {
      final doc = NCLDocument.fromContent(
        '<ncl><body id="body"><settings id="s1"/></body></ncl>',
      );
      doc.start();
      expect(doc.getSettings().id, 's1');
    });

    test('NCLDocument.fromContent parses NCL XML string correctly', () {
      final xml =
          '<ncl><body id="body"><media id="m1" src="m1.mp4"/></body></ncl>';
      final doc = NCLDocument.fromContent(xml);
      expect(doc.getNodeById('m1'), isNotNull);
    });

    test('docSrc default in fromContent', () {
      final doc = NCLDocument.fromContent('<ncl><body id="body"></body></ncl>');
      expect(doc.docSrc, 'tmp.ncl');
    });

    test('resolving relative media path against file docUri', () {
      final dummy = File('video.mp4')..writeAsStringSync('');
      try {
        final doc = NCLDocument.fromContent(
          '<ncl><body id="body"><media id="m1" src="video.mp4" /></body></ncl>',
          docSrc: 'file:///C:/Users/test/video.ncl',
        );
        final media = doc.getNodeById('m1') as Media;
        expect(media.uri, 'file:///C:/Users/test/video.mp4');
      } finally {
        if (dummy.existsSync()) dummy.deleteSync();
      }
    });
  });
}
