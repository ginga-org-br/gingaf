import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:nclui/ncl.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mock_video_player.dart';

const _joao08animationNcl = '''<ncl id="nclAnimation" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <ruleBase>
      <rule id="en" var="system.language" value="eng" comparator="eq"/>
    </ruleBase>
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
      <descriptor id="dribleDesc" region="frameReg"/>
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
      <causalConnector id="onBeginStartSet_var_delay_duration">
        <connectorParam name="var"/>
        <connectorParam name="delay"/>
        <connectorParam name="duration"/>
        <simpleCondition role="onBegin"/>
        <compoundAction operator="seq">
          <simpleAction role="start"/>
          <simpleAction role="set" value="\$var" delay="\$delay" duration="\$duration"/>
        </compoundAction>
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
    <media id="photo" src="media/photo.png" descriptor="photoDesc">
      <property name="top"/>
    </media>
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
    <link id="lPhoto" xconnector="onBeginStartSet_var_delay_duration">
      <bind role="onBegin" component="animation" interface="segPhoto"/>
      <bind role="start" component="photo"/>
      <bind role="set" component="photo" interface="top">
        <bindParam name="var" value="290"/>
        <bindParam name="delay" value="1s"/>
        <bindParam name="duration" value="3s"/>
      </bind>
    </link>
    <link id="lEnd" xconnector="onEndStop">
      <bind role="onEnd" component="animation"/>
      <bind role="stop" component="background"/>
      <bind role="stop" component="choro"/>
    </link>
  </body>
</ncl>''';

void main() {
  setUpAll(() {
    VideoPlayerPlatform.instance = MockVideoPlayer();
  });

  test(
      'NclDocument executes duration-based SET action property changes correctly',
      () {
    final doc = NclDocument.fromContent(
        '''<ncl id="nclAnimation" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <connectorBase>
      <causalConnector id="onBeginStartSet_var_delay_duration">
        <connectorParam name="var"/>
        <connectorParam name="delay"/>
        <connectorParam name="duration"/>
        <simpleCondition role="onBegin"/>
        <compoundAction operator="seq">
          <simpleAction role="start"/>
          <simpleAction role="set" value="\$var" delay="\$delay" duration="\$duration"/>
        </compoundAction>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="m1.mp4">
      <area id="a1" begin="10s"/>
    </media>
    <media id="m2" src="m2.png">
      <property name="p"/>
    </media>
    <link id="l1" xconnector="onBeginStartSet_var_delay_duration">
      <bind role="onBegin" component="m1" interface="a1"/>
      <bind role="start" component="m2"/>
      <bind role="set" component="m2" interface="p">
        <bindParam name="var" value="active"/>
        <bindParam name="delay" value="2s"/>
        <bindParam name="duration" value="5s"/>
      </bind>
    </link>
  </body>
</ncl>''');

    doc.start();
    doc.tick(10000);

    final m2 = doc.getMediaById('m2')!;
    final prop = m2.getPropertyNclEvent('p');

    expect(m2.getMainState(), NclStateType.occurring);
    expect(prop.state, NclStateType.sleeping);

    doc.tick(1000);
    expect(prop.state, NclStateType.sleeping);

    doc.tick(1000);
    expect(prop.state, NclStateType.occurring);
    expect(m2.getProperties().firstWhere((p) => p.name == 'p').value, isNull);

    doc.tick(4000);
    expect(prop.state, NclStateType.occurring);

    doc.tick(1000);
    expect(prop.state, NclStateType.sleeping);
    final pVal = m2.getProperties().firstWhere((p) => p.name == 'p');
    expect(pVal.value, 'active');
  });

  testWidgets('NclWidget runs animation example structure successfully',
      (WidgetTester tester) async {
    final gingacc = GingaCC(
      virtualFiles: {'joao08animation.ncl': _joao08animationNcl},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NclWidget(
            src: 'joao08animation.ncl',
            gingacc: gingacc,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final nclState = tester.state<NclWidgetState>(find.byType(NclWidget));
    expect(nclState.nclDocument, isNotNull);

    nclState.tick(41000);
    await tester.pump();

    final photo = nclState.nclDocument!.getMediaById('photo')!;
    expect(photo.getMainState(), NclStateType.occurring);
    final prop = photo.getPropertyNclEvent('top');

    nclState.tick(1000);
    expect(prop.state, NclStateType.occurring);

    nclState.tick(3000);
    expect(prop.state, NclStateType.sleeping);

    final topVal = photo.getProperties().firstWhere((p) => p.name == 'top');
    expect(topVal.value, '290');
  });
}
