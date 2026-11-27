<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onBeginIfReadyStart">
        <compoundCondition operator="and">
          <simpleCondition role="onBegin"/>
          <assessmentStatement comparator="eq">
            <attributeAssessment role="att" eventType="attribution" attributeType="nodeProperty"/>
            <valueAssessment value="ready"/>
          </assessmentStatement>
        </compoundCondition>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p0" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4">
      <property name="status" value="ready"/>
    </media>
    <media id="badge">
      <property name="background" value="green"/>
      <property name="bounds" value="75%,75%,20%,20%"/>
    </media>
    <link xconnector="onBeginIfReadyStart">
      <bind role="onBegin" component="video"/>
      <bind role="att" component="video" interface="status"/>
      <bind role="start" component="badge"/>
    </link>
  </body>
</ncl>
