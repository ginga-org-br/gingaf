import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCLDocument Context Tests', () {
    test('1x ctx', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="ctx1"/>
    <context id="ctx1">
      <media id="m1" src="v1.mp4" type="video/mp4"/>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.virtualClock, 0);
      expect(doc.getNodeById('ctx1')?.getMainState(), State.OCCURRING);
      final changed = doc.tick(1);
      expect(changed, isEmpty);
      expect(doc.virtualClock, 1);
      doc.stop();
      expect(doc.getNodeById('ctx1')?.getMainState(), State.SLEEPING);
      expect(doc.getBodyState(), State.SLEEPING);
    });

    test('2x ctx', () {
      const xmlString = '''
<ncl>
  <body>
    <port id="p1" component="c1"/>
    <port id="p2" component="c2"/>
    <context id="c1">
      <media id="m1" src="media.mp4" />
    </context>
    <context id="c2">
      <media id="m2" src="video.mp4" />
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xmlString);
      doc.start();
      
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.getNodeById('c1')?.getMainState(), State.OCCURRING);
      expect(doc.getNodeById('c2')?.getMainState(), State.OCCURRING);
      
      doc.stop();
      expect(doc.getNodeById('c1')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('c2')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('m1')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('m2')?.getMainState(), State.SLEEPING);
      expect(doc.getBodyState(), State.SLEEPING);
    });

    test('2x ctx nested', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="ctx1"/>
    <context id="ctx1">
      <port id="p2" component="ctx2"/>
      <context id="ctx2">
        <port id="p3" component="m1"/>
        <media id="m1" src="v1.mp4" type="video/mp4"/>
      </context>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.getNodeById('ctx1')?.getMainState(), State.OCCURRING);
      expect(doc.getNodeById('ctx2')?.getMainState(), State.OCCURRING);
      expect(doc.getNodeById('m1')?.getMainState(), State.OCCURRING);
    });

    test('3x ctx nested', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="ctx1"/>
    <context id="ctx1">
      <port id="p2" component="ctx2"/>
      <context id="ctx2">
        <port id="p3" component="ctx3"/>
        <context id="ctx3">
          <port id="p4" component="m1"/>
          <media id="m1" src="v1.mp4" type="video/mp4"/>
        </context>
      </context>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.getNodeById('ctx1')?.getMainState(), State.OCCURRING);
      expect(doc.getNodeById('ctx2')?.getMainState(), State.OCCURRING);
      expect(doc.getNodeById('ctx3')?.getMainState(), State.OCCURRING);
      expect(doc.getNodeById('m1')?.getMainState(), State.OCCURRING);
    });

    test('4x ctx nested', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="ctx1"/>
    <context id="ctx1">
      <port id="p2" component="ctx2"/>
      <context id="ctx2">
        <port id="p3" component="ctx3"/>
        <context id="ctx3">
          <port id="p4" component="ctx4"/>
          <context id="ctx4">
            <port id="p5" component="m1"/>
            <media id="m1" src="v1.mp4" type="video/mp4"/>
          </context>
        </context>
      </context>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.getNodeById('ctx1')?.getMainState(), State.OCCURRING);
      expect(doc.getNodeById('ctx2')?.getMainState(), State.OCCURRING);
      expect(doc.getNodeById('ctx3')?.getMainState(), State.OCCURRING);
      expect(doc.getNodeById('ctx4')?.getMainState(), State.OCCURRING);
      expect(doc.getNodeById('m1')?.getMainState(), State.OCCURRING);
    });

    test('1x ctx no ports', () {
      const xml = '''
<ncl>
  <body>
    <context id="ctx1">
      <media id="m1" src="v1.mp4" type="video/mp4"/>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.getNodeById('ctx1')?.getMainState(), State.SLEEPING);
    });

    test('2x ctx no ports', () {
      const xmlString = '''
<ncl>
  <body>
    <context id="c1">
      <media id="m1" src="media.mp4" />
    </context>
    <context id="c2">
      <media id="m2" src="video.mp4" />
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xmlString);
      doc.start();
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.getNodeById('c1')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('c2')?.getMainState(), State.SLEEPING);
    });

    test('2x ctx nested no ports', () {
      const xml = '''
<ncl>
  <body>
    <context id="ctx1">
      <context id="ctx2">
        <media id="m1" src="v1.mp4" type="video/mp4"/>
      </context>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.getNodeById('ctx1')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('ctx2')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('m1')?.getMainState(), State.SLEEPING);
    });

    test('3x ctx nested no ports', () {
      const xml = '''
<ncl>
  <body>
    <context id="ctx1">
      <context id="ctx2">
        <context id="ctx3">
          <media id="m1" src="v1.mp4" type="video/mp4"/>
        </context>
      </context>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.getNodeById('ctx1')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('ctx2')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('ctx3')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('m1')?.getMainState(), State.SLEEPING);
    });

    test('4x ctx nested no ports', () {
      const xml = '''
<ncl>
  <body>
    <context id="ctx1">
      <context id="ctx2">
        <context id="ctx3">
          <context id="ctx4">
            <media id="m1" src="v1.mp4" type="video/mp4"/>
          </context>
        </context>
      </context>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), State.OCCURRING);
      expect(doc.getNodeById('ctx1')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('ctx2')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('ctx3')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('ctx4')?.getMainState(), State.SLEEPING);
      expect(doc.getNodeById('m1')?.getMainState(), State.SLEEPING);
    });
  });
}
