<ncl>
  <body>
    <port id="p0" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4">
      <area id="seg1" begin="1s" end="3s"/>
    </media>
    <media id="badge">
      <property name="background" value="green"/>
      <property name="bounds" value="5%,75%,25%,15%"/>
    </media>
    <link>
      <bind role="onBegin" component="video" interface="seg1"/>
      <bind role="start" component="badge"/>
    </link>
  </body>
</ncl>
