import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nclui/ncl.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mock_video_player.dart';

void main() {
  setUpAll(() {
    VideoPlayerPlatform.instance = MockVideoPlayer();
  });

  group('embNcl UI', () {
    const videoNcl = '''<ncl>
  <body>
    <port id="init" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4">
      <area id="a1" begin="2s" end="4s"/>
    </media>
    <media id="green_bg">
      <property name="background" value="green"/>
      <property name="bounds" value="0%,80%,20%,20%"/>
    </media>
    <media id="red_bg">
      <property name="background" value="red"/>
      <property name="bounds" value="80%,80%,20%,20%"/>
      <property name="explicitDur" value="2s"/>
    </media>
    <link id="l1">
      <bind role="onBegin" component="video" interface="a1"/>
      <bind role="start" component="green_bg"/>
    </link>
    <link id="l2">
      <bind role="onEnd" component="video" interface="a1"/>
      <bind role="stop" component="green_bg"/>
      <bind role="start" component="red_bg"/>
    </link>
  </body>
</ncl>''';

    const embNclFullScreen = '''<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="embHtml"
  xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="formReg"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="nclDesc" region="formReg" focusIndex="1"/>
    </descriptorBase>
  </head>
  <body>
    <port id="entry" component="embNcl"/>
    <media id="embNcl" src="video.ncl" type="text/ncl" descriptor="nclDesc"/>
  </body>
</ncl>''';

    const embNclNotFullScreen = '''<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="embHtml"
  xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="formReg" left="20%" top="10%" width="60%" height="80%" zIndex="0"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="nclDesc" region="formReg" focusIndex="1"/>
    </descriptorBase>
  </head>
  <body>
    <port id="entry" component="embNcl"/>
    <media id="embNcl" src="video.ncl" type="text/ncl" descriptor="nclDesc"/>
  </body>
</ncl>''';

    testWidgets(
        'full screen embedded ncl advances time and checks pixel dimensions',
        (WidgetTester tester) async {
      final gingacc = GingaCC(
        virtualFiles: {
          'main.ncl': embNclFullScreen,
          'video.ncl': videoNcl,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NclWidget(
              src: 'main.ncl',
              gingacc: gingacc,
              bounds: const Rectangle<double>(0.0, 0.0, 720.0, 480.0),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final nclWidgets =
          tester.stateList<NclWidgetState>(find.byType(NclWidget)).toList();
      expect(nclWidgets.length, 2);

      final rootState = nclWidgets[0];
      final embeddedState = nclWidgets[1];

      expect(embeddedState.rect.left, equals(0.0));
      expect(embeddedState.rect.top, equals(0.0));
      expect(embeddedState.rect.width, equals(720.0));
      expect(embeddedState.rect.height, equals(480.0));

      final videoState = tester.state<AVWidgetState>(find.byType(AVWidget));
      expect(videoState.rect.left, equals(0.0));
      expect(videoState.rect.top, equals(0.0));
      expect(videoState.rect.width, equals(720.0));
      expect(videoState.rect.height, equals(480.0));

      rootState.tick(1500);
      await tester.pump();

      rootState.tick(2000);
      await tester.pump();

      rootState.nclDocument?.stop();
      embeddedState.nclDocument?.stop();
    });

    testWidgets(
        'non-full screen embedded ncl advances time and checks pixel dimensions',
        (WidgetTester tester) async {
      final gingacc = GingaCC(
        virtualFiles: {
          'main.ncl': embNclNotFullScreen,
          'video.ncl': videoNcl,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NclWidget(
              src: 'main.ncl',
              gingacc: gingacc,
              bounds: const Rectangle<double>(0.0, 0.0, 720.0, 480.0),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final nclWidgets =
          tester.stateList<NclWidgetState>(find.byType(NclWidget)).toList();
      expect(nclWidgets.length, 2);

      final rootState = nclWidgets[0];
      final embeddedState = nclWidgets[1];

      expect(embeddedState.rect.left, moreOrLessEquals(144.0));
      expect(embeddedState.rect.top, moreOrLessEquals(48.0));
      expect(embeddedState.rect.width, moreOrLessEquals(432.0));
      expect(embeddedState.rect.height, moreOrLessEquals(384.0));

      final videoState = tester.state<AVWidgetState>(find.byType(AVWidget));
      expect(videoState.rect.left, equals(0.0));
      expect(videoState.rect.top, equals(0.0));
      expect(videoState.rect.width, moreOrLessEquals(432.0));
      expect(videoState.rect.height, moreOrLessEquals(384.0));

      rootState.tick(1500);
      await tester.pump();

      rootState.tick(2000);
      await tester.pump();

      rootState.nclDocument?.stop();
      embeddedState.nclDocument?.stop();
    });
  });
}
