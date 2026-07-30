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

class MockSyncIntAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'joao02syncInt.ncl') {
      return '''<ncl id="joaoSyncIntTest" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
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
</ncl>''';
    }
    throw FlutterError('MockSyncIntAssetBundle: Unknown key \$key');
  }
}

void main() {
  late MockVideoPlayer fakePlatform;

  setUp(() {
    fakePlatform = MockVideoPlayer();
    VideoPlayerPlatform.instance = fakePlatform;
  });

  test('NCLDocument key selection, property SET, and layout change resolution', () {
    final doc = NCLDocument.fromContent('''<ncl id="joaoSyncIntTest" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
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
</ncl>''');
    doc.start();

    // Verify mainVideo starts, btnIcon is sleeping
    var active = doc.getActiveMedia().map((m) => m.id).toList();
    expect(active, contains('mainVideo'));
    expect(active, isNot(contains('btnIcon')));

    // Tick to 45s (45000ms), segIcon triggers, starting btnIcon
    doc.tick(45000);
    active = doc.getActiveMedia().map((m) => m.id).toList();
    expect(active, contains('mainVideo'));
    expect(active, contains('btnIcon'));
    expect(active, isNot(contains('promoVideo')));

    // Trigger key RED selection on btnIcon
    doc.triggerSelection('btnIcon', 'RED');
    doc.tick(0);

    // btnIcon should stop, promoVideo should start, and mainVideo's bounds should be updated
    active = doc.getActiveMedia().map((m) => m.id).toList();
    expect(active, contains('mainVideo'));
    expect(active, isNot(contains('btnIcon')));
    expect(active, contains('promoVideo'));

    final mainVideo = doc.getNodeById('mainVideo') as Media;
    final boundsProp = mainVideo.getProperties().firstWhere((p) => p.name == 'bounds');
    expect(boundsProp.value, '5%,6.7%,45%,45%');

    // Stop promoVideo (simulate video naturally ending)
    final promoVideo = doc.getNodeById('promoVideo') as Media;
    
    // Simulate end of promoVideo using the uiQueue
    doc.uiQueue.add(
      Action(
        event: promoVideo.getMainEvent(),
        action: ActionType.STOP,
      ),
    );
    doc.tick(0); // triggers link7 (onEnd promoVideo -> set mainVideo bounds to 0,0,100%,100%)

    expect(boundsProp.value, '0,0,100%,100%');
  });

  testWidgets('NCLApp updates widget sizes and positions in response to SET action from key selection',
      (WidgetTester tester) async {
    final mockBundle = MockSyncIntAssetBundle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultAssetBundle(
            bundle: mockBundle,
            child: NCLApp(src: 'joao02syncInt.ncl'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final nclState = tester.state<NCLAppState>(find.byType(NCLApp));

    // Tick to 45s: mainVideo, background, ambientAudio, smallVideo, popupImg, btnIcon are running
    nclState.tick(45000);
    await tester.pump();

    // Verify all active widgets are visible
    final posList = tester.widgetList<Positioned>(find.byType(Positioned)).toList();
    expect(posList.length, 6);

    // Trigger key RED selection on btnIcon
    nclState.nclDocument?.triggerSelection('btnIcon', 'RED');
    nclState.tick(0);
    await tester.pump();

    // After key selection: btnIcon is gone, promoVideo starts
    final posList2 = tester.widgetList<Positioned>(find.byType(Positioned)).toList();
    expect(posList2.length, 6);

    // Find mainVideo Positioned widget
    // Screen is 800x600. bounds is 5%,6.7%,45%,45%
    // left: 5% of 800 = 40.0
    // top: 6.7% of 600 = 40.2
    // width: 45% of 800 = 360.0
    // height: 45% of 600 = 270.0
    final mainVideoWidget = posList2.firstWhere((p) => p.width == 360.0);
    expect(mainVideoWidget.left, moreOrLessEquals(40.0));
    expect(mainVideoWidget.top, moreOrLessEquals(40.2));
    expect(mainVideoWidget.width, moreOrLessEquals(360.0));
    expect(mainVideoWidget.height, moreOrLessEquals(270.0));
  });
}
