<ncl id="epgApp" xmlns="http://www.ncl.org.br/NCL3.0/EDTV">
<head>
  <regionBase>
    <region id="screen" width="100%" height="100%">
      <region id="pipVideo" top="2%" right="2%" width="25%" height="25%" zIndex="3" />
      <region id="epgContainer" top="0%" left="0%" width="100%" height="100%" zIndex="1">
        <region id="channels" left="0%" top="10%" width="18%" height="90%" rows="6" scroll="vertical" />
        <region id="timeline" left="18%" top="0%" width="82%" height="10%" columns="4" scroll="horizontal" />
        <region id="grid" left="18%" top="10%" width="82%" height="90%" rows="6" columns="4" scroll="both" wrap="false" />
      </region>
    </region>
  </regionBase>
  <descriptorBase>
    <descriptor id="pipDesc" region="pipVideo" />
    <descriptor id="chDesc" region="channels" />
    <descriptor id="progDesc" region="grid" focusBorderColor="white" focusBorderWidth="2" />
    <descriptor id="timeDesc" region="timeline" />
  </descriptorBase>
  <connectorBase>
    <causalConnector id="onSelectionTune">
      <simpleCondition role="onSelection" />
      <simpleAction role="start" />
    </causalConnector>
  </connectorBase>
</head>
<body>
  <port id="pEpg" component="epgContext" />
  <media id="settings" type="application/x-ginga-settings">
    <property name="service.currentKeyMaster" value="epgContext" />
  </media>
  <context id="epgContext" data-binding="epg_grid.lua">
    <port id="pCh" component="chItem" />
    <port id="pProg" component="progItem" />
    <port id="pTime" component="timeSlot" />
    <media id="chItem" src="data:text/plain,{channels[row].name}" descriptor="chDesc" type="text/plain" />
    <media id="progItem" src="data:text/plain,{schedule[row][column].title}" descriptor="progDesc" type="text/plain" />
    <media id="timeSlot" src="data:text/plain,{timeline[column].time}" descriptor="timeDesc" type="text/plain" />
  </context>
</body>
</ncl>
