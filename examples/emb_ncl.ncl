<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="embHtml"
  xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="formReg" left="20%" top="10%" width="60%" height="80%" zIndex="0"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="nclDesc" region="formReg" focusIndex="1"/>
    </descriptorBase>
  </head>
  <body>
    <port id="entry" component="embNcl"/>
    <media id="embNcl" src="video.ncl" type="text/ncl" descriptor="nclDesc"/>
  </body>
</ncl>
