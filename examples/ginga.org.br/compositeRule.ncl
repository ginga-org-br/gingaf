<ncl>
  <head>
    <ruleBase>
      <compositeRule id="enWideRule" operator="and">
        <rule id="rLang" var="system.language" comparator="eq" value="en"/>
        <rule id="rScreen" var="system.screenSize" comparator="ne" value="0,0"/>
      </compositeRule>
    </ruleBase>
  </head>
  <body>
    <port id="p0" component="swLogo"/>
    <switch id="swLogo">
      <bindRule constituent="enLogo" rule="enWideRule"/>
      <defaultComponent component="defaultLogo"/>
      <media id="enLogo" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png"/>
      <media id="defaultLogo" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png"/>
    </switch>
  </body>
</ncl>
