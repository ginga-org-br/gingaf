<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="embHtml"
  xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="formReg" left="20%" top="10%" width="60%" height="80%" zIndex="0"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="formDesc" region="formReg"/>
    </descriptorBase>
  </head>
  <body>
    <port id="entry" component="htmlForm"/>
    <media id="htmlForm" src="current_service.html" descriptor="formDesc"/>
  </body>
</ncl>
