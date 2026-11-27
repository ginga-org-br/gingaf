<ncl>
  <head>
    <ruleBase>
      <rule id="rNever" var="system.language" comparator="eq" value="xx"/>
    </ruleBase>
  </head>
  <body>
    <port id="p0" component="swLogo"/>
    <switch id="swLogo">
      <bindRule constituent="altLogo" rule="rNever"/>
      <defaultComponent component="fallbackLogo"/>
      <media id="altLogo" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png"/>
      <media id="fallbackLogo" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png"/>
    </switch>
  </body>
</ncl>
