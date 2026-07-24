import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('primeiro_joao_12embNCL', () {
    const xml =
        '''<ncl id="_03prepPassiveDevicesEx" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="screenReg" width="100%" height="100%" zIndex="1">
        <region id="frameReg" left="5%" top="6.7%" width="18.5%" height="18.5%" zIndex="2"/>
      </region>
      <region id="passiveAdvReg" left="5%" top="5%" width="40%" height="40%" zIndex="2"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="passiveAdvDesc" region="passiveAdvReg" focusIndex="5" focusBorderWidth="0"/>
      <descriptor id="screenDesc" region="screenReg"/>
      <descriptor id="photoDesc" region="frameReg" explicitDur="3s"/>
      <descriptor id="audioDesc"/>
      <descriptor id="dribleDesc" region="frameReg"/>
    </descriptorBase>
    <connectorBase>
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
    <media id="animation" src="media/animGar.mp4" descriptor="screenDesc">
      <area id="segDrible" begin="12s"/>
      <area id="segPhoto" begin="41s"/>
      <area id="segIcon" begin="45s" end="51s"/>
    </media>
    <media id="choro" src="media/choro.mp4" descriptor="audioDesc"/>
    <media id="drible" src="media/drible.mp4" descriptor="dribleDesc"/>
    <media id="photo" src="media/photo.png" descriptor="photoDesc"/>
    <media id="advert" src="advert.ncl" descriptor="passiveAdvDesc"/>
    <link id="lIcon" xconnector="onBeginStart">
      <bind role="onBegin" component="animation" interface="segIcon"/>
      <bind role="start" component="advert"/>
    </link>
  </body>
</ncl>''';

    test('NCLDocument runs embedded NCL document successfully', () {
      final doc = NCLDocument.fromXML(xml);
      doc.start();
      doc.tick(45000);
      final active = doc.getActiveMedia().map((m) => m.id).toList();
      expect(active, contains('advert'));
    });
  });
}
