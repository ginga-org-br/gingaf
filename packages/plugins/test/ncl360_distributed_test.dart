import 'package:flutter_test/flutter_test.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:plugins/ncl360_math.dart';
import 'package:plugins/ncl360_plugin.dart';

void main() {
  group(
      'Multi-Device Tests',
      () {
    const hybrid2dAnd360Ncl = '''
<ncl id="hybrid360">
  <head>
    <regionBase id="rbTv">
      <region id="rgInfo" left="10%" top="70%" width="80%" height="20%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dInfo" region="rgInfo"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onBeginViewStart">
        <simpleCondition role="onBeginView"/>
        <simpleAction role="start"/>
      </causalConnector>
      <causalConnector id="onEndViewStop">
        <simpleCondition role="onEndView"/>
        <simpleAction role="stop"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p0" component="scene360"/>
    <media id="scene360" src="main.ncl360" type="application/x-ncl360">
      <property name="device" value="ncl-360-vr"/>
      <area id="spotConductor" label="conductor"/>
    </media>
    <media id="lhcInfo" src="lhc_info.txt" descriptor="dInfo"/>
    <link xconnector="onBeginViewStart">
      <bind role="onBeginView" component="scene360" interface="spotConductor"/>
      <bind role="start" component="lhcInfo"/>
    </link>
    <link xconnector="onEndViewStop">
      <bind role="onEndView" component="scene360" interface="spotConductor"/>
      <bind role="stop" component="lhcInfo"/>
    </link>
  </body>
</ncl>
''';

    test(
        'resolves ncl-360-vr device class, dispatches NodeMetadata/ActionMetadata, and triggers 2D TV link on gaze TransitionMetadata',
        () async {
      final gingacc = GingaCC();
      final doc = NclDocument.fromContent(
        hybrid2dAnd360Ncl,
        appSrc: 'main.ncl360',
        gingacc: gingacc,
      );

      final remoteClient = RemoteDeviceClient();
      final channel = await remoteClient.openRemoteDeviceChannel(
        deviceClass: 'ncl-360-vr',
        deviceId: 'hmd-quest-01',
      );
      expect(channel.wsPort, inInclusiveRange(45000, 45199));

      final sentToDevice = <Map<String, dynamic>>[];
      channel.onHostMessage.listen(sentToDevice.add);

      final coordinator = Ncl360RemoteCoordinator(
        primaryTvDocument: doc,
        channel: channel,
      );

      doc.start();
      doc.tick(100);

      final sceneMedia = doc.getMediaById('scene360')!;
      expect(doc.getDeviceClassForMedia(sceneMedia), 'ncl-360-vr');
      expect(doc.getSystemVariable('ncl-360-vr.devNumber'), '1');
      expect(doc.getSystemVariable('ncl-360-vr.screenSize(1)'), '1280, 720');
      expect(sceneMedia.getMainState(), NclStateType.occurring);
      expect(doc.getMediaById('lhcInfo')?.getMainState(),
          NclStateType.sleeping);

      await Future<void>.delayed(Duration.zero);
      expect(
        sentToDevice.any(
            (m) => m['nodeId'] == 'scene360' && m['nodeSrc'] == 'main.ncl360'),
        isTrue,
      );
      expect(
        sentToDevice.any((m) =>
            m['nodeId'] == 'scene360' &&
            m['eventType'] == 'presentation' &&
            m['action'] == 'start'),
        isTrue,
      );

      coordinator.offloadScene(
        sceneNodeId: 'scene360',
        skyboxSrc: 'lhc_360.mp4',
        hotspots: [
          Ncl360Hotspot(
            id: 'spotConductor',
            coordinate: const SphericalCoordinate(
              polar: 0.0,
              azimuthal: 0.0,
              radius: 1.0,
            ),
            label: 'Conductor Biography',
          ),
        ],
      );

      await Future<void>.delayed(Duration.zero);
      expect(coordinator.remoteHotspots.length, 1);
      expect(doc.getMediaById('lhcInfo')?.getMainState(),
          NclStateType.occurring);

      coordinator.updateCompanionGaze(yaw: 160.0, pitch: 0.0, fov: 60.0);
      await Future<void>.delayed(Duration.zero);
      expect(doc.getMediaById('lhcInfo')?.getMainState(),
          NclStateType.sleeping);

      coordinator.updateCompanionGaze(yaw: 0.0, pitch: 0.0, fov: 90.0);
      await Future<void>.delayed(Duration.zero);
      expect(doc.getMediaById('lhcInfo')?.getMainState(),
          NclStateType.occurring);

      await coordinator.dispose();
      await channel.close();
      remoteClient.close();
    });
  });
}
