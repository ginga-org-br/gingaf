<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onBeginStartAndSet">
        <simpleCondition role="onBegin"/>
        <compoundAction operator="par">
          <simpleAction role="start"/>
          <simpleAction role="set" value="true"/>
        </compoundAction>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p0" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4">
      <property name="active"/>
    </media>
    <media id="badge">
      <property name="background" value="yellow"/>
      <property name="bounds" value="10%,80%,80%,12%"/>
    </media>
    <link xconnector="onBeginStartAndSet">
      <bind role="onBegin" component="video"/>
      <bind role="start" component="badge"/>
      <bind role="set" component="video" interface="active"/>
    </link>
  </body>
</ncl>
