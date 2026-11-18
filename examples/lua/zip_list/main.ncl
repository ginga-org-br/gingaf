<ncl id="zip_list">
  <head>
    <regionBase>
      <region id="rgMain" left="5%" top="5%" width="90%" height="90%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dMain" region="rgMain"/>
    </descriptorBase>
  </head>
  <body>
    <port id="pInit" component="luaZip"/>
    <media id="sttgs" type="application/x-ginga-settings">
      <property name="service.currentKeyMaster" value="luaZip"/>
    </media>
    <media id="luaZip" src="main.lua" descriptor="dMain"/>
  </body>
</ncl>
