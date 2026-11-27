<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onBeginMatchValueStart">
        <compoundCondition operator="and">
          <simpleCondition role="onBegin"/>
          <assessmentStatement comparator="eq">
            <attributeAssessment role="attVal" eventType="attribution" attributeType="nodeProperty"/>
            <valueAssessment value="visible"/>
          </assessmentStatement>
        </compoundCondition>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p0" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4">
      <property name="flag" value="visible"/>
    </media>
    <media id="badge">
      <property name="background" value="green"/>
      <property name="bounds" value="75%,75%,20%,20%"/>
    </media>
    <link xconnector="onBeginMatchValueStart">
      <bind role="onBegin" component="video"/>
      <bind role="attVal" component="video" interface="flag"/>
      <bind role="start" component="badge"/>
    </link>
  </body>
</ncl>
