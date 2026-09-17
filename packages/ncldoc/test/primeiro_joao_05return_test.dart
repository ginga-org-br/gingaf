import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('primeiro_joao_05return', () {
    test('NclDocument executes form return logic correctly', () {
      final doc = NclDocument.fromContent(
        '''<ncl id="nclReturn" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="rBg" width="100%" height="100%" zIndex="1"/>
      <region id="rMain" width="100%" height="100%" zIndex="2">
        <region id="rSub1" left="5%" top="6.7%" width="18.5%" height="18.5%" zIndex="3"/>
        <region id="rSub2" left="87.5%" top="11.7%" width="8.45%" height="6.7%" zIndex="3"/>
        <region id="rSub3" left="15%" top="60%" width="25%" height="25%" zIndex="3"/>
        <region id="rSub4" left="57.25%" top="9.83%" width="37.75%" height="70.2%" zIndex="3"/>
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
      <descriptor id="dForm" region="rSub4" explicitDur="15s"/>
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
        <connectorParam name="keyCode"/>
        <connectorParam name="var"/>
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
    <port id="pEntry" component="mMain"/>
    <media id="mBg" src="bg.png" descriptor="dBg"/>
    <media id="mMain" src="main.mp4" descriptor="dMain">
      <area id="sDrible" begin="12s"/>
      <area id="sPhoto" begin="41s"/>
      <area id="sIcon" begin="45s" end="51s"/>
    </media>
    <media id="mAudio" src="music.mp3" descriptor="dAudio"/>
    <media id="mDrible" src="drible.mp4" descriptor="dInsert"/>
    <media id="mPhoto" src="photo.png" descriptor="dPopup"/>
    <context id="ctxAdvert">
      <media id="mReused" refer="mMain" instance="instSame">
        <property name="bounds"/>
      </media>
      <media id="mIcon" src="icon.png" descriptor="dIcon"/>
      <media id="mShoes" src="shoes.mp4" descriptor="dPromo"/>
      <media id="mForm" src="form.html" descriptor="dForm"/>
      <link id="lIcon" xconnector="onBeginStart">
        <bind role="onBegin" component="mReused" interface="sIcon"/>
        <bind role="start" component="mIcon"/>
      </link>
      <link id="lBegingShoes" xconnector="onKeySelectionStopSet_varStart">
        <bind role="onSelection" component="mIcon">
          <bindParam name="keyCode" value="RED"/>
        </bind>
        <bind role="start" component="mShoes"/>
        <bind role="start" component="mForm"/>
        <bind role="set" component="mReused" interface="bounds">
          <bindParam name="var" value="5%,6.7%,45%,45%"/>
        </bind>
        <bind role="stop" component="mIcon"/>
      </link>
      <link id="lEndForm" xconnector="onEndSet_var">
        <bind role="onEnd" component="mForm"/>
        <bind role="set" component="mReused" interface="bounds">
          <bindParam name="var" value="0,0,100%,100%"/>
        </bind>
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
  </body>
</ncl>''',
      );

      doc.start();
      final mMain = doc.getMediaById('mMain')!;
      final mIcon = doc.getMediaById('mIcon')!;
      final mShoes = doc.getMediaById('mShoes')!;
      final mForm = doc.getMediaById('mForm')!;
      final ctxAdvert = doc.getContextById('ctxAdvert')!;

      expect(ctxAdvert.getMainState(), NclStateType.sleeping);
      expect(mMain.getMainState(), NclStateType.occurring);
      expect(mIcon.getMainState(), NclStateType.sleeping);
      expect(mShoes.getMainState(), NclStateType.sleeping);
      expect(mForm.getMainState(), NclStateType.sleeping);

      doc.tick(45000);
      expect(mMain.getMainState(), NclStateType.occurring);
      expect(mIcon.getMainState(), NclStateType.occurring);
      expect(mShoes.getMainState(), NclStateType.sleeping);
      expect(mForm.getMainState(), NclStateType.sleeping);
      expect(ctxAdvert.getMainState(), NclStateType.occurring);

      doc.triggerSelection('mIcon', 'RED');
      doc.tick(0);

      expect(mMain.getMainState(), NclStateType.occurring);
      expect(mIcon.getMainState(), NclStateType.sleeping);
      expect(mShoes.getMainState(), NclStateType.occurring);
      expect(mForm.getMainState(), NclStateType.occurring);
      expect(ctxAdvert.getMainState(), NclStateType.occurring);

      final boundsProp = mMain.getProperties().firstWhere(
            (p) => p.name == 'bounds',
          );
      expect(boundsProp.value, '5%,6.7%,45%,45%');

      doc.tick(15000);
      expect(mMain.getMainState(), NclStateType.occurring);
      expect(mForm.getMainState(), NclStateType.sleeping);
      expect(ctxAdvert.getMainState(), NclStateType.occurring);
      expect(boundsProp.value, '0,0,100%,100%');
    });
  });
}
