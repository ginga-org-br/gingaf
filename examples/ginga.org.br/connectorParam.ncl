<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onBeginStartDelay">
        <connectorParam name="delay"/>
        <simpleCondition role="onBegin"/>
        <simpleAction role="start" delay="$delay"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p0" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4"/>
    <media id="badge">
      <property name="background" value="yellow"/>
      <property name="bounds" value="75%,75%,20%,20%"/>
    </media>
    <link xconnector="onBeginStartDelay">
      <bind role="onBegin" component="video"/>
      <bind role="start" component="badge">
        <bindParam name="delay" value="1s"/>
      </bind>
    </link>
  </body>
</ncl>
