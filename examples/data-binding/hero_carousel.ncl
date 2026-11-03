<ncl id="heroApp" xmlns="http://www.ncl.org.br/NCL3.0/EDTV">
<head>
  <regionBase>
    <region id="screen" width="100%" height="100%">
      <region id="hero" top="0%" height="45%" width="100%" zIndex="1" />
      <region id="rails" top="45%" height="55%" width="100%" rows="3" scroll="vertical" zIndex="1">
        <region id="category" height="20%" />
        <region id="movies" height="80%" columns="4" scroll="horizontal" />
      </region>
      <region id="video" top="0%" left="0%" width="100%" height="45%" zIndex="2" />
    </region>
  </regionBase>
  <descriptorBase>
    <descriptor id="heroDesc" region="hero" />
    <descriptor id="titleDesc" region="category" />
    <descriptor id="moviesDesc" region="movies" focusBorderColor="white" focusBorderWidth="2" />
    <descriptor id="videoDesc" region="video" />
  </descriptorBase>
  <connectorBase>
    <causalConnector id="onSelectionStart">
      <simpleCondition role="onSelection" />
      <simpleAction role="start" />
    </causalConnector>
  </connectorBase>
</head>
<body>
  <port id="pCatalog" component="catalog" />
  <media id="settings" type="application/x-ginga-settings">
    <property name="service.currentKeyMaster" value="catalog" />
  </media>
  <context id="catalog" data-binding="hero_carousel.lua">
    <port id="pCat" component="categoryTitle" />
    <port id="pMov" component="movie" />
    <media id="categoryTitle" src="data:text/plain,{category[row]}" descriptor="titleDesc" type="text/plain" />
    <media id="movie" src="{movies[row][column]}" descriptor="moviesDesc" type="image/png" />
    <media id="videoPlayer" src="{video[row][column]}" descriptor="videoDesc" type="video/mp4" />
    <link id="lnSelect" xconnector="onSelectionStart">
      <bind role="onSelection" component="movie" />
      <bind role="start" component="videoPlayer" />
    </link>
  </context>
</body>
</ncl>
