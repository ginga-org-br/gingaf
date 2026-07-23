import 'package:ncl_doc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('primeiro_joao_03context', () {
    test('NCLDocument executes context and port mapping correctly', () {
      final doc = NCLDocument.fromXML(
        '''<ncl id="nclCtx" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="rBg" width="100%" height="100%" zIndex="1"/>
      <region id="rMain" width="100%" height="100%" zIndex="2">
        <region id="rSub1" left="5%" top="6.7%" width="18.5%" height="18.5%" zIndex="3"/>
        <region id="rSub2" left="87.5%" top="11.7%" width="8.45%" height="6.7%" zIndex="3"/>
        <region id="rSub3" left="15%" top="60%" width="25%" height="25%" zIndex="3"/>
      </region>
    </regionBase>
    <descriptorBase>
      <descriptor id="dBg" region="rBg"/>
      <descriptor id="dMain" region="rMain"/>
      <descriptor id="dPopup" region="rSub1" explicitDur="5s"/>
      <descriptor id="dAudio"/>
      <descriptor id="dInsert" region="rSub1"/>
      <descriptor id="dIcon" region="rSub2" explicitDur="6s"/>
      <descriptor id="dPromo" region="rSub3"/>
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
      <causalConnector id="onKeySelectionStopStart">
        <connectorParam name="keyCode"/>
        <simpleCondition role="onSelection" key="\$keyCode"/>
        <compoundAction operator="seq">
          <simpleAction role="stop" max="unbounded" qualifier="par"/>
          <simpleAction role="start" max="unbounded" qualifier="par"/>
        </compoundAction>
      </causalConnector>
      <causalConnector id="onKeySelectionSet_var">
        <connectorParam name="keyCode"/>
        <connectorParam name="var"/>
        <simpleCondition role="onSelection" key="\$keyCode"/>
        <simpleAction role="set" value="\$var"/>
      </causalConnector>
      <causalConnector id="onEndSet_var">
        <connectorParam name="var"/>
        <simpleCondition role="onEnd"/>
        <simpleAction role="set" value="\$var"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="pEntry" component="mMain"/>
    <media id="mBg" src="bg.png" descriptor="dBg"/>
    <media id="mMain" src="main.mp4" descriptor="dMain">
      <area id="sDrible" begin="12s"/>
      <area id="sPhoto" begin="41s"/>
      <area id="sIcon" begin="45s" end="51s"/>
      <property name="bounds"/>
    </media>
    <media id="mAudio" src="music.mp3" descriptor="dAudio"/>
    <media id="mDrible" src="drible.mp4" descriptor="dInsert"/>
    <media id="mPhoto" src="photo.png" descriptor="dPopup"/>
    <context id="ctxAdvert">
      <port id="ptIcon" component="mIcon"/>
      <port id="ptShoes" component="mShoes"/>
      <media id="mIcon" src="icon.png" descriptor="dIcon"/>
      <media id="mShoes" src="shoes.mp4" descriptor="dPromo"/>
      <link id="lBegShoes" xconnector="onKeySelectionStopStart">
        <bind role="onSelection" component="mIcon">
          <bindParam name="keyCode" value="RED"/>
        </bind>
        <bind role="start" component="mShoes"/>
        <bind role="stop" component="mIcon"/>
      </link>
    </context>
    <link id="lMusic" xconnector="onBeginStart_delay">
      <bind role="onBegin" component="mMain"/>
      <bind role="start" component="mBg">
        <bindParam name="delay" value="5s"/>
      </bind>
      <bind role="start" component="mAudio">
        <bindParam name="delay" value="5s"/>
      </bind>
    </link>
    <link id="lDrible" xconnector="onBeginStart">
      <bind role="onBegin" component="mMain" interface="sDrible"/>
      <bind role="start" component="mDrible"/>
    </link>
    <link id="lPhoto" xconnector="onBeginStart">
      <bind role="onBegin" component="mMain" interface="sPhoto"/>
      <bind role="start" component="mPhoto"/>
    </link>
    <link id="lEnd" xconnector="onEndStop">
      <bind role="onEnd" component="mMain"/>
      <bind role="stop" component="mBg"/>
      <bind role="stop" component="mAudio"/>
    </link>
    <link id="lIcon" xconnector="onBeginStart">
      <bind role="onBegin" component="mMain" interface="sIcon"/>
      <bind role="start" component="ctxAdvert" interface="ptIcon"/>
    </link>
    <link id="lAdvert" xconnector="onKeySelectionSet_var">
      <bind role="onSelection" component="ctxAdvert" interface="ptIcon">
        <bindParam name="keyCode" value="RED"/>
      </bind>
      <bind role="set" component="mMain" interface="bounds">
        <bindParam name="var" value="5%,6.7%,45%,45%"/>
      </bind>
    </link>
    <link id="lEndAdvert" xconnector="onEndSet_var">
      <bind role="onEnd" component="ctxAdvert" interface="ptShoes"/>
      <bind role="set" component="mMain" interface="bounds">
        <bindParam name="var" value="0,0,100%,100%"/>
      </bind>
    </link>
  </body>
</ncl>''',
      );

      doc.start();
      final mMain = doc.getNodeById('mMain') as Media;
      final mIcon = doc.getNodeById('mIcon') as Media;
      final mShoes = doc.getNodeById('mShoes') as Media;

      expect(mMain.getMainState(), State.OCCURRING);
      expect(mIcon.getMainState(), State.SLEEPING);
      expect(mShoes.getMainState(), State.SLEEPING);

      var active = doc.getActiveMedia().map((m) => m.id).toList();
      expect(active, contains('mMain'));
      expect(active, isNot(contains('mIcon')));

      doc.tick(45000);
      active = doc.getActiveMedia().map((m) => m.id).toList();
      expect(active, contains('mMain'));
      expect(active, contains('mIcon'));
      expect(active, isNot(contains('mShoes')));
      expect(mIcon.getMainState(), State.OCCURRING);

      doc.triggerSelection('mIcon', 'RED');
      doc.tick(0);

      active = doc.getActiveMedia().map((m) => m.id).toList();
      expect(active, contains('mMain'));
      expect(active, isNot(contains('mIcon')));
      expect(active, contains('mShoes'));
      expect(mIcon.getMainState(), State.SLEEPING);
      expect(mShoes.getMainState(), State.OCCURRING);

      final boundsProp = mMain.getProperties().firstWhere(
        (p) => p.name == 'bounds',
      );
      expect(boundsProp.value, '5%,6.7%,45%,45%');

      doc.uiQueue.add(
        Action(event: mShoes.getMainEvent(), action: ActionType.STOP),
      );
      doc.tick(0);

      expect(mShoes.getMainState(), State.SLEEPING);
      expect(boundsProp.value, '0,0,100%,100%');
    });
  });
}
