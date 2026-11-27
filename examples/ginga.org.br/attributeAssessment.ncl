<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onBeginCheckAttrStart">
        <compoundCondition operator="and">
          <simpleCondition role="onBegin"/>
          <assessmentStatement comparator="eq">
            <attributeAssessment role="attState" eventType="attribution" attributeType="nodeProperty"/>
            <valueAssessment value="on"/>
          </assessmentStatement>
        </compoundCondition>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p0" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4">
      <property name="mode" value="on"/>
    </media>
    <media id="badge">
      <property name="background" value="blue"/>
      <property name="bounds" value="5%,75%,20%,20%"/>
    </media>
    <link xconnector="onBeginCheckAttrStart">
      <bind role="onBegin" component="video"/>
      <bind role="attState" component="video" interface="mode"/>
      <bind role="start" component="badge"/>
    </link>
  </body>
</ncl>
