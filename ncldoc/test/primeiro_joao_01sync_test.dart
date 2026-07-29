import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('primeiro_joao_01sync', () {
    test('NCLDocument descriptor duration and region resolution', () {
      final doc = NCLDocument.fromContent(
        '''<ncl id="syncTest" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="baseRegion" width="100%" height="100%" zIndex="2">
        <region id="overlayRegion" left="5%" top="6.7%" width="18.5%" height="18.5%" zIndex="3"/>
      </region>
    </regionBase>
    <descriptorBase>
      <descriptor id="fullscreenDesc" region="baseRegion"/>
      <descriptor id="popupDesc" region="overlayRegion" explicitDur="5s"/>
      <descriptor id="bgMusicDesc"/>
      <descriptor id="insertVideoDesc" region="overlayRegion"/>
    </descriptorBase>
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
    <port id="entry" component="mainVideo"/>
    <media id="mainVideo" src="mainVideo.mp4" descriptor="fullscreenDesc">
      <area id="dribleSegment" begin="12s"/>
      <area id="photoSegment" begin="41s"/>
    </media>
    <media id="bgMusic" src="bgMusic.mp3" descriptor="bgMusicDesc"/>
    <media id="insertVideo" src="insertVideo.mp4" descriptor="insertVideoDesc"/>
    <media id="popupPic" src="popupPic.png" descriptor="popupDesc"/>
    <link id="linkMusic" xconnector="onBeginStart_delay">
      <bind role="onBegin" component="mainVideo"/>
      <bind role="start" component="bgMusic">
        <bindParam name="delay" value="5s"/>
      </bind>
    </link>
    <link id="linkDrible" xconnector="onBeginStart">
      <bind role="onBegin" component="mainVideo" interface="dribleSegment"/>
      <bind role="start" component="insertVideo"/>
    </link>
    <link id="linkPhoto" xconnector="onBeginStart">
      <bind role="onBegin" component="mainVideo" interface="photoSegment"/>
      <bind role="start" component="popupPic"/>
    </link>
    <link id="linkEnd" xconnector="onEndStop">
      <bind role="onEnd" component="mainVideo"/>
      <bind role="stop" component="bgMusic"/>
    </link>
  </body>
</ncl>''',
      );
      doc.start();

      var active = doc.getActiveMedia().map((m) => m.id).toList();
      expect(active, contains('mainVideo'));
      expect(active, isNot(contains('bgMusic')));

      final mainVideo = doc.getNodeById('mainVideo') as Media;
      final bgMusic = doc.getNodeById('bgMusic') as Media;
      final insertVideo = doc.getNodeById('insertVideo') as Media;
      final popupPic = doc.getNodeById('popupPic') as Media;

      expect(mainVideo.getMainState(), State.OCCURRING);
      expect(bgMusic.getMainState(), State.SLEEPING);
      expect(insertVideo.getMainState(), State.SLEEPING);
      expect(popupPic.getMainState(), State.SLEEPING);

      doc.tick(4000);
      active = doc.getActiveMedia().map((m) => m.id).toList();
      expect(active, contains('mainVideo'));
      expect(active, isNot(contains('bgMusic')));
      expect(bgMusic.getMainState(), State.SLEEPING);

      doc.tick(1000);
      active = doc.getActiveMedia().map((m) => m.id).toList();
      expect(active, contains('mainVideo'));
      expect(active, contains('bgMusic'));
      expect(bgMusic.getMainState(), State.OCCURRING);

      doc.tick(7000);
      active = doc.getActiveMedia().map((m) => m.id).toList();
      expect(active, contains('mainVideo'));
      expect(active, contains('bgMusic'));
      expect(active, contains('insertVideo'));
      expect(insertVideo.getMainState(), State.OCCURRING);

      expect(popupPic.explicitDurMs, 5000);
    });
  });
}
