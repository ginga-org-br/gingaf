<ncl id="multiUserSwitchDoc">
  <head>
    <regionBase>
      <region id="rgAd" left="75%" top="75%" width="20%" height="20%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dAd" region="rgAd"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onBeginStart">
        <simpleCondition role="onBegin"/>
        <simpleAction role="start"/>
      </causalConnector>
      <causalConnector id="onEndStop">
        <simpleCondition role="onEnd"/>
        <simpleAction role="stop"/>
      </causalConnector>
    </connectorBase>
    <userBase>
      <userProfile id="pAdult" src="adult_query.json" max="1"/>
    </userBase>
    <ruleBase>
      <rule id="rMale" user="pAdult" var="gender" comparator="eq" value="male"/>
    </ruleBase>
  </head>
  <body id="body">
    <settings id="uSettings" type="application/x-ncl-user-settings" user="pAdult">
      <property name="gender"/>
    </settings>
    <port id="pMain" component="mVideo"/>
    <media id="mVideo" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4">
      <area id="aSec2" begin="2s"/>
    </media>
    <switch id="swAd">
      <bindRule rule="rMale" constituent="mMaleAd"/>
      <defaultComponent component="mGeneralAd"/>
      <media id="mMaleAd" src="ad_male.png" descriptor="dAd"/>
      <media id="mGeneralAd" src="ad_general.png" descriptor="dAd"/>
    </switch>
    <link xconnector="onBeginStart">
      <bind role="onBegin" component="mVideo" interface="aSec2"/>
      <bind role="start" component="swAd"/>
    </link>
    <link xconnector="onEndStop">
      <bind role="onEnd" component="mVideo"/>
      <bind role="stop" component="body"/>
    </link>
  </body>
</ncl>
