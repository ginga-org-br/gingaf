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
    <media id="overlay">
      <property name="background" value="blue"/>
      <property name="bounds" value="5%,75%,20%,20%"/>
    </media>
    <link xconnector="onBeginStartDelay">
      <linkParam name="delay" value="1s"/>
      <bind role="onBegin" component="video"/>
      <bind role="start" component="overlay"/>
    </link>
  </body>
</ncl>
