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
    <port id="p0" component="logo"/>
    <media id="logo" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png"/>
    <media id="bar">
      <property name="background" value="green"/>
      <property name="bounds" value="0%,85%,100%,15%"/>
    </media>
    <link xconnector="onBeginStart">
      <bind role="onBegin" component="logo"/>
      <bind role="start" component="bar"/>
    </link>
  </body>
</ncl>
