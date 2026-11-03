<ncl id="sportsApp" xmlns="http://www.ncl.org.br/NCL3.0/EDTV">
<head>
  <regionBase>
    <region id="videoPlane" left="0%" top="0%" width="72%" height="80%" zIndex="1" />
    <region id="telemetryRail" right="0%" top="0%" width="28%" height="100%" rows="5" scroll="vertical" zIndex="2" />
    <region id="cameraBar" left="0%" bottom="0%" width="72%" height="20%" columns="4" scroll="horizontal" zIndex="2" />
  </regionBase>
  <descriptorBase>
    <descriptor id="vidDesc" region="videoPlane" />
    <descriptor id="statDesc" region="telemetryRail" />
    <descriptor id="camDesc" region="cameraBar" focusBorderColor="white" focusBorderWidth="2" />
  </descriptorBase>
  <connectorBase>
    <causalConnector id="onSelectionStart">
      <simpleCondition role="onSelection" />
      <simpleAction role="start" />
    </causalConnector>
  </connectorBase>
</head>
<body>
  <port id="pSports" component="sportsCtx" />
  <media id="settings" type="application/x-ginga-settings">
    <property name="service.currentKeyMaster" value="sportsCtx" />
  </media>
  <context id="sportsCtx" data-binding="sports_overlay.lua" updatePolicy="3s">
    <port id="pVid" component="mainMatch" />
    <port id="pStat" component="statItem" />
    <port id="pCam" component="camThumbnail" />
    <media id="mainMatch" src="{cameras[column].video}" descriptor="vidDesc" type="video/mp4" />
    <media id="statItem" src="data:text/plain,{stats[row].value}" descriptor="statDesc" type="text/plain" />
    <media id="camThumbnail" src="{cameras[column].preview}" descriptor="camDesc" type="image/png" />
    <link id="lnSelect" xconnector="onSelectionStart">
      <bind role="onSelection" component="camThumbnail" />
      <bind role="start" component="mainMatch" />
    </link>
  </context>
</body>
</ncl>
