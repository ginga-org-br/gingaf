<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="focusNavEx" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="backgroundReg" width="100%" height="100%" zIndex="1"/>
      <region id="btn1Reg" left="10%" top="40%" width="16%" height="20%" zIndex="2"/>
      <region id="btn2Reg" left="32%" top="40%" width="16%" height="20%" zIndex="2"/>
      <region id="btn3Reg" left="54%" top="40%" width="16%" height="20%" zIndex="2"/>
      <region id="btn4Reg" left="76%" top="40%" width="16%" height="20%" zIndex="2"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="backgroundDesc" region="backgroundReg"/>
      <descriptor id="btn1Desc" region="btn1Reg" focusIndex="1" moveRight="2" moveLeft="4" focusBorderColor="yellow" focusBorderWidth="3"/>
      <descriptor id="btn2Desc" region="btn2Reg" focusIndex="2" moveRight="3" moveLeft="1" focusBorderColor="yellow" focusBorderWidth="3"/>
      <descriptor id="btn3Desc" region="btn3Reg" focusIndex="3" moveRight="4" moveLeft="2" focusBorderColor="yellow" focusBorderWidth="3"/>
      <descriptor id="btn4Desc" region="btn4Reg" focusIndex="4" moveRight="1" moveLeft="3" focusBorderColor="yellow" focusBorderWidth="3"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onSelectionSet">
        <connectorParam name="var"/>
        <simpleCondition role="onSelection"/>
        <simpleAction role="set" value="$var" max="unbounded" qualifier="par"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="pBg" component="bgApp"/>
    <port id="pBtn1" component="btn1"/>
    <port id="pBtn2" component="btn2"/>
    <port id="pBtn3" component="btn3"/>
    <port id="pBtn4" component="btn4"/>

    <media id="bgApp" descriptor="backgroundDesc">
      <property name="background" value="#121212"/>
    </media>

    <media id="btn1" descriptor="btn1Desc">
      <property name="background" value="green"/>
    </media>
    <media id="btn2" descriptor="btn2Desc">
      <property name="background" value="green"/>
    </media>
    <media id="btn3" descriptor="btn3Desc">
      <property name="background" value="green"/>
    </media>
    <media id="btn4" descriptor="btn4Desc">
      <property name="background" value="green"/>
    </media>

    <link id="lSelect1" xconnector="onSelectionSet">
      <bind role="onSelection" component="btn1"/>
      <bind role="set" component="btn1" interface="background">
        <bindParam name="var" value="red"/>
      </bind>
      <bind role="set" component="btn2" interface="background">
        <bindParam name="var" value="green"/>
      </bind>
      <bind role="set" component="btn3" interface="background">
        <bindParam name="var" value="green"/>
      </bind>
      <bind role="set" component="btn4" interface="background">
        <bindParam name="var" value="green"/>
      </bind>
    </link>
    <link id="lSelect2" xconnector="onSelectionSet">
      <bind role="onSelection" component="btn2"/>
      <bind role="set" component="btn1" interface="background">
        <bindParam name="var" value="green"/>
      </bind>
      <bind role="set" component="btn2" interface="background">
        <bindParam name="var" value="red"/>
      </bind>
      <bind role="set" component="btn3" interface="background">
        <bindParam name="var" value="green"/>
      </bind>
      <bind role="set" component="btn4" interface="background">
        <bindParam name="var" value="green"/>
      </bind>
    </link>
    <link id="lSelect3" xconnector="onSelectionSet">
      <bind role="onSelection" component="btn3"/>
      <bind role="set" component="btn1" interface="background">
        <bindParam name="var" value="green"/>
      </bind>
      <bind role="set" component="btn2" interface="background">
        <bindParam name="var" value="green"/>
      </bind>
      <bind role="set" component="btn3" interface="background">
        <bindParam name="var" value="red"/>
      </bind>
      <bind role="set" component="btn4" interface="background">
        <bindParam name="var" value="green"/>
      </bind>
    </link>
    <link id="lSelect4" xconnector="onSelectionSet">
      <bind role="onSelection" component="btn4"/>
      <bind role="set" component="btn1" interface="background">
        <bindParam name="var" value="green"/>
      </bind>
      <bind role="set" component="btn2" interface="background">
        <bindParam name="var" value="green"/>
      </bind>
      <bind role="set" component="btn3" interface="background">
        <bindParam name="var" value="green"/>
      </bind>
      <bind role="set" component="btn4" interface="background">
        <bindParam name="var" value="red"/>
      </bind>
    </link>
  </body>
</ncl>
