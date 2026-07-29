import 'dart:async';
import 'package:flutter/material.dart' hide Action;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ncl/ncl_app.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:ncldoc/elements.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../mock_video_player.dart';

class MockContextAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'joao03context.ncl') {
      return '''<ncl id="nclCtx" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
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
</ncl>''';
    }
    return '';
  }
}

void main() {
  setUpAll(() {
    VideoPlayerPlatform.instance = MockVideoPlayer();
  });

  test('NCLDocument executes context and port mapping correctly', () {
    final doc = NCLDocument.fromContent('''<ncl id="nclCtx" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
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
</ncl>''');

    doc.start();
    var active = doc.getActiveMedia().map((m) => m.id).toList();
    expect(active, contains('mMain'));
    expect(active, isNot(contains('mIcon')));

    doc.tick(45000);
    active = doc.getActiveMedia().map((m) => m.id).toList();
    expect(active, contains('mMain'));
    expect(active, contains('mIcon'));
    expect(active, isNot(contains('mShoes')));

    doc.triggerSelection('mIcon', 'RED');
    doc.tick(0);

    active = doc.getActiveMedia().map((m) => m.id).toList();
    expect(active, contains('mMain'));
    expect(active, isNot(contains('mIcon')));
    expect(active, contains('mShoes'));

    final mMain = doc.getNodeById('mMain') as Media;
    final boundsProp = mMain.getProperties().firstWhere((p) => p.name == 'bounds');
    expect(boundsProp.value, '5%,6.7%,45%,45%');

    final mShoes = doc.getNodeById('mShoes') as Media;
    doc.uiQueue.add(
      Action(
        event: mShoes.getMainEvent(),
        action: ActionType.STOP,
      ),
    );
    doc.tick(0);

    expect(boundsProp.value, '0,0,100%,100%');
  });

  testWidgets('NCLApp updates widget layouts for nested context selection',
      (WidgetTester tester) async {
    final mockBundle = MockContextAssetBundle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultAssetBundle(
            bundle: mockBundle,
            child: NCLApp(uri: 'joao03context.ncl'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final nclState = tester.state<NCLAppState>(find.byType(NCLApp));

    nclState.tick(45000);
    await tester.pump();

    final posList = tester.widgetList<Positioned>(find.byType(Positioned)).toList();
    expect(posList.length, 6);

    nclState.nclDocument?.triggerSelection('mIcon', 'RED');
    nclState.tick(0);
    await tester.pump();

    final posList2 = tester.widgetList<Positioned>(find.byType(Positioned)).toList();
    expect(posList2.length, 6);

    final mainVideoWidget = posList2.firstWhere((p) => p.width == 360.0);
    expect(mainVideoWidget.left, moreOrLessEquals(40.0));
    expect(mainVideoWidget.top, moreOrLessEquals(40.2));
    expect(mainVideoWidget.width, moreOrLessEquals(360.0));
    expect(mainVideoWidget.height, moreOrLessEquals(270.0));
  });
}
