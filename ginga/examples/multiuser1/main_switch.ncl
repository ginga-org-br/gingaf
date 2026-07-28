<ncl id="multiUserSwitchDoc">
  <head>
    <regionBase>
      <region id="rgAd" left="75%" top="75%" width="20%" height="20%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dAd" region="rgAd"/>
    </descriptorBase>
    <userBase>
      <userProfile id="pAdult" src="adult_query.json" max="1"/>
    </userBase>
    <ruleBase>
      <rule id="rMale" user="pAdult" var="gender" comparator="eq" value="male"/>
    </ruleBase>
  </head>
  <body>
    <settings id="uSettings" type="application/x-ncl-user-settings" user="pAdult">
      <property name="gender"/>
    </settings>
    <port id="pMain" component="swAd"/>
    <switch id="swAd">
      <bindRule rule="rMale" constituent="mMaleAd"/>
      <defaultComponent component="mGeneralAd"/>
      <media id="mMaleAd" src="ad_male.png" descriptor="dAd"/>
      <media id="mGeneralAd" src="ad_general.png" descriptor="dAd"/>
    </switch>
  </body>
</ncl>
