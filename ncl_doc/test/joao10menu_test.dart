import 'package:ncl_doc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('joao10menu', () {
    const xml = '''<ncl id="menuEx" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <ruleBase>
      <rule id="en" var="system.language" value="en" comparator="eq"/>
      <rule id="rRock" var="service.currentFocus" value="3" comparator="eq"/>
      <rule id="rTechno" var="service.currentFocus" value="4" comparator="eq"/>
      <rule id="rCartoon" var="service.currentFocus" value="5" comparator="eq"/>
    </ruleBase>
    <regionBase>
      <region id="backgroundReg" width="100%" height="100%" zIndex="1">
        <region id="screenReg" width="100%" height="88%" zIndex="2"/>
        <region id="frameReg" left="5%" top="6.7%" width="18.5%" height="18.5%" zIndex="3"/>
        <region id="iconReg" left="87.5%" top="11.7%" width="8.45%" height="6.7%" zIndex="3"/>
        <region id="shoesReg" left="15%" top="60%" width="25%" height="25%" zIndex="3"/>
        <region id="formReg" left="57.25%" top="9.83%" width="37.75%" height="70.2%" zIndex="3"/>
        <region id="intReg" left="92.5%" top="91.7%" width="5.07%" height="6.51%" zIndex="3"/>
        <region id="chorinhoReg" left="2.5%" top="91.7%" width="11.7%" height="6.51%" zIndex="3"/>
        <region id="rockReg" left="25%" top="91.7%" width="11.7%" height="6.51%" zIndex="3"/>
        <region id="technoReg" left="47.5%" top="91.7%" width="11.7%" height="6.51%" zIndex="3"/>
        <region id="cartoonReg" left="70%" top="91.7%" width="11.7%" height="6.51%" zIndex="3"/>
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
      <descriptor id="intDesc" region="intReg"/>
      <descriptor id="chorinhoDesc" region="chorinhoReg" focusIndex="2" moveRight="3" moveLeft="5"/>
      <descriptor id="rockDesc" region="rockReg" focusIndex="3" moveRight="4" moveLeft="2"/>
      <descriptor id="technoDesc" region="technoReg" focusIndex="4" moveRight="5" moveLeft="3"/>
      <descriptor id="cartoonDesc" region="cartoonReg" focusIndex="5" moveRight="2" moveLeft="4"/>
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
      <causalConnector id="onBeginStart_delay">
        <connectorParam name="delay"/>
        <simpleCondition role="onBegin"/>
        <simpleAction role="start" delay="\$delay" max="unbounded" qualifier="par"/>
      </causalConnector>
      <causalConnector id="onSelectionSet_varStop">
        <connectorParam name="var"/>
        <simpleCondition role="onSelection"/>
        <compoundAction operator="seq">
          <simpleAction role="set" value="\$var"/>
          <simpleAction role="stop"/>
        </compoundAction>
      </causalConnector>
      <causalConnector id="onSelection_orSet_varStopStart">
        <connectorParam name="var"/>
        <compoundCondition operator="or">
          <simpleCondition role="onSelection"/>
        </compoundCondition>
        <compoundAction operator="seq">
          <simpleAction role="set" value="\$var"/>
          <simpleAction role="stop"/>
          <simpleAction role="start"/>
        </compoundAction>
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
      <area id="segCred" end="64s"/>
    </media>
    <media id="drible" src="media/drible.mp4" descriptor="dribleDesc"/>
    <media id="photo" src="media/photo.png" descriptor="photoDesc">
      <property name="top"/>
    </media>
    <context id="menu">
      <port id="pChoro" component="choro"/>
      <port id="pChorinho" component="imgChorinho"/>
      <port id="pRock" component="imgRock"/>
      <port id="pTechno" component="imgTechno"/>
      <port id="pCartoon" component="imgCartoon"/>
      <media id="imgChorinho" src="media/chorinho.png" descriptor="chorinhoDesc"/>
      <media id="imgRock" src="media/rock.png" descriptor="rockDesc"/>
      <media id="imgTechno" src="media/techno.png" descriptor="technoDesc"/>
      <media id="imgCartoon" src="media/cartoon.png" descriptor="cartoonDesc"/>
      <media id="choro" src="media/choro.mp4" descriptor="audioDesc">
        <property name="soundLevel" value="1"/>
      </media>
      <switch id="musics">
        <bindRule constituent="rock" rule="rRock"/>
        <bindRule constituent="techno" rule="rTechno"/>
        <bindRule constituent="cartoon" rule="rCartoon"/>
        <media id="rock" src="media/rock.mp4"/>
        <media id="techno" src="media/techno.mp4"/>
        <media id="cartoon" src="media/cartoon.mp4"/>
      </switch>
      <link id="lChoro" xconnector="onSelectionSet_varStop">
        <bind role="onSelection" component="imgChorinho"/>
        <bind role="set" component="choro" interface="soundLevel">
          <bindParam name="var" value="1"/>
        </bind>
        <bind role="stop" component="musics"/>
      </link>
      <link id="lOthers" xconnector="onSelection_orSet_varStopStart">
        <bind role="onSelection" component="imgRock"/>
        <bind role="onSelection" component="imgTechno"/>
        <bind role="onSelection" component="imgCartoon"/>
        <bind role="set" component="choro" interface="soundLevel">
          <bindParam name="var" value="0"/>
        </bind>
        <bind role="stop" component="musics"/>
        <bind role="start" component="musics"/>
      </link>
    </context>
    <link id="lMusic" xconnector="onBeginStart_delay">
      <bind role="onBegin" component="animation"/>
      <bind role="start" component="background">
        <bindParam name="delay" value="5s"/>
      </bind>
      <bind role="start" component="menu">
        <bindParam name="delay" value="5s"/>
      </bind>
    </link>
  </body>
</ncl>''';

    test('NCLDocument parses and runs menu configuration successfully', () {
      final doc = NCLDocument.fromXML(xml);
      doc.start();
      doc.tick(5000);
      final active = doc.getActiveMedia().map((m) => m.id).toList();
      expect(active, contains('imgChorinho'));
      expect(active, contains('imgRock'));
    });
  });
}
