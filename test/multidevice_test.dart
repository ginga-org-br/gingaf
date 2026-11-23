import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/args.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:plugins/ncl360_math.dart';

void main() {
  group('Standalone Multi-Device Remote Player Tests', () {
    test('parses standalone remote player CLI flag (--remote-device) without URL param',
        () {
      expect(ssdpDefaultPort, 1900);
      expect(
        ssdpSearchTarget,
        'urn:schemas-sbtvd-org:service:TV3.0WebServices:1',
      );

      final parsed = parseArgsCliAndEnv(
        ['--remote-device=ncl-360-vr'],
        {},
      );
      expect(parsed.remoteDevice, 'ncl-360-vr');

      final parsedEnv = parseArgsCliAndEnv(
        [],
        {
          'GINGA_REMOTE_DEVICE': 'accessibility',
        },
      );
      expect(parsedEnv.remoteDevice, 'accessibility');
    });

    test(
        'standalone ncl-360-vr and accessibility VLibras remote players discover main screen via SSDP and co-execute over real CCWS HTTP+WebSocket',
        () async {
      final vrAsset = File('examples/multidevice/vr360_companion.ncl360');
      final vlibrasAsset = File('examples/multidevice/vlibras_companion.html');
      expect(vrAsset.existsSync(), isTrue);
      expect(vlibrasAsset.existsSync(), isTrue);

      final html = vlibrasAsset.readAsStringSync();
      expect(html, contains('https://vlibras.gov.br/app/vlibras-plugin.js'));
      expect(html, contains('VLibras.Widget'));
      expect(html, contains('vw-plugin-wrapper'));
      expect(html, contains('playVlibrasGloss'));
      expect(html, contains("'accessibility'"));
      expect(html, isNot(contains('require(')));
      expect(html, isNot(contains('node_modules')));

      final ssdpListener = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      final testSsdpPort = ssdpListener.port;
      try {
        ssdpListener.joinMulticast(InternetAddress(ssdpMulticastAddress));
      } catch (_) {}
      addTearDown(ssdpListener.close);

      final aliveAnnounce = Completer<String>();
      final byebyeAnnounce = Completer<String>();
      ssdpListener.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = ssdpListener.receive();
        if (dg == null) return;
        final text = utf8.decode(dg.data, allowMalformed: true);
        if (text.startsWith('NOTIFY') &&
            text.contains('NT: $ssdpSearchTarget')) {
          if (text.contains('NTS: ssdp:alive') && !aliveAnnounce.isCompleted) {
            aliveAnnounce.complete(text);
          } else if (text.contains('NTS: ssdp:byebye') &&
              !byebyeAnnounce.isCompleted) {
            byebyeAnnounce.complete(text);
          }
        }
      });

      final mainScreenCc = GingaCC();
      final vrCompanionCc = GingaCC();
      final vlibrasCompanionCc = GingaCC();
      await mainScreenCc.ccws.start(ssdpPort: testSsdpPort);
      addTearDown(() async {
        mainScreenCc.clearRemoteDevices();
        await mainScreenCc.ccws.stop();
      });

      final aliveMsg =
          await aliveAnnounce.future.timeout(const Duration(seconds: 2));
      expect(aliveMsg, contains('NOTIFY * HTTP/1.1'));
      expect(aliveMsg, contains('NT: $ssdpSearchTarget'));
      expect(aliveMsg, contains('NTS: ssdp:alive'));
      expect(
        aliveMsg,
        contains('LOCATION: http://127.0.0.1:${mainScreenCc.ccws.port}/manifest'),
      );
      expect(aliveMsg, contains('CACHE-CONTROL: max-age=1800'));

      final boundSsdpPort = mainScreenCc.ccws.ssdpPort;
      expect(boundSsdpPort, equals(testSsdpPort));
      expect(mainScreenCc.ccws.ssdpServer?.isRunning, isTrue);

      final vrClient = RemoteDeviceClient(
        gingacc: vrCompanionCc,
        deviceClass: 'ncl-360-vr',
        supportedTypes: const ['application/x-ncl360'],
        useSsdpDiscovery: true,
        ssdpPort: boundSsdpPort!,
        screenSize: '2064, 2208',
        screenGraphicSize: '2064, 2208',
      );
      final vlibrasClient = RemoteDeviceClient(
        gingacc: vlibrasCompanionCc,
        deviceClass: 'accessibility',
        supportedTypes: const ['text/html', 'application/x-vlibras-gloss'],
        useSsdpDiscovery: true,
        ssdpPort: boundSsdpPort,
        screenSize: '390, 844',
        screenGraphicSize: '390, 844',
      );
      addTearDown(() async {
        await vrClient.dispose();
        await vlibrasClient.dispose();
      });

      expect(await vrClient.register(), isTrue);
      expect(await vlibrasClient.register(), isTrue);
      expect(
        vrClient.discoveredReceiver?.location,
        'http://127.0.0.1:${mainScreenCc.ccws.port}/manifest',
      );
      expect(
        vrClient.discoveredReceiver?.baseUrl,
        '127.0.0.1:${mainScreenCc.ccws.port}',
      );
      expect(vrClient.discoveredReceiver?.brandName, 'GingaF');
      expect(vrClient.discoveredReceiver?.pairingMethods, 'open');
      expect(
        vlibrasClient.discoveredReceiver?.baseUrl,
        '127.0.0.1:${mainScreenCc.ccws.port}',
      );
      expect(vrClient.wsUrl, startsWith('ws://localhost:45'));
      expect(vlibrasClient.wsUrl, startsWith('ws://localhost:45'));

      final vrNodes = <Map<String, dynamic>>[];
      final vlibrasNodes = <Map<String, dynamic>>[];
      final vlibrasGlosses = <String>[];
      final vrStarted = Completer<void>();
      final vlibrasStarted = Completer<void>();
      final secondGlossArrived = Completer<void>();

      vrClient.onNodeMetadata.listen(vrNodes.add);
      vrClient.onActionMetadata.listen((m) {
        if (m['eventType'] == 'presentation' &&
            m['action'] == 'start' &&
            !vrStarted.isCompleted) {
          vrStarted.complete();
        }
      });

      vlibrasClient.onNodeMetadata.listen((m) {
        vlibrasNodes.add(m);
        final props = m['properties'];
        if (props is List) {
          for (final p in props.whereType<Map>()) {
            if (p['name'] == 'librasGloss') {
              vlibrasGlosses.add(p['value'].toString());
            }
          }
        }
      });
      vlibrasClient.onActionMetadata.listen((m) {
        if (m['eventType'] == 'presentation' &&
            m['action'] == 'start' &&
            !vlibrasStarted.isCompleted) {
          vlibrasStarted.complete();
        } else if (m['eventType'] == 'attribution' &&
            m['action'] == 'set' &&
            m['label'] == 'librasGloss') {
          vlibrasGlosses.add(m['value'].toString());
          if (!secondGlossArrived.isCompleted) {
            secondGlossArrived.complete();
          }
        }
      });

      final mainDoc = await NclDocument.fromSrc(
        'examples/multidevice/multidevice_vlibras_vr360.ncl',
        gingacc: mainScreenCc,
      );
      mainDoc.start();
      mainDoc.tick(100);
      await Future.wait([vrStarted.future, vlibrasStarted.future])
          .timeout(const Duration(seconds: 2));

      expect(mainDoc.getSystemVariable('ncl-360-vr.devNumber'), '1');
      expect(
        mainDoc.getSystemVariable('ncl-360-vr.screenSize(1)'),
        '2064, 2208',
      );
      expect(mainDoc.getSystemVariable('accessibility.devNumber'), '1');
      expect(
        mainDoc.getSystemVariable('accessibility.screenSize(1)'),
        '390, 844',
      );

      expect(
        vrNodes.any(
          (m) =>
              m['nodeId'] == 'scene360' &&
              m['nodeSrc'].toString().endsWith('vr360_companion.ncl360') &&
              m['type'] == 'application/x-ncl360',
        ),
        isTrue,
      );
      expect(
        vlibrasNodes.any(
          (m) =>
              m['nodeId'] == 'vlibrasStream' &&
              m['nodeSrc'].toString().endsWith('vlibras_companion.html') &&
              m['type'] == 'text/html',
        ),
        isTrue,
      );

      mainDoc.tick(2100);
      await secondGlossArrived.future.timeout(const Duration(seconds: 2));
      expect(
        vlibrasGlosses,
        equals([
          'BORBOLETA',
          'BORBOLETA',
        ]),
      );

      vrClient.sendTransitionMetadata(
        nodeId: 'scene360',
        appId: mainDoc.applicationId,
        eventType: 'view',
        transition: 'starts',
        label: 'hotspot1',
      );
      vlibrasClient.sendTransitionMetadata(
        nodeId: 'vlibrasStream',
        appId: mainDoc.applicationId,
        eventType: 'selection',
        transition: 'starts',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        mainDoc.getMediaById('infoOverlay')?.getMainState(),
        NclStateType.occurring,
      );
      expect(
        mainDoc.getMediaById('tvAck')?.getMainState(),
        NclStateType.occurring,
      );

      const hotspotCoord = SphericalCoordinate(
        polar: 0.0,
        azimuthal: 0.0,
        radius: 1.0,
      );
      final vrHostChannel =
          mainScreenCc.getRemoteDeviceChannelsByClass('ncl-360-vr').first;
      final infoOverlayMedia = mainDoc.getMediaById('infoOverlay')!;
      Completer<void>? pendingGaze;
      String? expectedGazeTransition;
      final gazeSub = vrHostChannel.onDeviceMessage.listen((msg) {
        final cue = pendingGaze;
        if (msg['eventType'] == 'view' &&
            msg['label'] == 'hotspot1' &&
            msg['transition'] == expectedGazeTransition &&
            cue != null &&
            !cue.isCompleted) {
          cue.complete();
        }
      });

      const gazeIterations = 30;
      final gazeSw = Stopwatch()..start();
      for (var i = 0; i < gazeIterations; i++) {
        final yaw = i.isEven ? 180.0 : 0.0;
        final inView = hotspotCoord.isInView(
          cameraYaw: yaw,
          cameraPitch: 0.0,
          fov: 90.0,
        );
        final transition = inView ? 'starts' : 'stops';
        expectedGazeTransition = transition;
        final cue = Completer<void>();
        pendingGaze = cue;
        vrClient.sendTransitionMetadata(
          nodeId: 'scene360',
          appId: mainDoc.applicationId,
          eventType: 'view',
          transition: transition,
          label: 'hotspot1',
        );
        await cue.future.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(Duration.zero);
        expect(
          infoOverlayMedia.getMainState(),
          inView ? NclStateType.occurring : NclStateType.sleeping,
        );
      }
      gazeSw.stop();
      await gazeSub.cancel();
      final meanGazeRoundTripMs =
          gazeSw.elapsedMicroseconds / 1000.0 / gazeIterations;
      expect(meanGazeRoundTripMs, lessThan(50.0));

      final vlibrasMedia = mainDoc.getMediaById('vlibrasStream')!;
      Completer<void>? pendingGloss;
      String? expectedGloss;
      final glossSub = vlibrasClient.onActionMetadata.listen((msg) {
        final cue = pendingGloss;
        if (msg['eventType'] == 'attribution' &&
            msg['action'] == 'set' &&
            msg['label'] == 'librasGloss' &&
            msg['value'] == expectedGloss &&
            cue != null &&
            !cue.isCompleted) {
          cue.complete();
        }
      });

      const glossIterations = 20;
      final glossSw = Stopwatch()..start();
      for (var i = 0; i < glossIterations; i++) {
        final cueGloss = 'GLOSA DISTRIBUTED CUE-$i';
        expectedGloss = cueGloss;
        final cue = Completer<void>();
        pendingGloss = cue;
        mainDoc.dispatchPropertyUpdate(
          vlibrasMedia,
          'librasGloss',
          cueGloss,
        );
        await cue.future.timeout(const Duration(seconds: 2));
      }
      glossSw.stop();
      await glossSub.cancel();
      final meanGlossLatencyMs =
          glossSw.elapsedMicroseconds / 1000.0 / glossIterations;
      expect(meanGlossLatencyMs, lessThan(20.0));

      await vrClient.deregister();
      await vlibrasClient.deregister();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        mainDoc.getMediaById('scene360')?.getMainState(),
        NclStateType.sleeping,
      );
      expect(
        mainDoc.getMediaById('vlibrasStream')?.getMainState(),
        NclStateType.sleeping,
      );
      expect(mainDoc.getSystemVariable('ncl-360-vr.devNumber'), '0');
      expect(mainDoc.getSystemVariable('accessibility.devNumber'), '0');

      mainDoc.stop();
      await mainScreenCc.ccws.stop();

      final byebyeMsg =
          await byebyeAnnounce.future.timeout(const Duration(seconds: 2));
      expect(byebyeMsg, contains('NOTIFY * HTTP/1.1'));
      expect(byebyeMsg, contains('NT: $ssdpSearchTarget'));
      expect(byebyeMsg, contains('NTS: ssdp:byebye'));
      expect(byebyeMsg, isNot(contains('LOCATION:')));
    });

    test(
        'dynamic replication (RD00/RD01) and excess explicit class_id(2) sleeping behavior',
        () async {
      final cc = GingaCC();
      final reg1 = cc.registerRemoteDevice(
        deviceClass: 'accessibility',
        supportedTypes: ['text/html'],
        screenSize: '390, 844',
      );
      final reg2 = cc.registerRemoteDevice(
        deviceClass: 'accessibility',
        supportedTypes: ['text/html'],
        screenSize: '820, 1180',
      );
      final ch1 = cc.getRemoteDeviceChannel(reg1['handle'] as String)!;
      final ch2 = cc.getRemoteDeviceChannel(reg2['handle'] as String)!;

      final glosses1 = <String>[];
      final glosses2 = <String>[];
      ch1.onHostMessage.listen((m) {
        if (m['eventType'] == 'attribution' && m['label'] == 'librasGloss') {
          glosses1.add('${m['nodeId']}:${m['value']}');
        }
      });
      ch2.onHostMessage.listen((m) {
        if (m['eventType'] == 'attribution' && m['label'] == 'librasGloss') {
          glosses2.add('${m['nodeId']}:${m['value']}');
        }
      });

      final doc = await NclDocument.fromSrc(
        'examples/multidevice/multidevice_vlibras_vr360.ncl',
        gingacc: cc,
      );
      doc.start();
      doc.tick(100);
      doc.tick(2100);
      await Future<void>.delayed(Duration.zero);

      expect(doc.getSystemVariable('accessibility.devNumber'), '2');
      expect(doc.getSystemVariable('accessibility.screenSize(1)'), '390, 844');
      expect(doc.getSystemVariable('accessibility.screenSize(2)'), '820, 1180');
      expect(doc.getMediaById('vlibrasStream'), isNull);
      expect(doc.getMediaById('vlibrasStreamRD00'), isNotNull);
      expect(doc.getMediaById('vlibrasStreamRD01'), isNotNull);
      expect(
        glosses1,
        contains('vlibrasStreamRD00:BORBOLETA'),
      );
      expect(
        glosses2,
        contains('vlibrasStreamRD01:BORBOLETA'),
      );

      await ch1.close();
      await Future<void>.delayed(Duration.zero);
      expect(
        doc.getMediaById('vlibrasStreamRD00')?.getMainState(),
        NclStateType.sleeping,
      );
      expect(
        doc.getMediaById('vlibrasStreamRD01')?.getMainState(),
        NclStateType.occurring,
      );
      expect(doc.getSystemVariable('accessibility.devNumber'), '1');
      doc.stop();
      cc.clearRemoteDevices();

      const explicitIndexNcl = '''
<ncl id="explicitVlibras">
  <head>
    <connectorBase>
      <causalConnector id="onBeginStart">
        <simpleCondition role="onBegin"/>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="p0" component="vlibras1"/>
    <media id="vlibras1" type="text/html" src="vlibras_companion.html">
      <property name="device" value="accessibility(1)"/>
    </media>
    <media id="vlibras2" type="text/html" src="vlibras_companion.html">
      <property name="device" value="accessibility(2)"/>
    </media>
    <link xconnector="onBeginStart">
      <bind role="onBegin" component="vlibras1"/>
      <bind role="start" component="vlibras2"/>
    </link>
  </body>
</ncl>
''';
      cc.registerRemoteDevice(
        deviceClass: 'accessibility',
        supportedTypes: ['text/html'],
      );
      final explicitDoc = NclDocument.fromContent(
        explicitIndexNcl,
        appSrc: 'explicit_vlibras.ncl',
        gingacc: cc,
      );
      explicitDoc.start();
      explicitDoc.tick(100);
      expect(
        explicitDoc.getMediaById('vlibras1')?.getMainState(),
        NclStateType.occurring,
      );
      expect(
        explicitDoc.getMediaById('vlibras2')?.getMainState(),
        NclStateType.sleeping,
      );
      explicitDoc.stop();
      cc.clearRemoteDevices();
    });
  });
}
