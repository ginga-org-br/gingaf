<ncl id="multiUserDoc">
  <head>
    <regionBase>
      <region id="rgAd" left="75%" top="75%" width="20%" height="20%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dAd" region="rgAd"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onBeginTestVarStart">
        <compoundCondition operator="and">
          <simpleCondition role="onBegin"/>
          <assessmentStatement comparator="eq">
            <attributeAssessment role="var" attributeType="nodeProperty" eventType="attribution"/>
            <valueAssessment value="$value"/>
          </assessmentStatement>
        </compoundCondition>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
    <userBase>
      <userProfile id="pAdult" src="adult_query.json" max="1"/>
    </userBase>
  </head>
  <body>
    <settings id="uSettings" type="application/x-ncl-user-settings" user="pAdult">
      <property name="gender"/>
    </settings>
    <port id="pMain" component="mVideo"/>
    <media id="mVideo" src="video.mp4">
      <area id="aSec2" begin="2s"/>
    </media>
    <media id="mMaleAd" src="ad_male.png" descriptor="dAd"/>
    <media id="mGeneralAd" src="ad_general.png" descriptor="dAd"/>
    <link xconnector="onBeginTestVarStart">
      <bind role="onBegin" component="mVideo" interface="aSec2"/>
      <bind role="var" component="uSettings" interface="gender"/>
      <bindParam name="value" value="male"/>
      <bind role="start" component="mMaleAd"/>
    </link>
    <link xconnector="onBeginTestVarStart">
      <bind role="onBegin" component="mVideo" interface="aSec2"/>
      <bind role="var" component="uSettings" interface="gender"/>
      <bindParam name="value" value="female"/>
      <bind role="start" component="mGeneralAd"/>
    </link>
  </body>
</ncl>
