import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:nclui/ncl.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mock_video_player.dart';

const _joao00syncPropNcl = '''<ncl id="mySyncTest" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
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
</ncl>''';

void main() {
  late MockVideoPlayer fakePlatform;

  setUp(() {
    fakePlatform = MockVideoPlayer();
    VideoPlayerPlatform.instance = fakePlatform;
  });

  test('NclDocument delay and property parsing', () {
    final doc = NclDocument.fromContent(
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
</ncl>''');
    doc.start();

    final animation = doc.getMediaById('animation')!;
    final music = doc.getMediaById('music')!;
    final img1 = doc.getMediaById('img1')!;
    final img2 = doc.getMediaById('img2')!;

    expect(animation.getMainState(), NclStateType.occurring);
    expect(music.getMainState(), NclStateType.sleeping);
    expect(img1.getMainState(), NclStateType.sleeping);
    expect(img2.getMainState(), NclStateType.sleeping);

    doc.tick(4000);
    expect(animation.getMainState(), NclStateType.occurring);
    expect(music.getMainState(), NclStateType.sleeping);

    doc.tick(1000);
    expect(animation.getMainState(), NclStateType.occurring);
    expect(music.getMainState(), NclStateType.occurring);

    doc.tick(7000);
    expect(animation.getMainState(), NclStateType.occurring);
    expect(music.getMainState(), NclStateType.occurring);
    expect(img1.getMainState(), NclStateType.occurring);

    final leftProp = img1.getProperties().firstWhere((p) => p.name == 'left');
    expect(leftProp.value, '5%');
    final zIndexProp =
        img1.getProperties().firstWhere((p) => p.name == 'zIndex');
    expect(zIndexProp.value, '3');
  });

  testWidgets(
      'NclWidget layouts children based on parsed properties and sorts by zIndex',
      (WidgetTester tester) async {
    final gingacc = GingaCC(
      virtualFiles: {'joao00syncProp.ncl': _joao00syncPropNcl},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NclWidget(
            src: 'joao00syncProp.ncl',
            gingacc: gingacc,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final nclState = tester.state<NclWidgetState>(find.byType(NclWidget));

    nclState.tick(12000);
    await tester.pump();

    expect(find.byType(Positioned), findsNWidgets(3));

    final posList =
        tester.widgetList<Positioned>(find.byType(Positioned)).toList();
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

    final posList2 =
        tester.widgetList<Positioned>(find.byType(Positioned)).toList();
    expect(posList2.length, 4);

    final p0 = posList2[0];
    final p1 = posList2[1];
    final p2 = posList2[2];
    final p3 = posList2[3];

    expect(p0.width, moreOrLessEquals(800.0));
    expect(p1.width, moreOrLessEquals(800.0));
    expect(p2.left, moreOrLessEquals(40.0));
    expect(p3.left, moreOrLessEquals(80.0));
    expect(p3.top, moreOrLessEquals(120.0));
    expect(p3.width, moreOrLessEquals(240.0));
    expect(p3.height, moreOrLessEquals(240.0));
  });
}
