import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('primeiro_joao_00syncProp', () {
    test('NCLDocument delay and property parsing', () {
      final doc = NCLDocument.fromXML(
        '''<ncl id="mySyncTest" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <connectorBase>
      <causalConnector id="onBeginStart_delay">
        <connectorParam name="delay"/>
        <simpleCondition role="onBegin"/>
        <simpleAction role="start" delay="\$delay" max="unbounded" qualifier="par"/>
      </causalConnector>
      <causalConnector id="onBeginStart">
        <simpleCondition role="onBegin"/>
        <simpleAction role="start" max="unbounded" qualifier="par"/>
      </causalConnector>
      <causalConnector id="onEndStop">
        <simpleCondition role="onEnd"/>
        <simpleAction role="stop" max="unbounded" qualifier="par"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="entry" component="animation"/>
    <media id="animation" src="video.mp4">
      <area id="seg1" begin="12s"/>
      <area id="seg2" begin="41s"/>
      <property name="width" value="100%"/>
      <property name="height" value="100%"/>
      <property name="zIndex" value="2"/>
    </media>
    <media id="music" src="audio.mp3"/>
    <media id="img1" src="image1.png">
      <property name="left" value="5%"/>
      <property name="top" value="6.7%"/>
      <property name="width" value="18.5%"/>
      <property name="height" value="18.5%"/>
      <property name="zIndex" value="3"/>
    </media>
    <media id="img2" src="image2.png">
      <property name="left" value="10%"/>
      <property name="top" value="20%"/>
      <property name="width" value="30%"/>
      <property name="height" value="40%"/>
      <property name="zIndex" value="5"/>
      <property name="explicitDur" value="5s"/>
    </media>
    <link id="link1" xconnector="onBeginStart_delay">
      <bind role="onBegin" component="animation"/>
      <bind role="start" component="music">
        <bindParam name="delay" value="5s"/>
      </bind>
    </link>
    <link id="link2" xconnector="onBeginStart">
      <bind role="onBegin" component="animation" interface="seg1"/>
      <bind role="start" component="img1"/>
    </link>
    <link id="link3" xconnector="onBeginStart">
      <bind role="onBegin" component="animation" interface="seg2"/>
      <bind role="start" component="img2"/>
    </link>
    <link id="link4" xconnector="onEndStop">
      <bind role="onEnd" component="animation"/>
      <bind role="stop" component="music"/>
    </link>
  </body>
</ncl>''',
      );
      doc.start();

      var active = doc.getActiveMedia().map((m) => m.id).toList();
      expect(active, contains('animation'));
      expect(active, isNot(contains('music')));

      doc.tick(4000);
      active = doc.getActiveMedia().map((m) => m.id).toList();
      expect(active, contains('animation'));
      expect(active, isNot(contains('music')));

      doc.tick(1000);
      active = doc.getActiveMedia().map((m) => m.id).toList();
      expect(active, contains('animation'));
      expect(active, contains('music'));

      doc.tick(7000);
      active = doc.getActiveMedia().map((m) => m.id).toList();
      expect(active, contains('animation'));
      expect(active, contains('music'));
      expect(active, contains('img1'));

      final img1 = doc.getNodeById('img1') as Media;
      final leftProp = img1.getProperties().firstWhere((p) => p.name == 'left');
      expect(leftProp.value, '5%');
      final zIndexProp = img1.getProperties().firstWhere(
        (p) => p.name == 'zIndex',
      );
      expect(zIndexProp.value, '3');
    });
  });
}
