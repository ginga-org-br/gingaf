<ncl>
  <head>
    <ruleBase>
      <rule id="rEn" var="system.language" comparator="eq" value="en"/>
    </ruleBase>
  </head>
  <body>
    <port id="p0" component="swBox" interface="spBox"/>
    <switch id="swBox">
      <switchPort id="spBox">
        <mapping component="boxEn"/>
        <mapping component="boxDefault"/>
      </switchPort>
      <bindRule constituent="boxEn" rule="rEn"/>
      <defaultComponent component="boxDefault"/>
      <media id="boxEn">
        <property name="background" value="green"/>
        <property name="bounds" value="20%,20%,60%,60%"/>
      </media>
      <media id="boxDefault">
        <property name="background" value="blue"/>
        <property name="bounds" value="20%,20%,60%,60%"/>
      </media>
    </switch>
  </body>
</ncl>
