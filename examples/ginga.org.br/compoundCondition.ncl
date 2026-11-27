<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onBeginOrEndStart">
        <compoundCondition operator="or">
          <simpleCondition role="onBegin"/>
          <simpleCondition role="onEnd"/>
        </compoundCondition>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p0" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4"/>
    <media id="badge">
      <property name="background" value="purple"/>
      <property name="bounds" value="75%,75%,20%,20%"/>
    </media>
    <link xconnector="onBeginOrEndStart">
      <bind role="onBegin" component="video"/>
      <bind role="onEnd" component="video"/>
      <bind role="start" component="badge"/>
    </link>
  </body>
</ncl>
