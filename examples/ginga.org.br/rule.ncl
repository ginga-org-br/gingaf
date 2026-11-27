<ncl>
  <head>
    <ruleBase>
      <rule id="rPt" var="system.language" comparator="eq" value="pt"/>
    </ruleBase>
  </head>
  <body>
    <port id="p0" component="swBox"/>
    <switch id="swBox">
      <bindRule constituent="ptBox" rule="rPt"/>
      <defaultComponent component="fallbackBox"/>
      <media id="ptBox">
        <property name="background" value="green"/>
        <property name="bounds" value="20%,20%,60%,60%"/>
      </media>
      <media id="fallbackBox">
        <property name="background" value="blue"/>
        <property name="bounds" value="20%,20%,60%,60%"/>
      </media>
    </switch>
  </body>
</ncl>
