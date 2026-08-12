<ncl>
  <head>
    <regionBase>
      <region id="rgTopLeft" left="0%" top="0%" width="50%" height="50%"/>
      <region id="rgTopRight" left="50%" top="0%" width="50%" height="50%"/>
      <region id="rgBottomLeft" left="0%" top="50%" width="50%" height="50%"/>
      <region id="rgBottomRight" left="50%" top="50%" width="50%" height="50%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dTopLeft" region="rgTopLeft"/>
      <descriptor id="dTopRight" region="rgTopRight"/>
      <descriptor id="dBottomLeft" region="rgBottomLeft"/>
      <descriptor id="dBottomRight" region="rgBottomRight"/>
    </descriptorBase>
  </head>
  <body>
    <port id="p1" component="v1"/>
    <port id="p2" component="v2"/>
    <port id="p3" component="v3"/>
    <port id="p4" component="v4"/>

    <media id="v1" src="primeiro-joao/media/animGar.mp4" descriptor="dTopLeft"/>
    <media id="v2" src="primeiro-joao/media/animGar.mp4" descriptor="dTopRight"/>
    <media id="v3" src="primeiro-joao/media/animGar.mp4" descriptor="dBottomLeft"/>
    <media id="v4" src="primeiro-joao/media/animGar.mp4" descriptor="dBottomRight"/>
  </body>
</ncl>
