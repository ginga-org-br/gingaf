<ncl>
  <head>
    <ruleBase>
      <rule id="rEn" var="system.language" comparator="eq" value="en"/>
    </ruleBase>
  </head>
  <body>
    <port id="p0" component="swCard"/>
    <switch id="swCard">
      <bindRule constituent="enCard" rule="rEn"/>
      <defaultComponent component="defaultCard"/>
      <media id="enCard">
        <property name="background" value="teal"/>
        <property name="bounds" value="25%,25%,50%,50%"/>
      </media>
      <media id="defaultCard">
        <property name="background" value="navy"/>
        <property name="bounds" value="25%,25%,50%,50%"/>
      </media>
    </switch>
  </body>
</ncl>
