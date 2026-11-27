<ncl>
  <head>
    <ruleBase>
      <rule id="rEn" var="system.language" comparator="eq" value="en"/>
    </ruleBase>
  </head>
  <body>
    <port id="p0" component="swLogo" interface="spEntry"/>
    <switch id="swLogo">
      <switchPort id="spEntry">
        <mapping component="enLogo"/>
        <mapping component="defaultLogo"/>
      </switchPort>
      <bindRule constituent="enLogo" rule="rEn"/>
      <defaultComponent component="defaultLogo"/>
      <media id="enLogo" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png"/>
      <media id="defaultLogo" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png"/>
    </switch>
  </body>
</ncl>
