import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCLDocument from nodes Tests', () {
    test('tick increments virtual clock', () {
      final doc = NCLDocument.fromBodyElements([]);
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
      final doc = NCLDocument.fromBodyElements([]);
      doc.start();
      final changed3 = doc.tick(100);
      expect(changed3, isEmpty);
      expect(doc.virtualClock, 100);
      final changed4 = doc.tick(0);
      expect(changed4, isEmpty);
      expect(doc.virtualClock, 100);
    });

    test('automatic start via Port', () {
      final media = Media(rawAttributes: const {'id': 'm1'});
      final port = Port(rawAttributes: const {'id': 'p1', 'component': 'm1'});
      final doc = NCLDocument.fromBodyElements([media, port]);
      doc.start();
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.getNodeById('m1')?.getMainState(), State.OCCURRING);
      doc.stop();
      expect(doc.getNodeById('m1')?.getMainState(), State.SLEEPING);
      expect(doc.getBodyState(), State.SLEEPING);
    });

    test('causal link between two media', () {
      final m1 = Media(rawAttributes: const {'id': 'm1'});
      final m2 = Media(rawAttributes: const {'id': 'm2'});
      final port = Port(rawAttributes: const {'id': 'p1', 'component': 'm1'});
      final link = Link(rawAttributes: const {'id': 'l1'});
      link.children.add(
        Bind(rawAttributes: const {'role': 'onBegin', 'component': 'm1'}),
      );
      link.children.add(
        Bind(rawAttributes: const {'role': 'start', 'component': 'm2'}),
      );
      final doc = NCLDocument.fromBodyElements([m1, m2, port, link]);
      doc.start();
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.getNodeById('m1')?.getMainState(), State.OCCURRING);
      expect(doc.getNodeById('m2')?.getMainState(), State.OCCURRING);
      doc.stop();
      expect(doc.getNodeById('m1')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('m2')?.getMainState(), State.SLEEPING);
      expect(doc.getBodyState(), State.SLEEPING);
    });

    test('default Settings is created if none is provided', () {
      final doc = NCLDocument.fromBodyElements([]);
      doc.start();
      final settings = doc.getSettings();
      expect(settings, isNotNull);
      expect(settings.id, '__settings__');
    });

    test('NCLDocument Composition', () {
      final media = Media(rawAttributes: const {'id': 'm1', 'src': 'v.mp4'});
      final port = Port(rawAttributes: const {'id': 'p1', 'component': 'm1'});
      final doc = NCLDocument.fromBodyElements([media, port]);
      doc.start();

      // Expect 3
      expect(doc.body.getMedias().length, 2);
      expect(doc.body.getPorts().length, 1);
      expect(doc.body.getMedias().first.id, 'm1');
      expect(doc.body.getPorts().first.id, 'p1');
    });

    test('getSettings is returned correctly when provided', () {
      final settings = Settings(rawAttributes: const {'id': 's1'});
      final doc = NCLDocument.fromBodyElements([settings]);
      doc.start();
      expect(doc.getSettings(), settings);
    });

    test('baseURI and fromXML / fromBodyElements', () {
      final doc1 = NCLDocument.fromXML(
        '<ncl><body></body></ncl>',
        baseURI: Uri.parse('some_uri/'),
      );
      expect(doc1.baseURI, Uri.parse('some_uri/'));

      final doc2 = NCLDocument.fromBodyElements([]);
      expect(doc2.baseURI, Uri.parse('.'));
    });

    test('resolving relative media path against file baseURI', () {
      final doc = NCLDocument.fromXML(
        '<ncl><body><media id="m1" src="video.mp4" /></body></ncl>',
        baseURI: Uri.parse('file:///C:/Users/test/video.ncl'),
      );
      final media = doc.getNodeById('m1') as Media;
      expect(media.uri, 'file:///C:/Users/test/video.mp4');
    });
  });
}
