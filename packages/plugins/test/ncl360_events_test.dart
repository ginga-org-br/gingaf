import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncldoc/elements.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:plugins/ncl360_plugin.dart';

bool isMediaActive(NclDocument doc, String mediaId) =>
    doc.getActiveMedia().any((m) => m.id == mediaId);

void main() {
  group('NCL360 View Transition & Event Tests', () {
    test('onBeginView and onEndView trigger links when hotspot enters and exits view', () {
      const xml = '''
<ncl>
  <body>
    <port id="pInit" component="pano360"/>
    <media id="pano360" type="video/360">
      <area id="spot1" polar="0" azimuthal="0" radius="1.0" pin="environment"/>
    </media>
    <media id="banner" type="text/plain"/>
    <link id="lViewBegin">
      <bind role="onBeginView" component="pano360" interface="spot1"/>
      <bind role="start" component="banner"/>
    </link>
    <link id="lViewEnd">
      <bind role="onEndView" component="pano360" interface="spot1"/>
      <bind role="stop" component="banner"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      expect(isMediaActive(doc, 'banner'), isFalse);

      doc.handleViewTransition('pano360', true, 'spot1');
      expect(isMediaActive(doc, 'banner'), isTrue);

      doc.handleViewTransition('pano360', false, 'spot1');
      expect(isMediaActive(doc, 'banner'), isFalse);
    });

    test('onBeginView triggers when link binds directly to area as component', () {
      const xml = '''
<ncl>
  <body>
    <port id="pInit" component="pano360"/>
    <media id="pano360" type="video/360">
      <area id="spotDirect" polar="0" azimuthal="0"/>
    </media>
    <media id="overlay" type="text/plain"/>
    <link id="lDirect">
      <bind role="onBeginView" component="spotDirect"/>
      <bind role="start" component="overlay"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      expect(isMediaActive(doc, 'overlay'), isFalse);

      doc.handleViewTransition('spotDirect', true);
      expect(isMediaActive(doc, 'overlay'), isTrue);
    });

    test('onSelection on 360 hotspot triggers link actions', () {
      const xml = '''
<ncl>
  <body>
    <port id="pInit" component="pano360"/>
    <media id="pano360" type="video/360">
      <area id="doorway" polar="0" azimuthal="90"/>
    </media>
    <media id="nextRoom" type="video/360"/>
    <link id="lDoorway">
      <bind role="onSelection" component="pano360" interface="doorway"/>
      <bind role="start" component="nextRoom"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      expect(isMediaActive(doc, 'nextRoom'), isFalse);

      doc.handleSelection('doorway');
      expect(isMediaActive(doc, 'nextRoom'), isTrue);
    });

    test('onSelection on 360 hotspot binds directly to area component', () {
      const xml = '''
<ncl>
  <body>
    <port id="pInit" component="pano360"/>
    <media id="pano360" type="video/360">
      <area id="targetSpot" polar="0" azimuthal="45"/>
    </media>
    <media id="feedback" type="text/plain"/>
    <link id="lFeedback">
      <bind role="onSelection" component="targetSpot"/>
      <bind role="start" component="feedback"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      expect(isMediaActive(doc, 'feedback'), isFalse);

      doc.handleSelection('targetSpot');
      expect(isMediaActive(doc, 'feedback'), isTrue);
    });
  });

  group('NCL360 Advance Time & Duration Tests', () {
    test('advancing time expires explicit media duration and fires onEnd', () {
      const xml = '''
<ncl>
  <head>
    <descriptorBase>
      <descriptor id="dTimed" explicitDur="3s"/>
    </descriptorBase>
  </head>
  <body>
    <port id="pInit" component="pano360"/>
    <media id="pano360" type="video/360" descriptor="dTimed"/>
    <media id="followUp" type="text/plain"/>
    <link id="lEnd">
      <bind role="onEnd" component="pano360"/>
      <bind role="start" component="followUp"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      expect(isMediaActive(doc, 'pano360'), isTrue);
      expect(isMediaActive(doc, 'followUp'), isFalse);

      doc.tick(1000);
      expect(isMediaActive(doc, 'pano360'), isTrue);
      expect(isMediaActive(doc, 'followUp'), isFalse);

      doc.tick(1000);
      expect(isMediaActive(doc, 'pano360'), isTrue);
      expect(isMediaActive(doc, 'followUp'), isFalse);

      doc.tick(1500);
      expect(isMediaActive(doc, 'pano360'), isFalse);
      expect(isMediaActive(doc, 'followUp'), isTrue);
    });

    test('advancing time executes delayed link actions triggered by view transition', () {
      const xml = '''
<ncl>
  <body>
    <port id="pInit" component="pano360"/>
    <media id="pano360" type="video/360">
      <area id="hotspotTimed" polar="0" azimuthal="0"/>
    </media>
    <media id="delayedInfo" type="text/plain"/>
    <link id="lDelayed">
      <bind role="onBeginView" component="pano360" interface="hotspotTimed"/>
      <bind role="start" component="delayedInfo">
        <bindParam name="delay" value="2s"/>
      </bind>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      expect(isMediaActive(doc, 'delayedInfo'), isFalse);

      doc.handleViewTransition('pano360', true, 'hotspotTimed');
      expect(isMediaActive(doc, 'delayedInfo'), isFalse);

      doc.tick(1000);
      expect(isMediaActive(doc, 'delayedInfo'), isFalse);

      doc.tick(1200);
      expect(isMediaActive(doc, 'delayedInfo'), isTrue);
    });

    test('stepped advance time accumulates clock and resolves multiple scheduled events', () {
      const xml = '''
<ncl>
  <head>
    <descriptorBase>
      <descriptor id="dShort" explicitDur="1s"/>
      <descriptor id="dLong" explicitDur="2500ms"/>
    </descriptorBase>
  </head>
  <body>
    <port id="p1" component="m1"/>
    <port id="p2" component="m2"/>
    <media id="m1" type="video/360" descriptor="dShort"/>
    <media id="m2" type="video/360" descriptor="dLong"/>
    <media id="afterM1" type="text/plain"/>
    <media id="afterM2" type="text/plain"/>
    <link id="l1">
      <bind role="onEnd" component="m1"/>
      <bind role="start" component="afterM1"/>
    </link>
    <link id="l2">
      <bind role="onEnd" component="m2"/>
      <bind role="start" component="afterM2"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      expect(isMediaActive(doc, 'm1'), isTrue);
      expect(isMediaActive(doc, 'm2'), isTrue);
      expect(isMediaActive(doc, 'afterM1'), isFalse);
      expect(isMediaActive(doc, 'afterM2'), isFalse);

      for (int i = 0; i < 5; i++) {
        doc.tick(100);
      }
      expect(isMediaActive(doc, 'm1'), isTrue);
      expect(isMediaActive(doc, 'm2'), isTrue);

      for (int i = 0; i < 6; i++) {
        doc.tick(100);
      }
      expect(isMediaActive(doc, 'm1'), isFalse);
      expect(isMediaActive(doc, 'afterM1'), isTrue);
      expect(isMediaActive(doc, 'm2'), isTrue);
      expect(isMediaActive(doc, 'afterM2'), isFalse);

      doc.tick(1500);
      expect(isMediaActive(doc, 'm2'), isFalse);
      expect(isMediaActive(doc, 'afterM2'), isTrue);
    });
  });

  group('NCL360 Dynamic Property & Attribution Tests', () {
    test('setting yaw property dynamically modifies camera orientation', () {
      const xml = '''
<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onBeginSet">
        <connectorParam name="val"/>
        <simpleCondition role="onBegin"/>
        <simpleAction role="set" value="\$val"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="pInit" component="pano360"/>
    <port id="pTrigger" component="triggerMedia"/>
    <media id="pano360" type="video/360">
      <property name="yaw" value="0.0"/>
      <property name="pitch" value="0.0"/>
      <property name="fov" value="90.0"/>
    </media>
    <media id="triggerMedia" type="text/plain"/>
    <link id="lRotate" xconnector="onBeginSet">
      <bind role="onBegin" component="triggerMedia"/>
      <bind role="set" component="pano360" interface="yaw">
        <bindParam name="val" value="180.0"/>
      </bind>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      final pano = doc.getNodeById('pano360')!;
      expect(doc.getPropertyValue(pano, 'yaw'), equals('180.0'));
    });
  });

  group('Scene360Widget Interactive Viewport & Time Progression Tests', () {
    testWidgets('camera rotation dynamically updates hotspot inView and triggers links', (tester) async {
      const xml = '''
<ncl>
  <body>
    <port id="pInit" component="pano360"/>
    <media id="pano360" type="video/360">
      <area id="hotspotNorth" polar="0" azimuthal="0" radius="1.0" pin="environment" label="North Landmark"/>
      <area id="hotspotSouth" polar="0" azimuthal="180" radius="1.0" pin="environment" label="South Landmark"/>
    </media>
    <media id="northBanner" type="text/plain"/>
    <link id="lNorthBegin">
      <bind role="onBeginView" component="pano360" interface="hotspotNorth"/>
      <bind role="start" component="northBanner"/>
    </link>
    <link id="lNorthEnd">
      <bind role="onEndView" component="pano360" interface="hotspotNorth"/>
      <bind role="stop" component="northBanner"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      final media = doc.getNodeById('pano360') as Media;

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
                    mimeType: 'video/360',
                    media: media,
                    document: doc,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(isMediaActive(doc, 'northBanner'), isTrue);
      expect(find.text('North Landmark'), findsOneWidget);
      expect(find.text('South Landmark'), findsNothing);

      await tester.drag(find.byType(Scene360Widget), const Offset(-600.0, 0.0));
      await tester.pump(const Duration(milliseconds: 200));

      expect(isMediaActive(doc, 'northBanner'), isFalse);
      expect(find.text('North Landmark'), findsNothing);
      expect(find.text('South Landmark'), findsOneWidget);
    });

    test('onLookAt and onLookAway trigger links when looking at and away from interface', () {
      const xml = '''
<ncl>
  <body>
    <port id="pInit" component="louvre360"/>
    <media id="louvre360" type="application/x-ncl360">
      <area id="monalisa" polar="0" azimuthal="0"/>
    </media>
    <media id="soundTrack" type="audio/mp3"/>
    <link id="lLookAt">
      <bind role="onLookAt" component="louvre360" interface="monalisa"/>
      <bind role="start" component="soundTrack"/>
    </link>
    <link id="lLookAway">
      <bind role="onLookAway" component="louvre360" interface="monalisa"/>
      <bind role="stop" component="soundTrack"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      expect(isMediaActive(doc, 'soundTrack'), isFalse);

      doc.handleViewTransition('louvre360', true, 'monalisa');
      expect(isMediaActive(doc, 'soundTrack'), isTrue);

      doc.handleViewTransition('louvre360', false, 'monalisa');
      expect(isMediaActive(doc, 'soundTrack'), isFalse);
    });

    test('starting and stopping area interface does not stop parent media', () {
      const xml = '''
<ncl>
  <body>
    <port id="pInit" component="louvre360"/>
    <media id="louvre360" type="application/x-ncl360">
      <area id="photo1"/>
      <area id="photo2"/>
    </media>
    <media id="trigger" type="text/plain"/>
    <link id="lStartArea">
      <bind role="onBegin" component="trigger"/>
      <bind role="start" component="louvre360" interface="photo1"/>
    </link>
    <link id="lStopArea">
      <bind role="onEnd" component="trigger"/>
      <bind role="stop" component="louvre360" interface="photo1"/>
    </link>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      doc.start();

      final louvre = doc.getNodeById('louvre360') as Media;
      expect(louvre.getMainState(), equals(NclStateType.occurring));
      expect(louvre.getAreaNclEvent('photo1').state, equals(NclStateType.sleeping));

      final trigger = doc.getNodeById('trigger') as Media;
      doc.scheduler.stackNclAction(trigger.getMainNclEvent(), NclActionType.start);
      doc.scheduler.tick(0);

      expect(louvre.getAreaNclEvent('photo1').state, equals(NclStateType.occurring));
      expect(louvre.getMainState(), equals(NclStateType.occurring));

      doc.scheduler.stackNclAction(trigger.getMainNclEvent(), NclActionType.stop);
      doc.scheduler.tick(0);

      expect(louvre.getAreaNclEvent('photo1').state, equals(NclStateType.sleeping));
      expect(louvre.getMainState(), equals(NclStateType.occurring));
    });
  });
}

