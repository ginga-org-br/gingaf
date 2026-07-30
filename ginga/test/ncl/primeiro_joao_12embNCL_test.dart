import 'dart:async';
import 'package:flutter/material.dart' hide Action, State;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ncl/ncl_app.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:ncldoc/elements.dart';
import 'package:ncldoc/event.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../mock_video_player.dart';

class MockEmbNclAssetBundle extends CachingAssetBundle {
  final String language;
  MockEmbNclAssetBundle({this.language = 'por'});

  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'joao12embNCL.ncl') {
      return '''<ncl id="_03prepPassiveDevicesEx" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
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
    } else if (key == 'advert.ncl') {
      return '''<ncl id="_00prepPassiveDevicesEx" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="backgroundReg" width="100%" height="100%" zIndex="5">
        <region id="iconReg" width="100%" height="100%" zIndex="6"/>
      </region>
    </regionBase>
    <descriptorBase>
      <descriptor id="backgroundDesc" region="backgroundReg" explicitDur="12s"/>
      <descriptor id="iconDesc" region="iconReg" explicitDur="6s" focusIndex="1"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onBeginStart">
        <simpleCondition role="onBegin"/>
        <simpleAction role="start" max="unbounded" qualifier="par"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body id="adv">
    <port id="pIcon" component="icon"/>
    <media id="icon" src="../media/iconPassive.png" descriptor="iconDesc"/>
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

  testWidgets('NCLApp runs embedded NCL document successfully', (WidgetTester tester) async {
    final mockBundle = MockEmbNclAssetBundle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultAssetBundle(
            bundle: mockBundle,
            child: NCLApp(src: 'joao12embNCL.ncl'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final nclState = tester.state<NCLAppState>(find.byType(NCLApp));
    expect(nclState.nclDocument, isNotNull);

    nclState.tick(45000);
    await tester.pump();

    final activeMedia = nclState.nclDocument!.getActiveMedia().map((m) => m.id).toList();
    expect(activeMedia, contains('advert'));
  });
}
