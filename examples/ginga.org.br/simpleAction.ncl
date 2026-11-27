<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onBeginStart">
        <simpleCondition role="onBegin"/>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p0" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4"/>
    <media id="badge">
      <property name="background" value="red"/>
      <property name="bounds" value="75%,5%,20%,20%"/>
    </media>
    <link xconnector="onBeginStart">
      <bind role="onBegin" component="video"/>
      <bind role="start" component="badge"/>
    </link>
  </body>
</ncl>
