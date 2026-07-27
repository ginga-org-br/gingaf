<ncl id="multiUserDoc">
  <head>
    <regionBase>
      <region id="rgAd" left="75%" top="60%" width="20%" height="40%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dAd" region="rgAd"/>
    </descriptorBase>
    <userBase>
      <userProfile id="pAdult" src="adult_query.json"/>
    </userBase>
    <ruleBase>
      <rule id="rAdult" var="age" comparator="gte" value="18"/>
    </ruleBase>
  </head>
  <body>
    <settings id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
      <property name="age"/>
    </settings>
    <port id="pMain" component="swAd"/>
    <switch id="swAd">
      <bindRule rule="rAdult" constituent="mAdultAd"/>
      <defaultComponent component="mGeneralAd"/>
      <media id="mAdultAd" src="ad_adult.png" descriptor="dAd"/>
      <media id="mGeneralAd" src="ad_general.png" descriptor="dAd"/>
    </switch>
  </body>
</ncl>
