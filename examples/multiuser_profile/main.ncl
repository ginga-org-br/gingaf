<ncl id="multiUserDoc">
  <head>
    <regionBase>
      <region id="rgTop" left="5%" top="3%" width="90%" height="12%" zIndex="10"/>
      <region id="rgAd" left="75%" top="75%" width="20%" height="20%" zIndex="5"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dTop" region="rgTop"/>
      <descriptor id="dAd" region="rgAd"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onBeginSet">
        <connectorParam name="var"/>
        <simpleCondition role="onBegin"/>
        <simpleAction role="set" value="$var" max="unbounded" qualifier="par"/>
      </causalConnector>
      <causalConnector id="onEndAttributionSet">
        <connectorParam name="var"/>
        <simpleCondition role="onEndAttribution"/>
        <simpleAction role="set" value="$var" max="unbounded" qualifier="par"/>
      </causalConnector>
      <causalConnector id="onEndAttributionStop">
        <simpleCondition role="onEndAttribution"/>
        <simpleAction role="stop" max="unbounded" qualifier="par"/>
      </causalConnector>
      <causalConnector id="onBeginOrAttributionTestVarStart">
        <connectorParam name="var"/>
        <connectorParam name="value"/>
        <compoundCondition operator="and">
          <compoundCondition operator="or">
            <simpleCondition role="onBegin"/>
            <simpleCondition role="onEndAttribution"/>
          </compoundCondition>
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
  <body id="body">
    <media id="uSettings" type="application/x-ncl-user-settings" user="currentUser">
      <property name="id"/>
      <property name="name"/>
      <property name="gender"/>
      <property name="age"/>
    </media>
    <media id="uAdult" type="application/x-ncl-user-settings" user="pAdult">
      <property name="gender"/>
    </media>
    <port id="pMain" component="mVideo"/>
    <port id="pTop" component="mUserLua"/>
    <media id="mUserLua" src="user_info.lua" descriptor="dTop">
      <property name="userId"/>
      <property name="userName"/>
      <property name="userGender"/>
      <property name="userAge"/>
    </media>
    <media id="mVideo" src="sbtvd://"/>
    <media id="mMaleAd" src="ad_male.png" descriptor="dAd"/>
    <media id="mFemaleAd" src="ad_general.png" descriptor="dAd"/>
    <link xconnector="onBeginSet">
      <bind role="onBegin" component="mVideo"/>
      <bind role="get1" component="uSettings" interface="id"/>
      <bind role="get2" component="uSettings" interface="name"/>
      <bind role="get3" component="uSettings" interface="gender"/>
      <bind role="get4" component="uSettings" interface="age"/>
      <bind role="set" component="mUserLua" interface="userId">
        <bindParam name="var" value="$get1"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userName">
        <bindParam name="var" value="$get2"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userGender">
        <bindParam name="var" value="$get3"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userAge">
        <bindParam name="var" value="$get4"/>
      </bind>
    </link>
    <link xconnector="onEndAttributionSet">
      <bind role="onEndAttribution" component="uSettings" interface="id"/>
      <bind role="get" component="uSettings" interface="id"/>
      <bind role="get" component="uSettings" interface="name"/>
      <bind role="get" component="uSettings" interface="gender"/>
      <bind role="get" component="uSettings" interface="age"/>
      <bind role="set" component="mUserLua" interface="userGender">
        <bindParam name="var" value="$get"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userName">
        <bindParam name="var" value="$get"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userAge">
        <bindParam name="var" value="$get"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userId">
        <bindParam name="var" value="$get"/>
      </bind>
    </link>
    <link xconnector="onEndAttributionStop">
      <bind role="onEndAttribution" component="uSettings" interface="id"/>
      <bind role="stop" component="mMaleAd"/>
      <bind role="stop" component="mFemaleAd"/>
    </link>
    <link xconnector="onBeginOrAttributionTestVarStart">
      <bind role="onBegin" component="mVideo"/>
      <bind role="onEndAttribution" component="uSettings" interface="id"/>
      <bind role="var" component="uAdult" interface="gender"/>
      <bindParam name="value" value="male"/>
      <bind role="start" component="mMaleAd"/>
    </link>
    <link xconnector="onBeginOrAttributionTestVarStart">
      <bind role="onBegin" component="mVideo"/>
      <bind role="onEndAttribution" component="uSettings" interface="id"/>
      <bind role="var" component="uAdult" interface="gender"/>
      <bindParam name="value" value="female"/>
      <bind role="start" component="mFemaleAd"/>
    </link>
  </body>
</ncl>
