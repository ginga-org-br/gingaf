<ncl>
  <head>
    <ruleBase>
      <rule id="rEn" var="system.language" comparator="eq" value="en"/>
    </ruleBase>
  </head>
  <body>
    <port id="p0" component="swBanner"/>
    <switch id="swBanner">
      <bindRule constituent="enBanner" rule="rEn"/>
      <defaultComponent component="defaultBanner"/>
      <media id="enBanner" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png"/>
      <media id="defaultBanner" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png"/>
    </switch>
  </body>
</ncl>
