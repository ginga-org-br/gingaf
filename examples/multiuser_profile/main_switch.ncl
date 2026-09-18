<ncl id="multiUserSwitchDoc">
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
      <causalConnector id="onBeginStart">
        <simpleCondition role="onBegin"/>
        <simpleAction role="start"/>
      </causalConnector>
      <causalConnector id="onBeginSet">
        <connectorParam name="var"/>
        <simpleCondition role="onBegin"/>
        <simpleAction role="set" value="$var" max="unbounded" qualifier="par"/>
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
    <media  id="uSettings" type="application/x-ncl-user-settings" user="pAdult">
      <property name="id"/>
      <property name="name"/>
      <property name="gender"/>
      <property name="age"/>
    </media>
    <port id="pMain" component="mVideo"/>
    <port id="pTop" component="mUserLua"/>
    <media id="mUserLua" src="user_info.lua" descriptor="dTop">
      <property name="userId"/>
      <property name="userName"/>
      <property name="userGender"/>
      <property name="userAge"/>
    </media>
    <media id="mVideo" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4">
      <area id="aSec4" begin="4s"/>
    </media>
    <switch id="swAd">
      <bindRule rule="rMale" constituent="mMaleAd"/>
      <defaultComponent component="mGeneralAd"/>
      <media id="mMaleAd" src="ad_male.png" descriptor="dAd"/>
      <media id="mGeneralAd" src="ad_general.png" descriptor="dAd"/>
    </switch>
    <link xconnector="onBeginSet">
      <bind role="onBegin" component="mVideo"/>
      <bind role="get" component="uSettings" interface="id"/>
      <bind role="get" component="uSettings" interface="name"/>
      <bind role="get" component="uSettings" interface="gender"/>
      <bind role="get" component="uSettings" interface="age"/>
      <bind role="set" component="mUserLua" interface="userId">
        <bindParam name="var" value="$get"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userName">
        <bindParam name="var" value="$get"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userGender">
        <bindParam name="var" value="$get"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userAge">
        <bindParam name="var" value="$get"/>
      </bind>
    </link>
    <link xconnector="onBeginStart">
      <bind role="onBegin" component="mVideo" interface="aSec4"/>
      <bind role="start" component="swAd"/>
    </link>
  </body>
</ncl>
