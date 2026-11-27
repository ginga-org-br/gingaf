<ncl>
  <head>
    <transitionBase>
      <transition id="tFade" type="fade" dur="1s"/>
    </transitionBase>
    <regionBase>
      <region id="rgMain" left="20%" top="20%" width="60%" height="60%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dMain" region="rgMain" transIn="tFade"/>
    </descriptorBase>
  </head>
  <body>
    <port id="p0" component="logo"/>
    <media id="logo" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png" descriptor="dMain"/>
  </body>
</ncl>
