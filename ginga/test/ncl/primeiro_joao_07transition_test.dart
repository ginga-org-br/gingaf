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

class MockTransitionAssetBundle extends CachingAssetBundle {
  final String language;
  MockTransitionAssetBundle({this.language = 'por'});

  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'joao07transition.ncl') {
      return '''<ncl id="nclTransition" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <ruleBase>
      <rule id="en" var="system.language" value="eng" comparator="eq"/>
    </ruleBase>
    <transitionBase>
      <transition id="trans1" type="fade" dur="2s"/>
      <transition id="trans2" type="barWipe" dur="1s"/>
    </transitionBase>
    <regionBase>
      <region id="backgroundReg" width="100%" height="100%" zIndex="1"/>
      <region id="screenReg" width="100%" height="100%" zIndex="2">
        <region id="frameReg" left="5%" top="6.7%" width="18.5%" height="18.5%" zIndex="3"/>
        <region id="iconReg" left="87.5%" top="11.7%" width="8.45%" height="6.7%" zIndex="3"/>
        <region id="shoesReg" left="15%" top="60%" width="25%" height="25%" zIndex="3"/>
        <region id="formReg" left="57.25%" top="9.83%" width="37.75%" height="70.2%" zIndex="3"/>
      </region>
    </regionBase>
    <descriptorBase>
      <descriptor id="backgroundDesc" region="backgroundReg"/>
      <descriptor id="screenDesc" region="screenReg"/>
      <descriptor id="photoDesc" region="frameReg" explicitDur="5s"/>
      <descriptor id="audioDesc"/>
      <descriptor id="dribleDesc" region="frameReg" transIn="trans1" transOut="trans2"/>
      <descriptor id="iconDesc" region="iconReg" explicitDur="6s"/>
      <descriptor id="shoesDesc" region="shoesReg"/>
      <descriptor id="formDesc" region="formReg" focusIndex="1" explicitDur="15s"/>
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
    <port id="entry" component="animation"/>
    <media id="background" src="media/background.png" descriptor="backgroundDesc"/>
    <media id="animation" src="media/animGar.mp4" descriptor="screenDesc">
      <area id="segDrible" begin="12s"/>
      <area id="segPhoto" begin="41s"/>
      <area id="segIcon" begin="45s" end="51s"/>
    </media>
    <media id="choro" src="media/choro.mp4" descriptor="audioDesc"/>
    <media id="drible" src="media/drible.mp4" descriptor="dribleDesc"/>
    <media id="photo" src="media/photo.png" descriptor="photoDesc"/>
    <context id="advert">
      <media id="reusedAnimation" refer="animation" instance="instSame">
        <property name="bounds"/>
      </media>
      <media id="icon" src="media/icon.png" descriptor="iconDesc"/>
      <media id="shoes" src="media/shoes.mp4" descriptor="shoesDesc"/>
      <switch id="form">
        <switchPort id="spForm">
          <mapping component="enForm"/>
          <mapping component="ptForm"/>
        </switchPort>
        <bindRule constituent="enForm" rule="en"/>
        <defaultComponent component="ptForm"/>
        <media id="ptForm" src="media/ptForm.htm" descriptor="formDesc"/>
        <media id="enForm" src="media/enForm.htm" descriptor="formDesc"/>
      </switch>
      <link id="lIcon" xconnector="onBeginStart">
        <bind role="onBegin" component="reusedAnimation" interface="segIcon"/>
        <bind role="start" component="icon"/>
      </link>
      <link id="lBegingShoes" xconnector="onKeySelectionStopSet_varStart">
        <bind role="onSelection" component="icon">
          <bindParam name="keyCode" value="RED"/>
        </bind>
        <bind role="start" component="shoes"/>
        <bind role="start" component="form" interface="spForm"/>
        <bind role="set" component="reusedAnimation" interface="bounds">
          <bindParam name="var" value="5%,6.7%,45%,45%"/>
        </bind>
        <bind role="stop" component="icon"/>
      </link>
      <link id="lEndForm" xconnector="onEndSet_var">
        <bind role="onEnd" component="form" interface="spForm"/>
        <bind role="set" component="reusedAnimation" interface="bounds">
          <bindParam name="var" value="0,0,100%,100%"/>
        </bind>
      </link>
    </context>
    <link id="lMusic" xconnector="onBeginStart_delay">
      <bind role="onBegin" component="animation"/>
      <bind role="start" component="background">
        <bindParam name="delay" value="5s"/>
      </bind>
      <bind role="start" component="choro">
        <bindParam name="delay" value="5s"/>
      </bind>
    </link>
    <link id="lDrible" xconnector="onBeginStart">
      <bind role="onBegin" component="animation" interface="segDrible"/>
      <bind role="start" component="drible"/>
    </link>
    <link id="lPhoto" xconnector="onBeginStart">
      <bind role="onBegin" component="animation" interface="segPhoto"/>
      <bind role="start" component="photo"/>
    </link>
    <link id="lEnd" xconnector="onEndStop">
      <bind role="onEnd" component="animation"/>
      <bind role="stop" component="background"/>
      <bind role="stop" component="choro"/>
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

  test('NCLDocument parses transitions and transition descriptors correctly', () {
    final doc = NCLDocument.fromXML('''<ncl id="nclTransition" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <transitionBase>
      <transition id="trans1" type="fade" dur="2s"/>
      <transition id="trans2" type="barWipe" dur="1s"/>
    </transitionBase>
    <descriptorBase>
      <descriptor id="dribleDesc" region="frameReg" transIn="trans1" transOut="trans2"/>
    </descriptorBase>
  </head>
  <body/>
</ncl>''');

    final headChildren = doc.headChildren;
    final transBase = headChildren.firstWhere((e) => e.xmlTagName == 'transitionBase');
    expect(transBase.children.length, 2);

    final trans1 = transBase.children.firstWhere((e) => e.rawAttributes['id'] == 'trans1');
    expect(trans1.rawAttributes['type'], 'fade');
    expect(trans1.rawAttributes['dur'], '2s');

    final descBase = headChildren.firstWhere((e) => e.xmlTagName == 'descriptorBase');
    final dribleDesc = descBase.children.firstWhere((e) => e.rawAttributes['id'] == 'dribleDesc');
    expect(dribleDesc.rawAttributes['transIn'], 'trans1');
    expect(dribleDesc.rawAttributes['transOut'], 'trans2');
  });

  testWidgets('NCLApp runs transition example structure successfully', (WidgetTester tester) async {
    final mockBundle = MockTransitionAssetBundle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultAssetBundle(
            bundle: mockBundle,
            child: NCLApp(uri: 'joao07transition.ncl'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final nclState = tester.state<NCLAppState>(find.byType(NCLApp));
    expect(nclState.nclDocument, isNotNull);

    nclState.tick(5000);
    await tester.pump();

    final activeMedia = nclState.nclDocument!.getActiveMedia().map((m) => m.id).toList();
    expect(activeMedia, contains('background'));
    expect(activeMedia, contains('choro'));
  });
}
