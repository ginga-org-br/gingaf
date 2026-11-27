<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onBeginCheckBothStart">
        <compoundCondition operator="and">
          <simpleCondition role="onBegin"/>
          <compoundStatement operator="and">
            <assessmentStatement comparator="eq">
              <attributeAssessment role="attA" eventType="attribution" attributeType="nodeProperty"/>
              <valueAssessment value="ready"/>
            </assessmentStatement>
            <assessmentStatement comparator="eq">
              <attributeAssessment role="attB" eventType="attribution" attributeType="nodeProperty"/>
              <valueAssessment value="on"/>
            </assessmentStatement>
          </compoundStatement>
        </compoundCondition>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p0" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4">
      <property name="status" value="ready"/>
      <property name="mode" value="on"/>
    </media>
    <media id="badge">
      <property name="background" value="green"/>
      <property name="bounds" value="75%,75%,20%,20%"/>
    </media>
    <link xconnector="onBeginCheckBothStart">
      <bind role="onBegin" component="video"/>
      <bind role="attA" component="video" interface="status"/>
      <bind role="attB" component="video" interface="mode"/>
      <bind role="start" component="badge"/>
    </link>
  </body>
</ncl>
