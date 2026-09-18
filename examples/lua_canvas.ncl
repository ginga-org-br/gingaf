<ncl>
  <head>
    <regionBase>
      <region id="rgCanvas" left="10%" top="10%" width="80%" height="80%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dCanvas" region="rgCanvas"/>
    </descriptorBase>
  </head>
  <body>
    <port id="init" component="lua"/>
    <media type="application/x-ginga-settings" id="settings">
      <property name="service.currentKeyMaster" value="lua"/>
    </media>
    <media id="lua" src="lua_canvas.lua" descriptor="dCanvas">
      <property name="background" value="black"/>
    </media>
  </body>
</ncl>
