import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCLDocument Context With Links Tests', () {
    test('2x ctx link onEnd', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="ctx1"/>
    <context id="ctx1">
      <media id="m1" src="v1.mp4" type="video/mp4"/>
    </context>
    <context id="ctx2">
      <media id="m2" src="v2.mp4" type="video/mp4"/>
    </context>
    <link id="l1">
      <bind role="onEnd" component="ctx1"/>
      <bind role="start" component="ctx2"/>
    </link>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), NCLState.OCCURRING);
      expect(doc.virtualClock, 0);
      expect(doc.getNodeById('ctx1')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('ctx2')?.getMainState(), NCLState.SLEEPING);
      final changed = doc.tick(1);
      expect(changed, isEmpty);
      expect(doc.virtualClock, 1);
      doc.stop();
      expect(doc.getNodeById('ctx1')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('ctx2')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getBodyState(), NCLState.SLEEPING);
    });

    test('2x ctx internal links', () {
      const xml = '''
<ncl>
  <body>
    <port id="p1" component="c1"/>
    <port id="p2" component="c2"/>
    <context id="c1">
      <port id="p_c1" component="m1"/>
      <media id="m1" src="m1.mp4"/>
      <media id="m2" src="m2.mp4"/>
      <link id="l1">
        <bind role="onBegin" component="m1"/>
        <bind role="start" component="m2"/>
      </link>
    </context>
    <context id="c2">
      <port id="p_c2" component="m3"/>
      <media id="m3" src="m3.mp4"/>
      <media id="m4" src="m4.mp4"/>
      <link id="l2">
        <bind role="onBegin" component="m3"/>
        <bind role="start" component="m4"/>
      </link>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getNodeById('c1')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('c2')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('m1')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('m2')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('m3')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('m4')?.getMainState(), NCLState.OCCURRING);
    });

    test('2x ctx link onEnd no ports', () {
      const xml = '''
<ncl>
  <body>
    <context id="ctx1">
      <media id="m1" src="v1.mp4" type="video/mp4"/>
    </context>
    <context id="ctx2">
      <media id="m2" src="v2.mp4" type="video/mp4"/>
    </context>
    <link id="l1">
      <bind role="onEnd" component="ctx1"/>
      <bind role="start" component="ctx2"/>
    </link>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), NCLState.OCCURRING);
      expect(doc.getNodeById('ctx1')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('ctx2')?.getMainState(), NCLState.SLEEPING);
    });

    test('2x ctx internal links no ports', () {
      const xml = '''
<ncl>
  <body>
    <context id="c1">
      <media id="m1" src="m1.mp4"/>
      <media id="m2" src="m2.mp4"/>
      <link id="l1">
        <bind role="onBegin" component="m1"/>
        <bind role="start" component="m2"/>
      </link>
    </context>
    <context id="c2">
      <media id="m3" src="m3.mp4"/>
      <media id="m4" src="m4.mp4"/>
      <link id="l2">
        <bind role="onBegin" component="m3"/>
        <bind role="start" component="m4"/>
      </link>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), NCLState.OCCURRING);
      expect(doc.getNodeById('c1')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('c2')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('m1')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('m2')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('m3')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('m4')?.getMainState(), NCLState.SLEEPING);
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
          <media id="m1" src="v1.mp4"/>
          <media id="m2" src="v2.mp4"/>
          <link id="l1">
            <bind role="onBegin" component="m1"/>
            <bind role="start" component="m2"/>
          </link>
        </context>
      </context>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), NCLState.OCCURRING);
      expect(doc.getNodeById('ctx1')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('ctx2')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('ctx3')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('m1')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('m2')?.getMainState(), NCLState.OCCURRING);
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
            <media id="m1" src="v1.mp4"/>
            <media id="m2" src="v2.mp4"/>
            <link id="l1">
              <bind role="onBegin" component="m1"/>
              <bind role="start" component="m2"/>
            </link>
          </context>
        </context>
      </context>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), NCLState.OCCURRING);
      expect(doc.getNodeById('ctx1')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('ctx2')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('ctx3')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('ctx4')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('m1')?.getMainState(), NCLState.OCCURRING);
      expect(doc.getNodeById('m2')?.getMainState(), NCLState.OCCURRING);
    });

    test('3x ctx nested no ports', () {
      const xml = '''
<ncl>
  <body>
    <context id="ctx1">
      <context id="ctx2">
        <context id="ctx3">
          <media id="m1" src="v1.mp4"/>
          <media id="m2" src="v2.mp4"/>
          <link id="l1">
            <bind role="onBegin" component="m1"/>
            <bind role="start" component="m2"/>
          </link>
        </context>
      </context>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), NCLState.OCCURRING);
      expect(doc.getNodeById('ctx1')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('ctx2')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('ctx3')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('m1')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('m2')?.getMainState(), NCLState.SLEEPING);
    });

    test('4x ctx nested no ports', () {
      const xml = '''
<ncl>
  <body>
    <context id="ctx1">
      <context id="ctx2">
        <context id="ctx3">
          <context id="ctx4">
            <media id="m1" src="v1.mp4"/>
            <media id="m2" src="v2.mp4"/>
            <link id="l1">
              <bind role="onBegin" component="m1"/>
              <bind role="start" component="m2"/>
            </link>
          </context>
        </context>
      </context>
    </context>
  </body>
</ncl>
''';
      final doc = NCLDocument.fromContent(xml);
      doc.start();
      expect(doc.getBodyState(), NCLState.OCCURRING);
      expect(doc.getNodeById('ctx1')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('ctx2')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('ctx3')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('ctx4')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('m1')?.getMainState(), NCLState.SLEEPING);
      expect(doc.getNodeById('m2')?.getMainState(), NCLState.SLEEPING);
    });
  });
}
