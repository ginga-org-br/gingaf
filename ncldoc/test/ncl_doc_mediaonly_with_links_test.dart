import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCLDocument Media Only With Links Tests', () {
    test('link onEnd starts another media', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="v1.mp4" type="video/mp4"/>
    <media id="m2" src="v2.mp4" type="video/mp4"/>
    <link id="l1">
      <bind role="onEnd" component="m1"/>
      <bind role="start" component="m2"/>
    </link>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromXML(xml);
      doc.start();
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.virtualClock, 0);
      expect(doc.getNodeById('m1')?.getMainState(), State.OCCURRING);
      final changed1 = doc.tick(1);
      expect(changed1, isEmpty);
      expect(doc.virtualClock, 1);
      doc.stop();
      expect(doc.getNodeById('m1')?.getMainState(), State.SLEEPING);
      expect(doc.getBodyState(), State.SLEEPING);
    });

    test('link onBegin starts another media', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="v1.mp4" type="video/mp4"/>
    <media id="m2" src="v2.mp4" type="video/mp4"/>
    <link id="l1">
      <bind role="onBegin" component="m1"/>
      <bind role="start" component="m2"/>
    </link>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromXML(xml);
      doc.start();
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.virtualClock, 0);
      expect(doc.getNodeById('m1')?.getMainState(), State.OCCURRING);
      expect(doc.getNodeById('m2')?.getMainState(), State.OCCURRING);
      final changed2 = doc.tick(1);
      expect(changed2, isEmpty);
      expect(doc.virtualClock, 1);
      doc.stop();
      expect(doc.getNodeById('m1')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('m2')?.getMainState(), State.SLEEPING);
      expect(doc.getBodyState(), State.SLEEPING);
    });
  });
}
