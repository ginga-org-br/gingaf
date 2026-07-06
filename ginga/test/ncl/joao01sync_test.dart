import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ncl/ncl_app.dart';
import 'package:ncl_doc/ncl_document.dart';
import 'package:ncl_doc/elements.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../mock_video_player.dart';

class MockSyncAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'joao01sync.ncl') {
      return '''<ncl id="syncTest" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
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
</ncl>''';
    }
    throw FlutterError('MockSyncAssetBundle: Unknown key \$key');
  }
}

void main() {
  late MockVideoPlayer fakePlatform;

  setUp(() {
    fakePlatform = MockVideoPlayer();
    VideoPlayerPlatform.instance = fakePlatform;
  });

  test('NCLDocument descriptor duration and region resolution', () {
    final doc = NCLDocument.fromXML('''<ncl id="syncTest" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
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
</ncl>''');
    doc.start();

    var active = doc.getActiveMedia().map((m) => m.id).toList();
    expect(active, contains('mainVideo'));
    expect(active, isNot(contains('bgMusic')));

    doc.tick(4000);
    active = doc.getActiveMedia().map((m) => m.id).toList();
    expect(active, contains('mainVideo'));
    expect(active, isNot(contains('bgMusic')));

    doc.tick(1000);
    active = doc.getActiveMedia().map((m) => m.id).toList();
    expect(active, contains('mainVideo'));
    expect(active, contains('bgMusic'));

    doc.tick(7000);
    active = doc.getActiveMedia().map((m) => m.id).toList();
    expect(active, contains('mainVideo'));
    expect(active, contains('bgMusic'));
    expect(active, contains('insertVideo'));

    final popupPic = doc.getNodeById('popupPic') as Media;
    expect(popupPic.explicitDurMs, 5000);
  });

  testWidgets('NCLApp layouts children based on descriptors and region hierarchy',
      (WidgetTester tester) async {
    final mockBundle = MockSyncAssetBundle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultAssetBundle(
            bundle: mockBundle,
            child: NCLApp(uri: 'joao01sync.ncl'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final nclState = tester.state<NCLAppState>(find.byType(NCLApp));

    nclState.tick(12000);
    await tester.pump();

    final posList = tester.widgetList<Positioned>(find.byType(Positioned)).toList();
    expect(posList.length, 3);

    final pos0 = posList[0];
    final pos1 = posList[1];
    final pos2 = posList[2];

    expect(pos0.width, moreOrLessEquals(800.0));
    expect(pos0.height, moreOrLessEquals(600.0));

    expect(pos1.width, moreOrLessEquals(800.0));
    expect(pos1.height, moreOrLessEquals(600.0));

    expect(pos2.left, moreOrLessEquals(40.0));
    expect(pos2.top, moreOrLessEquals(40.2));
    expect(pos2.width, moreOrLessEquals(148.0));
    expect(pos2.height, moreOrLessEquals(111.0));

    nclState.tick(29000);
    await tester.pump();

    final posList2 = tester.widgetList<Positioned>(find.byType(Positioned)).toList();
    expect(posList2.length, 4);

    final posPopup = posList2[3];
    expect(posPopup.left, moreOrLessEquals(40.0));
    expect(posPopup.top, moreOrLessEquals(40.2));
    expect(posPopup.width, moreOrLessEquals(148.0));
    expect(posPopup.height, moreOrLessEquals(111.0));
  });
}
