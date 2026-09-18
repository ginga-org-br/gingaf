<ncl id="multiUserDoc">
  <head>
    <regionBase>
      <region id="rgTop" left="5%" top="3%" width="90%" height="12%" zIndex="10"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dTop" region="rgTop"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onEndStop">
        <simpleCondition role="onEnd"/>
        <simpleAction role="stop"/>
      </causalConnector>
      <causalConnector id="onBeginSet">
        <connectorParam name="var"/>
        <simpleCondition role="onBegin"/>
        <simpleAction role="set" value="$var" max="unbounded" qualifier="par"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body id="body">
    <media id="uSettings" type="application/x-ncl-user-settings" user="currentUser">
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
    <media id="mVideo" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4"/>
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
  </body>
</ncl>
