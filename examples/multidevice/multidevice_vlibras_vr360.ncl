<ncl id="tv30MultideviceMainScreen">
  <head>
    <regionBase id="rbTv">
      <region id="rgBg" left="0%" top="0%" width="100%" height="100%" zIndex="1"/>
      <region id="rgGuide" left="5%" top="76%" width="90%" height="18%" zIndex="2"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dBg" region="rgBg"/>
      <descriptor id="dGuide" region="rgGuide"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onBeginStart">
        <simpleCondition role="onBegin"/>
        <simpleAction role="start" max="unbounded" qualifier="par"/>
      </causalConnector>
      <causalConnector id="onEndStart">
        <simpleCondition role="onEnd"/>
        <simpleAction role="start" max="unbounded" qualifier="par"/>
      </causalConnector>
      <causalConnector id="onBeginSet">
        <connectorParam name="var"/>
        <simpleCondition role="onBegin"/>
        <simpleAction role="set" value="$var"/>
      </causalConnector>
      <causalConnector id="onBeginOrAttributionSet">
        <connectorParam name="var"/>
        <compoundCondition operator="or">
          <simpleCondition role="onBegin"/>
          <simpleCondition role="onEndAttribution"/>
        </compoundCondition>
        <simpleAction role="set" value="$var" max="unbounded" qualifier="par"/>
      </causalConnector>
      <causalConnector id="onBeginViewStart">
        <simpleCondition role="onBeginView"/>
        <simpleAction role="start"/>
      </causalConnector>
      <causalConnector id="onEndViewStop">
        <simpleCondition role="onEndView"/>
        <simpleAction role="stop"/>
      </causalConnector>
      <causalConnector id="onSelectionStart">
        <simpleCondition role="onSelection"/>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p0" component="luaGuide"/>
    <media id="settings" type="application/x-ginga-settings">
      <property name="ncl-360-vr.devNumber"/>
      <property name="accessibility.devNumber"/>
    </media>
    <media id="bgVideo" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4" descriptor="dBg"/>
    <media id="luaGuide" src="multidevice_guide.lua" descriptor="dGuide">
      <property name="vrDevNumber"/>
      <property name="accDevNumber"/>
    </media>
    <media id="scene360" type="application/x-ncl360" src="vr360_companion.ncl360">
      <property name="device" value="ncl-360-vr"/>
      <area id="hotspot1" label="info1"/>
    </media>
    <media id="vlibrasStream" type="text/html" src="vlibras_companion.html">
      <property name="device" value="accessibility"/>
      <property name="librasGloss" value="BORBOLETA"/>
    </media>
    <media id="infoOverlay" type="application/x-ginga-settings"/>
    <media id="tvAck" type="application/x-ginga-settings"/>
    <link xconnector="onBeginStart">
      <bind role="onBegin" component="luaGuide"/>
      <bind role="start" component="bgVideo"/>
    </link>
    <link xconnector="onBeginStart">
      <bind role="onBegin" component="bgVideo"/>
      <bind role="start" component="scene360"/>
      <bind role="start" component="vlibrasStream"/>
    </link>
    <link xconnector="onBeginSet">
      <bind role="onBegin" component="bgVideo"/>
      <bind role="set" component="vlibrasStream" interface="librasGloss">
        <bindParam name="var" value="BORBOLETA"/>
      </bind>
    </link>
    <link xconnector="onBeginOrAttributionSet">
      <bind role="onBegin" component="luaGuide"/>
      <bind role="onEndAttribution" component="settings" interface="ncl-360-vr.devNumber"/>
      <bind role="onEndAttribution" component="settings" interface="accessibility.devNumber"/>
      <bind role="getVr" component="settings" interface="ncl-360-vr.devNumber"/>
      <bind role="getAcc" component="settings" interface="accessibility.devNumber"/>
      <bind role="set" component="luaGuide" interface="vrDevNumber">
        <bindParam name="var" value="$getVr"/>
      </bind>
      <bind role="set" component="luaGuide" interface="accDevNumber">
        <bindParam name="var" value="$getAcc"/>
      </bind>
    </link>
    <link xconnector="onEndStart">
      <bind role="onEnd" component="bgVideo"/>
      <bind role="start" component="bgVideo"/>
    </link>
    <link xconnector="onBeginViewStart">
      <bind role="onBeginView" component="scene360" interface="hotspot1"/>
      <bind role="start" component="infoOverlay"/>
    </link>
    <link xconnector="onEndViewStop">
      <bind role="onEndView" component="scene360" interface="hotspot1"/>
      <bind role="stop" component="infoOverlay"/>
    </link>
    <link xconnector="onSelectionStart">
      <bind role="onSelection" component="vlibrasStream"/>
      <bind role="start" component="tvAck"/>
    </link>
  </body>
</ncl>
