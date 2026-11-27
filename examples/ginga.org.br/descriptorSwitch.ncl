<ncl>
  <head>
    <ruleBase>
      <rule id="rWide" var="system.screenSize" comparator="eq" value="1920,1080"/>
    </ruleBase>
    <regionBase>
      <region id="rgWide" left="10%" top="10%" width="80%" height="80%"/>
      <region id="rgDefault" left="25%" top="25%" width="50%" height="50%"/>
    </regionBase>
    <descriptorBase>
      <descriptorSwitch id="dsLogo">
        <bindRule constituent="dWide" rule="rWide"/>
        <defaultDescriptor descriptor="dDefault"/>
        <descriptor id="dWide" region="rgWide"/>
        <descriptor id="dDefault" region="rgDefault"/>
      </descriptorSwitch>
    </descriptorBase>
  </head>
  <body>
    <port id="p0" component="logo"/>
    <media id="logo" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png" descriptor="dsLogo"/>
  </body>
</ncl>
