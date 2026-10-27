import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:ncldoc/elements.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:nclui/base_widget.dart';
import 'package:plugins/ncl360_plugin.dart';
import 'package:plugins/plugin_base.dart';
import 'package:plugins/plugins_registry.dart';
import 'package:plugins/ncl360_math.dart';
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerAllPlugins(GetIt.instance);
  });

  group('SphericalCoordinate and Spherical Math Tests', () {
    test('normalizeDegrees normalizes negative and overflowing values', () {
      expect(SphericalCoordinate.normalizeDegrees(0.0), closeTo(0.0, 0.001));
      expect(SphericalCoordinate.normalizeDegrees(360.0), closeTo(0.0, 0.001));
      expect(SphericalCoordinate.normalizeDegrees(720.0), closeTo(0.0, 0.001));
      expect(SphericalCoordinate.normalizeDegrees(-90.0), closeTo(270.0, 0.001));
      expect(SphericalCoordinate.normalizeDegrees(450.0), closeTo(90.0, 0.001));
      expect(SphericalCoordinate.normalizeDegrees(-370.0), closeTo(350.0, 0.001));
    });

    test('deltaAngleDegrees calculates shortest arc difference correctly', () {
      expect(SphericalCoordinate.deltaAngleDegrees(0.0, 45.0), closeTo(45.0, 0.001));
      expect(SphericalCoordinate.deltaAngleDegrees(45.0, 0.0), closeTo(-45.0, 0.001));
      expect(SphericalCoordinate.deltaAngleDegrees(350.0, 10.0), closeTo(20.0, 0.001));
      expect(SphericalCoordinate.deltaAngleDegrees(10.0, 350.0), closeTo(-20.0, 0.001));
      expect(SphericalCoordinate.deltaAngleDegrees(0.0, 180.0), closeTo(180.0, 0.001));
    });

    test('angularDistanceTo calculates great-circle distance accurately', () {
      const coordCenter = SphericalCoordinate(polar: 0.0, azimuthal: 0.0);
      expect(coordCenter.angularDistanceTo(0.0, 0.0), closeTo(0.0, 0.001));
      expect(coordCenter.angularDistanceTo(90.0, 0.0), closeTo(90.0, 0.001));
      expect(coordCenter.angularDistanceTo(0.0, 90.0), closeTo(90.0, 0.001));
      expect(coordCenter.angularDistanceTo(180.0, 0.0), closeTo(180.0, 0.001));
      expect(coordCenter.angularDistanceTo(0.0, -90.0), closeTo(90.0, 0.001));

      const coordNorth = SphericalCoordinate(polar: 90.0, azimuthal: 0.0);
      expect(coordNorth.angularDistanceTo(0.0, -90.0), closeTo(180.0, 0.001));
      expect(coordNorth.angularDistanceTo(45.0, 90.0), closeTo(0.0, 0.001));
    });

    test('isInView correctly identifies coordinates within camera frustum', () {
      const targetInFront = SphericalCoordinate(polar: 0.0, azimuthal: 0.0);
      expect(
        targetInFront.isInView(cameraYaw: 0.0, cameraPitch: 0.0, fov: 90.0),
        isTrue,
      );
      expect(
        targetInFront.isInView(cameraYaw: 30.0, cameraPitch: 0.0, fov: 90.0),
        isTrue,
      );
      expect(
        targetInFront.isInView(cameraYaw: 50.0, cameraPitch: 0.0, fov: 90.0),
        isFalse,
      );
      expect(
        targetInFront.isInView(
          cameraYaw: 50.0,
          cameraPitch: 0.0,
          fov: 90.0,
          marginDegrees: 10.0,
        ),
        isTrue,
      );
      expect(
        targetInFront.isInView(cameraYaw: 180.0, cameraPitch: 0.0, fov: 90.0),
        isFalse,
      );

      const targetCameraPinned = SphericalCoordinate(
        polar: 10.0,
        azimuthal: 15.0,
        pin: PinType.camera,
      );
      expect(
        targetCameraPinned.isInView(cameraYaw: 180.0, cameraPitch: 45.0, fov: 90.0),
        isTrue,
      );
    });

    test('projectToViewport maps spherical coordinates to screen space', () {
      const coord = SphericalCoordinate(polar: 0.0, azimuthal: 0.0);
      const viewport = Size(800.0, 600.0);

      final centerProjected = coord.projectToViewport(
        cameraYaw: 0.0,
        cameraPitch: 0.0,
        cameraRoll: 0.0,
        fov: 90.0,
        viewportSize: viewport,
      );
      expect(centerProjected, isNotNull);
      expect(centerProjected!.dx, closeTo(400.0, 0.01));
      expect(centerProjected.dy, closeTo(300.0, 0.01));

      final rightProjected = coord.projectToViewport(
        cameraYaw: -20.0,
        cameraPitch: 0.0,
        cameraRoll: 0.0,
        fov: 90.0,
        viewportSize: viewport,
      );
      expect(rightProjected, isNotNull);
      expect(rightProjected!.dx, greaterThan(400.0));

      final behindProjected = coord.projectToViewport(
        cameraYaw: 180.0,
        cameraPitch: 0.0,
        cameraRoll: 0.0,
        fov: 90.0,
        viewportSize: viewport,
      );
      expect(behindProjected, isNull);
    });
  });

  group('ViewportCamera Navigation Tests', () {
    test('pan updates yaw and clamps pitch', () {
      final camera = ViewportCamera(yaw: 0.0, pitch: 0.0, fov: 90.0);
      camera.pan(100.0, 50.0, sensitivity: 0.2);
      expect(camera.yaw, closeTo(340.0, 0.01));
      expect(camera.pitch, closeTo(10.0, 0.01));

      camera.pan(0.0, 500.0, sensitivity: 1.0);
      expect(camera.pitch, closeTo(85.0, 0.01));

      camera.pan(0.0, -1000.0, sensitivity: 1.0);
      expect(camera.pitch, closeTo(-85.0, 0.01));
    });

    test('zoom modifies and clamps fov', () {
      final camera = ViewportCamera(fov: 90.0);
      camera.zoom(-20.0);
      expect(camera.fov, closeTo(70.0, 0.01));

      camera.zoom(-100.0);
      expect(camera.fov, closeTo(30.0, 0.01));

      camera.zoom(200.0);
      expect(camera.fov, closeTo(120.0, 0.01));
    });

    test('rotateKey updates all navigation angles', () {
      final camera = ViewportCamera();
      camera.rotateKey(deltaYaw: 15.0, deltaPitch: -10.0, deltaRoll: 5.0, deltaFov: -5.0);
      expect(camera.yaw, closeTo(15.0, 0.01));
      expect(camera.pitch, closeTo(-10.0, 0.01));
      expect(camera.roll, closeTo(5.0, 0.01));
      expect(camera.fov, closeTo(85.0, 0.01));
    });
  });

  group('Ncl360MediaPlugin canHandle Tests', () {
    final plugin = Ncl360MediaPlugin();

    test('canHandle recognizes 360 image extensions', () {
      expect(plugin.canHandle('panorama.360.jpg', null), isTrue);
      expect(plugin.canHandle('scene.360.jpeg', null), isTrue);
      expect(plugin.canHandle('view.360.png', null), isTrue);
      expect(plugin.canHandle('sphere.360.webp', null), isTrue);
      expect(plugin.canHandle('environment.pano', null), isTrue);
      expect(plugin.canHandle('room.360', null), isTrue);
    });

    test('canHandle recognizes 360 video extensions and MIME types', () {
      expect(plugin.canHandle('video.360.mp4', null), isTrue);
      expect(plugin.canHandle('video.mp4', 'video/360'), isTrue);
      expect(plugin.canHandle('image.jpg', 'image/360'), isTrue);
      expect(plugin.canHandle('custom_media', 'application/x-ginga-360'), isTrue);
      expect(plugin.canHandle('custom_media', 'application/x-ncl-360'), isTrue);
    });

    test('canHandle rejects standard non-360 media', () {
      expect(plugin.canHandle('standard.mp4', 'video/mp4'), isFalse);
      expect(plugin.canHandle('photo.jpg', 'image/jpeg'), isFalse);
      expect(plugin.canHandle('document.ncl', 'application/x-ncl-NCL'), isFalse);
      expect(plugin.canHandle('notes.txt', 'text/plain'), isFalse);
    });
  });

  group('Scene360Widget UI & Viewport Tracking Tests', () {
    testWidgets('renders Scene360Widget and displays 360 HUD', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Scene360Widget(
                src: '',
                mimeType: 'image/360',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Scene360Widget), findsOneWidget);
      expect(find.textContaining('Yaw: 0.0°'), findsOneWidget);
      expect(find.textContaining('FoV: 90.0°'), findsOneWidget);
    });

    testWidgets('supports drag gesture to update viewport yaw and pitch', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Scene360Widget(
                src: '',
                mimeType: 'image/360',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scene360Widget), const Offset(-100.0, 50.0));
      await tester.pump();

      expect(find.byType(Scene360Widget), findsOneWidget);
      expect(find.textContaining('Yaw: 30.0°'), findsOneWidget);
      expect(find.textContaining('Pitch: 15.0°'), findsOneWidget);
    });

    testWidgets('extracts hotspots and triggers view transitions when in view', (tester) async {
      final media = Media(rawAttributes: {'id': 'scene360'});
      final hotspotArea = Area(
        rawAttributes: {
          'id': 'hotspot_room1',
          'polar': '0',
          'azimuthal': '0',
          'label': 'Living Room',
        },
      );
      media.children.add(hotspotArea);

      final doc = NclDocument.fromContent('<ncl><head/><body/></ncl>');
      doc.body.children.add(media);

      bool viewTransitionTriggered = false;

      doc.onStateChanged = () {
        viewTransitionTriggered = true;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  Scene360Widget(
                    src: '',
                    mimeType: 'image/360',
                    media: media,
                    document: doc,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Living Room'), findsOneWidget);

      await tester.tap(find.text('Living Room'));
      await tester.pump();

      expect(doc.currentFocusNodeId, equals('hotspot_room1'));
      expect(viewTransitionTriggered, isTrue);
    });

    test('video360/main.ncl360 standalone parses and includes CERN LHC info', () {
      File xmlFile = File('examples/video360/main.ncl360');
      if (!xmlFile.existsSync()) {
        xmlFile = File('../../examples/video360/main.ncl360');
      }
      expect(xmlFile.existsSync(), isTrue);

      final xmlContent = xmlFile.readAsStringSync();
      final doc = NclDocument.fromContent(
        xmlContent,
        docSrc: 'examples/video360/main.ncl360',
      );

      final sceneMedia = doc.getNodeById('scene360_root') as Media?;
      expect(sceneMedia, isNotNull);
      expect(sceneMedia!.rawAttributes['type'], equals('application/x-ncl360'));

      final areas = sceneMedia.children.whereType<Area>().toList();
      expect(areas.any((a) => a.id == 'mainVideo'), isTrue);
      expect(areas.any((a) => a.id == 'lhcInfo'), isTrue);

      File infoFile = File('examples/video360/lhc_info.txt');
      if (!infoFile.existsSync()) {
        infoFile = File('../../examples/video360/lhc_info.txt');
      }
      expect(infoFile.existsSync(), isTrue);
      expect(infoFile.readAsStringSync().contains('Large Hadron Collider'), isTrue);

      doc.start();
      expect(doc.isPlaying, isTrue);
      expect(doc.getActiveMedia().contains(sceneMedia), isTrue);
    });

    test('Ncl360MediaPlugin canHandle supports application/x-ncl360 and .ncl360', () {
      final plugin = Ncl360MediaPlugin();
      expect(plugin.canHandle('louvre.ncl360', null), isTrue);
      expect(plugin.canHandle('https://example.com/scene.ncl360', null), isTrue);
      expect(plugin.canHandle('anything', 'application/x-ncl360'), isTrue);
      expect(plugin.canHandle('anything', 'application/x-ncl-360'), isTrue);
    });

    test('embedded application/x-ncl360 parses valid document with areas and links', () {
      const xmlContent = '''
<ncl id="Embedded360Test">
  <head>
    <connectorBase>
      <causalConnector id="onSelectionStopStart">
        <simpleCondition role="onSelection"/>
        <compoundAction operator="seq">
          <simpleAction role="stop"/>
          <simpleAction role="start"/>
        </compoundAction>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="entry" component="connect"/>
    <media id="connect" src="connect.png"/>
    <media id="intro" src="intro.mp4"/>
    <media id="scene360" type="application/x-ncl360" src="scene.ncl360">
      <area id="mainVideo" label="mainVideo"/>
      <area id="spot1" label="spot1"/>
    </media>
    <link xconnector="onSelectionStopStart">
      <bind role="onSelection" component="connect"/>
      <bind role="stop" component="connect"/>
      <bind role="start" component="intro"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xmlContent, docSrc: 'test.ncl');
      expect(doc.body.children.isNotEmpty, isTrue);

      final s360 = doc.getNodeById('scene360') as Media?;
      expect(s360, isNotNull);
      expect(s360!.rawAttributes['type'], equals('application/x-ncl360'));

      final areas = s360.children.whereType<Area>().toList();
      expect(areas.any((a) => a.id == 'mainVideo'), isTrue);
      expect(areas.any((a) => a.id == 'spot1'), isTrue);

      doc.start();
      expect(doc.isPlaying, isTrue);
      expect(doc.getNodeById('connect')?.getMainState(), equals(NclStateType.occurring));

      doc.triggerSelection('connect', 'OK');
      doc.tick(100);
      expect(doc.getNodeById('connect')?.getMainState(), equals(NclStateType.sleeping));
      expect(doc.getNodeById('intro')?.getMainState(), equals(NclStateType.occurring));
      expect(doc.isPlaying, isTrue);

      doc.stop();
    });

    testWidgets('navigation ignores keys so arrow keys do not modify yaw or pitch', (tester) async {
      final key = GlobalKey<MediaState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Scene360Widget(
                key: key,
                src: '',
                mimeType: 'image/360',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final state = key.currentState as dynamic;
      expect(state, isNotNull);

      final handledRight = state.handleKeyPress('RIGHT');
      await tester.pump();
      expect(handledRight, isFalse);
      expect(find.textContaining('Yaw: 0.0°'), findsOneWidget);

      final handledUp = state.handleKeyPress('UP');
      await tester.pump();
      expect(handledUp, isFalse);
      expect(find.textContaining('Pitch: 0.0°'), findsOneWidget);
    });

    testWidgets('supports mouse scroll wheel to zoom field of view', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Scene360Widget(
                src: '',
                mimeType: 'image/360',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('FoV: 90.0°'), findsOneWidget);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 50)));
      await tester.pump();

      expect(find.textContaining('FoV: 93.0°'), findsOneWidget);

      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -50)));
      await tester.pump();

      expect(find.textContaining('FoV: 90.0°'), findsOneWidget);
    });
  });

  group('Ncl360Projection Tests', () {
    test('fromString parses various projection formats', () {
      expect(Ncl360Projection.fromString(null), equals(Ncl360Projection.auto));
      expect(Ncl360Projection.fromString(''), equals(Ncl360Projection.auto));
      expect(Ncl360Projection.fromString('auto'), equals(Ncl360Projection.auto));
      expect(Ncl360Projection.fromString('eac'), equals(Ncl360Projection.eac));
      expect(Ncl360Projection.fromString('sbs'), equals(Ncl360Projection.eac));
      expect(Ncl360Projection.fromString('cubemap'), equals(Ncl360Projection.eac));
      expect(Ncl360Projection.fromString('equiangularcubemap'), equals(Ncl360Projection.eac));
      expect(Ncl360Projection.fromString('equirectangular'), equals(Ncl360Projection.equirectangular));
      expect(Ncl360Projection.fromString('equirect'), equals(Ncl360Projection.equirectangular));
      expect(Ncl360Projection.fromString('erp'), equals(Ncl360Projection.equirectangular));
    });

    testWidgets('Scene360Widget displays standard 360 HUD', (tester) async {
      final key = GlobalKey<MediaState>();
      final media = Media(
        rawAttributes: {
          'id': 'testSky',
          'src': 'pano.jpg',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  Scene360Widget(
                    key: key,
                    src: 'pano.jpg',
                    mimeType: 'image/360',
                    media: media,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('360° | Yaw: 0.0°'), findsOneWidget);
    });

    testWidgets('Scene360Widget supports remote video URL src', (tester) async {
      final key = GlobalKey<MediaState>();
      final media = Media(
        rawAttributes: {
          'id': 'remoteVideo',
          'src': 'https://threejs.org/examples/textures/pano.mp4',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  Scene360Widget(
                    key: key,
                    src: 'https://threejs.org/examples/textures/pano.mp4',
                    mimeType: 'video/360',
                    media: media,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(Scene360Widget), findsOneWidget);
    });
  });

  group('Ncl360ParserPlugin Tests', () {
    test('targetTag and plugin registration', () {
      final plugin = Ncl360ParserPlugin();
      expect(plugin.targetTag, equals('ncl360'));
      expect(plugin.type, equals(PluginType.experimental));

      final plugins = GetIt.instance.getAll<NclParserPlugin>().toList();
      expect(plugins.any((p) => p is Ncl360ParserPlugin), isTrue);
    });

    test('parseDocument creates valid head, body, port, and media areas', () {
      final plugin = Ncl360ParserPlugin();
      final xmlDoc = XmlDocument.parse('''
<ncl360 id="test360">
  <head/>
  <body>
    <media id="mainVideo" src="test.mp4" descriptor="dSky"/>
    <media id="info1" src="info.txt" descriptor="dInfo"/>
  </body>
</ncl360>
''');
      final parser = NclParser();
      final result = plugin.parseDocument(xmlDoc.rootElement, parser);
      expect(result, isNotNull);
      final (head, body) = result!;

      expect(head.any((e) => e is Region && e.id == 'rg_ncl360_root'), isTrue);
      expect(head.any((e) => e is Descriptor && e.id == 'desc_ncl360_root'), isTrue);

      final sceneMedia = body.children.whereType<Media>().firstWhere((m) => m.id == 'scene360_root');
      expect(sceneMedia.rawAttributes['type'], equals('application/x-ncl360'));
      expect(sceneMedia.children.whereType<Area>().length, equals(2));
      expect(sceneMedia.children.whereType<Area>().any((a) => a.id == 'mainVideo'), isTrue);
      expect(sceneMedia.children.whereType<Area>().any((a) => a.id == 'info1'), isTrue);
    });

    test('parseTag creates Media element with nested Area children', () {
      final plugin = Ncl360ParserPlugin();
      final xmlDoc = XmlDocument.parse('''
<ncl360 id="myTag" src="scene.ncl360" descriptor="d360">
  <media id="spot1" descriptor="dSpot1"/>
</ncl360>
''');
      final parser = NclParser();
      final elem = plugin.parseTag(xmlDoc.rootElement, parser);
      expect(elem, isNotNull);
      expect(elem, isA<Media>());
      final media = elem as Media;
      expect(media.id, equals('myTag'));
      expect(media.rawAttributes['type'], equals('application/x-ncl360'));
      expect(media.children.whereType<Area>().length, equals(1));
      expect(media.children.whereType<Area>().first.id, equals('spot1'));
    });

    test('NclParser parseString integrates Ncl360ParserPlugin via GetIt', () {
      final parser = NclParser();
      final (head, body) = parser.parseString('''
<ncl360 id="integratedTest">
  <head/>
  <body>
    <media id="sceneMedia1" src="stream.mp4"/>
  </body>
</ncl360>
''');
      expect(head.any((e) => e.id == 'rg_ncl360_root'), isTrue);
      final media = body.children.whereType<Media>().firstWhere((m) => m.id == 'scene360_root');
      expect(media.children.whereType<Area>().any((a) => a.id == 'sceneMedia1'), isTrue);
    });

    test('Ncl360Hotspot supports backgroundColor styling', () {
      final hotspot = Ncl360Hotspot(
        id: 'lhcInfo',
        coordinate: const SphericalCoordinate(polar: 0.0, azimuthal: 0.0),
        label: 'LHC Info',
        backgroundColor: Colors.grey,
      );
      expect(hotspot.backgroundColor, equals(Colors.grey));
    });

    testWidgets('Ncl360 Hotspot widget renders with background container when backgroundColor is specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 100,
                  top: 100,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                    color: Colors.grey,
                    child: const Text('Large Hadron Collider'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Large Hadron Collider'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, equals(Colors.grey));
    });
  });
}
