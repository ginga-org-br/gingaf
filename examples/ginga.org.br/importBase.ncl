<ncl>
  <head>
    <connectorBase>
      <importBase alias="conn" documentURI="connectorBase.ncl"/>
    </connectorBase>
  </head>
  <body>
    <port id="p0" component="logo"/>
    <media id="logo" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png"/>
    <media id="bar">
      <property name="background" value="teal"/>
      <property name="bounds" value="0%,85%,100%,15%"/>
    </media>
    <link xconnector="conn#onBeginStart">
      <bind role="onBegin" component="logo"/>
      <bind role="start" component="bar"/>
    </link>
  </body>
</ncl>
