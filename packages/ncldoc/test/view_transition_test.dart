import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NclScheduler View Transition & Time Advancement Tests', () {
    test(
        'triggerViewTransition onBeginView starts target and onEndView stops target',
        () {
      const xml = '''
<ncl>
  <body>
    <port id="pInit" component="pano360"/>
    <media id="pano360" type="video/360">
      <area id="hotspot1" polar="0" azimuthal="0"/>
    </media>
    <media id="infoPanel" type="text/plain"/>
    <link id="lIn">
      <bind role="onBeginView" component="pano360" interface="hotspot1"/>
      <bind role="start" component="infoPanel"/>
    </link>
    <link id="lOut">
      <bind role="onEndView" component="pano360" interface="hotspot1"/>
      <bind role="stop" component="infoPanel"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      final infoPanel = doc.getNodeById('infoPanel') as Media;
      expect(infoPanel.getMainState(), equals(NclStateType.sleeping));

      doc.handleViewTransition('pano360', true, 'hotspot1');
      expect(infoPanel.getMainState(), equals(NclStateType.occurring));

      doc.handleViewTransition('pano360', false, 'hotspot1');
      expect(infoPanel.getMainState(), equals(NclStateType.sleeping));
    });

    test('view transition link with delay executes only after time advances',
        () {
      const xml = '''
<ncl>
  <body>
    <port id="pInit" component="pano360"/>
    <media id="pano360" type="video/360">
      <area id="hotspotDelayed" polar="0" azimuthal="45"/>
    </media>
    <media id="delayedAlert" type="text/plain"/>
    <link id="lDelayed">
      <bind role="onBeginView" component="pano360" interface="hotspotDelayed"/>
      <bind role="start" component="delayedAlert">
        <bindParam name="delay" value="1500ms"/>
      </bind>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      final delayedAlert = doc.getNodeById('delayedAlert') as Media;
      expect(delayedAlert.getMainState(), equals(NclStateType.sleeping));

      doc.handleViewTransition('pano360', true, 'hotspotDelayed');
      expect(delayedAlert.getMainState(), equals(NclStateType.sleeping));

      doc.tick(500);
      expect(delayedAlert.getMainState(), equals(NclStateType.sleeping));

      doc.tick(500);
      expect(delayedAlert.getMainState(), equals(NclStateType.sleeping));

      doc.tick(600);
      expect(delayedAlert.getMainState(), equals(NclStateType.occurring));
    });

    test('direct area component binding in onBeginView and onSelection', () {
      const xml = '''
<ncl>
  <body>
    <port id="pInit" component="pano360"/>
    <media id="pano360" type="video/360">
      <area id="spotDirect"/>
    </media>
    <media id="viewTarget" type="text/plain"/>
    <media id="selectTarget" type="text/plain"/>
    <link id="lView">
      <bind role="onBeginView" component="spotDirect"/>
      <bind role="start" component="viewTarget"/>
    </link>
    <link id="lSelect">
      <bind role="onSelection" component="spotDirect"/>
      <bind role="start" component="selectTarget"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      final viewTarget = doc.getNodeById('viewTarget') as Media;
      final selectTarget = doc.getNodeById('selectTarget') as Media;

      expect(viewTarget.getMainState(), equals(NclStateType.sleeping));
      expect(selectTarget.getMainState(), equals(NclStateType.sleeping));

      doc.handleViewTransition('spotDirect', true);
      expect(viewTarget.getMainState(), equals(NclStateType.occurring));
      expect(selectTarget.getMainState(), equals(NclStateType.sleeping));

      doc.handleSelection('spotDirect');
      expect(selectTarget.getMainState(), equals(NclStateType.occurring));
    });

    test(
        'time advancement across media explicit duration stops media and dependent links',
        () {
      const xml = '''
<ncl>
  <head>
    <descriptorBase>
      <descriptor id="d3s" explicitDur="3s"/>
    </descriptorBase>
  </head>
  <body>
    <port id="pInit" component="pano360"/>
    <media id="pano360" type="video/360" descriptor="d3s"/>
    <media id="doneNotice" type="text/plain"/>
    <link id="lDone">
      <bind role="onEnd" component="pano360"/>
      <bind role="start" component="doneNotice"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      final pano = doc.getNodeById('pano360') as Media;
      final doneNotice = doc.getNodeById('doneNotice') as Media;

      expect(pano.getMainState(), equals(NclStateType.occurring));
      expect(doneNotice.getMainState(), equals(NclStateType.sleeping));

      doc.tick(1500);
      expect(pano.getMainState(), equals(NclStateType.occurring));
      expect(doneNotice.getMainState(), equals(NclStateType.sleeping));

      doc.tick(1600);
      expect(pano.getMainState(), equals(NclStateType.sleeping));
      expect(doneNotice.getMainState(), equals(NclStateType.occurring));
    });
  });
}
