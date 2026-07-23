import 'package:ncl_doc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('primeiro_joao_02syncInt', () {
    test(
      'NCLDocument key selection, property SET, and layout change resolution',
      () {
        final doc = NCLDocument.fromXML(
          '''<ncl id="joaoSyncIntTest" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="bgRegion" width="100%" height="100%" zIndex="1"/>
      <region id="mainRegion" width="100%" height="100%" zIndex="2">
        <region id="subRegion1" left="5%" top="6.7%" width="18.5%" height="18.5%" zIndex="3"/>
        <region id="subRegion2" left="87.5%" top="11.7%" width="8.45%" height="6.7%" zIndex="3"/>
        <region id="subRegion3" left="15%" top="60%" width="25%" height="25%" zIndex="3"/>
      </region>
    </regionBase>
    <descriptorBase>
      <descriptor id="bgDesc" region="bgRegion"/>
      <descriptor id="mainDesc" region="mainRegion"/>
      <descriptor id="popupDesc" region="subRegion1" explicitDur="5s"/>
      <descriptor id="audioDesc"/>
      <descriptor id="insertDesc" region="subRegion1"/>
      <descriptor id="iconDesc" region="subRegion2" explicitDur="6s"/>
      <descriptor id="promoDesc" region="subRegion3"/>
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
      <causalConnector id="onKeySelectionStopSet_varStart">
        <connectorParam name="var"/>
        <connectorParam name="keyCode"/>
        <simpleCondition role="onSelection" key="\$keyCode"/>
        <compoundAction operator="seq">
          <simpleAction role="stop" max="unbounded" qualifier="par"/>
          <simpleAction role="set" value="\$var"/>
          <simpleAction role="start" max="unbounded" qualifier="par"/>
        </compoundAction>
      </causalConnector>
      <causalConnector id="onEndSet_var">
        <connectorParam name="var"/>
        <simpleCondition role="onEnd"/>
        <simpleAction role="set" value="\$var"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="entry" component="mainVideo"/>
    <media id="background" src="bg.png" descriptor="bgDesc"/>
    <media id="mainVideo" src="main.mp4" descriptor="mainDesc">
      <area id="segDrible" begin="12s"/>
      <area id="segPhoto" begin="41s"/>
      <area id="segIcon" begin="45s" end="51s"/>
      <property name="bounds"/>
    </media>
    <media id="ambientAudio" src="ambient.mp3" descriptor="audioDesc"/>
    <media id="smallVideo" src="small.mp4" descriptor="insertDesc"/>
    <media id="popupImg" src="popup.png" descriptor="popupDesc"/>
    <media id="btnIcon" src="icon.png" descriptor="iconDesc"/>
    <media id="promoVideo" src="promo.mp4" descriptor="promoDesc"/>
    <link id="link1" xconnector="onBeginStart_delay">
      <bind role="onBegin" component="mainVideo"/>
      <bind role="start" component="background">
        <bindParam name="delay" value="5s"/>
      </bind>
      <bind role="start" component="ambientAudio">
        <bindParam name="delay" value="5s"/>
      </bind>
    </link>
    <link id="link2" xconnector="onBeginStart">
      <bind role="onBegin" component="mainVideo" interface="segDrible"/>
      <bind role="start" component="smallVideo"/>
    </link>
    <link id="link3" xconnector="onBeginStart">
      <bind role="onBegin" component="mainVideo" interface="segPhoto"/>
      <bind role="start" component="popupImg"/>
    </link>
    <link id="link4" xconnector="onEndStop">
      <bind role="onEnd" component="mainVideo"/>
      <bind role="stop" component="background"/>
      <bind role="stop" component="ambientAudio"/>
    </link>
    <link id="link5" xconnector="onBeginStart">
      <bind role="onBegin" component="mainVideo" interface="segIcon"/>
      <bind role="start" component="btnIcon"/>
    </link>
    <link id="link6" xconnector="onKeySelectionStopSet_varStart">
      <bind role="onSelection" component="btnIcon">
        <bindParam name="keyCode" value="RED"/>
      </bind>
      <bind role="set" component="mainVideo" interface="bounds">
        <bindParam name="var" value="5%,6.7%,45%,45%"/>
      </bind>
      <bind role="start" component="promoVideo"/>
      <bind role="stop" component="btnIcon"/>
    </link>
    <link id="link7" xconnector="onEndSet_var">
      <bind role="onEnd" component="promoVideo"/>
      <bind role="set" component="mainVideo" interface="bounds">
        <bindParam name="var" value="0,0,100%,100%"/>
      </bind>
    </link>
  </body>
</ncl>''',
        );
        doc.start();

        final mainVideo = doc.getNodeById('mainVideo') as Media;
        final btnIcon = doc.getNodeById('btnIcon') as Media;
        final promoVideo = doc.getNodeById('promoVideo') as Media;

        expect(mainVideo.getMainState(), State.OCCURRING);
        expect(btnIcon.getMainState(), State.SLEEPING);
        expect(promoVideo.getMainState(), State.SLEEPING);

        var active = doc.getActiveMedia().map((m) => m.id).toList();
        expect(active, contains('mainVideo'));
        expect(active, isNot(contains('btnIcon')));

        doc.tick(45000);
        active = doc.getActiveMedia().map((m) => m.id).toList();
        expect(active, contains('mainVideo'));
        expect(active, contains('btnIcon'));
        expect(active, isNot(contains('promoVideo')));
        expect(btnIcon.getMainState(), State.OCCURRING);

        doc.triggerSelection('btnIcon', 'RED');
        doc.tick(0);

        active = doc.getActiveMedia().map((m) => m.id).toList();
        expect(active, contains('mainVideo'));
        expect(active, isNot(contains('btnIcon')));
        expect(active, contains('promoVideo'));
        expect(btnIcon.getMainState(), State.SLEEPING);
        expect(promoVideo.getMainState(), State.OCCURRING);

        final boundsProp = mainVideo.getProperties().firstWhere(
          (p) => p.name == 'bounds',
        );
        expect(boundsProp.value, '5%,6.7%,45%,45%');

        doc.uiQueue.add(
          Action(event: promoVideo.getMainEvent(), action: ActionType.STOP),
        );
        doc.tick(0);

        expect(promoVideo.getMainState(), State.SLEEPING);
        expect(boundsProp.value, '0,0,100%,100%');
      },
    );
  });
}
