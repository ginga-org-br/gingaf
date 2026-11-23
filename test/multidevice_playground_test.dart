import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ginga.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:nclui/ncl_widget.dart';
import 'package:plugins/ncl360_math.dart';
import 'package:plugins/ncl360_plugin.dart';

void main() {
  testWidgets(
      '3-view Playground session runs main screen, ncl-360-vr (Scene360Widget), and accessibility (VLibras HtmlWidget) simultaneously without overwriting PlaygroundEditor',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cc = GingaCC();
    cc.config = GingaConfig(
      appSrc: 'examples/multidevice/multidevice_vlibras_vr360.ncl',
      enablePlayground: true,
      startWithCCWS: true,
    );
    addTearDown(() async {
      cc.clearRemoteDevices();
      await cc.ccws.stop();
    });

    await tester.pumpWidget(Ginga(gingacc: cc));
    await tester.pumpAndSettle();

    expect(cc.ccws.ssdpServer, isNull);
    expect(cc.ccws.ssdpPort, isNull);

    expect(find.byKey(const Key('flutter_monaco_widget')), findsOneWidget);
    expect(
      find.byKey(const Key('floating_menu_toggle_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('monaco_add_remote_device_button')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('floating_menu_toggle_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('monaco_add_remote_device_button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('playground_multidevice_column')), findsNothing);

    final editorSizeBefore =
        tester.getSize(find.byKey(const Key('flutter_monaco_widget')));
    final playerHeightBefore = tester
        .getSize(find.byKey(const Key('no_running_app_placeholder')))
        .height;

    await tester.tap(find.byKey(const Key('monaco_add_remote_device_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_remote_device_ncl_360_vr')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('monaco_add_remote_device_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_remote_device_accessibility')));
    await tester.pumpAndSettle();

    expect(cc.getRemoteDevicesByClass('ncl-360-vr').length, 1);
    expect(cc.getRemoteDevicesByClass('accessibility').length, 1);
    expect(
      find.byKey(const Key('remote_device_idle_ncl-360-vr')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('remote_device_idle_accessibility')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('flutter_monaco_widget'))),
      equals(editorSizeBefore),
    );

    final mainPaneRect =
        tester.getRect(find.byKey(const Key('playground_main_player_pane')));
    final companionsPaneRect =
        tester.getRect(find.byKey(const Key('playground_companions_pane')));
    expect(mainPaneRect.height, lessThan(playerHeightBefore));
    expect(companionsPaneRect.top, greaterThanOrEqualTo(mainPaneRect.bottom));

    await tester.tap(find.byKey(const Key('monaco_run_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('playground_main_player_pane')), findsOneWidget);
    expect(find.byKey(const Key('playground_companions_pane')), findsOneWidget);
    expect(find.byType(NclWidget), findsOneWidget);
    expect(find.byType(Scene360Widget), findsOneWidget);
    expect(find.byType(HtmlWidget), findsOneWidget);

    final nclState = tester.state<NclWidgetState>(find.byType(NclWidget));
    final mainDoc = nclState.nclDocument!;
    expect(mainDoc.getSystemVariable('ncl-360-vr.devNumber'), '1');
    expect(mainDoc.getSystemVariable('accessibility.devNumber'), '1');

    final remoteStates = tester
        .stateList<RemoteDevicePlayerWidgetState>(
          find.byType(RemoteDevicePlayerWidget),
        )
        .toList();
    expect(remoteStates.length, 2);

    final vr360Remote =
        remoteStates.firstWhere((s) => s.widget.deviceClass == 'ncl-360-vr');
    final vlibrasRemote =
        remoteStates.firstWhere((s) => s.widget.deviceClass == 'accessibility');

    expect(cc.ccws.ssdpServer, isNull);
    expect(vr360Remote.widget.useSsdpDiscovery, isFalse);
    expect(vlibrasRemote.widget.useSsdpDiscovery, isFalse);
    expect(vr360Remote.client.discoveredReceiver, isNull);
    expect(vlibrasRemote.client.discoveredReceiver, isNull);
    expect(vr360Remote.client.wsUrl, startsWith('ws://localhost:'));
    expect(vlibrasRemote.client.wsUrl, startsWith('ws://localhost:'));

    expect(vr360Remote.isPlaying, isTrue);
    expect(vr360Remote.activeNodeId, 'scene360');
    expect(vr360Remote.activeNodeSrc, endsWith('vr360_companion.ncl360'));

    expect(vlibrasRemote.isPlaying, isTrue);
    expect(vlibrasRemote.activeNodeId, 'vlibrasStream');
    expect(vlibrasRemote.activeNodeSrc, endsWith('vlibras_companion.html'));
    expect(
      vlibrasRemote.properties['librasGloss'],
      'BORBOLETA',
    );

    expect(
      mainDoc.getMediaById('infoOverlay')?.getMainState(),
      NclStateType.sleeping,
    );
    vr360Remote.sendViewTransition('hotspot1', true);
    await tester.pump();
    expect(
      mainDoc.getMediaById('infoOverlay')?.getMainState(),
      NclStateType.occurring,
    );

    vr360Remote.sendViewTransition('hotspot1', false);
    await tester.pump();
    expect(
      mainDoc.getMediaById('infoOverlay')?.getMainState(),
      NclStateType.sleeping,
    );

    expect(mainDoc.getMediaById('tvAck')?.getMainState(), NclStateType.sleeping);
    vlibrasRemote.sendSelectionTransition();
    await tester.pump();
    expect(
      mainDoc.getMediaById('tvAck')?.getMainState(),
      NclStateType.occurring,
    );

    mainDoc.tick(2100);
    await tester.pump();
    expect(
      vlibrasRemote.properties['librasGloss'],
      'BORBOLETA',
    );

    const hotspotCoord = SphericalCoordinate(
      polar: 0.0,
      azimuthal: 0.0,
      radius: 1.0,
    );
    const gazeIterations = 30;
    const glossIterations = 20;
    final vlibrasMedia = mainDoc.getMediaById('vlibrasStream')!;
    final infoOverlayMedia = mainDoc.getMediaById('infoOverlay')!;

    final gazeSw = Stopwatch()..start();
    for (var i = 0; i < gazeIterations; i++) {
      final yaw = i.isEven ? 0.0 : 180.0;
      final inView = hotspotCoord.isInView(
        cameraYaw: yaw,
        cameraPitch: 0.0,
        fov: 90.0,
      );
      vr360Remote.sendViewTransition('hotspot1', inView);
      await tester.pump();
      expect(
        infoOverlayMedia.getMainState(),
        inView ? NclStateType.occurring : NclStateType.sleeping,
      );
    }
    gazeSw.stop();
    final meanGazeMs = gazeSw.elapsedMicroseconds / 1000.0 / gazeIterations;
    expect(meanGazeMs, lessThan(50.0));

    final glossSw = Stopwatch()..start();
    for (var i = 0; i < glossIterations; i++) {
      final cueGloss = 'GLOSA PLAYGROUND CUE-$i';
      mainDoc.dispatchPropertyUpdate(
        vlibrasMedia,
        'librasGloss',
        cueGloss,
      );
      await tester.pump();
      expect(vlibrasRemote.properties['librasGloss'], cueGloss);
    }
    glossSw.stop();
    final meanGlossMs = glossSw.elapsedMicroseconds / 1000.0 / glossIterations;
    expect(meanGlossMs, lessThan(20.0));

    await tester
        .tap(find.byKey(const Key('playground_companion_close_companion_1')));
    await tester.pump();
    await tester
        .tap(find.byKey(const Key('playground_companion_close_companion_2')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );

    expect(find.byKey(const Key('playground_companions_pane')), findsNothing);
    expect(cc.getRemoteDevicesByClass('ncl-360-vr'), isEmpty);
    expect(cc.getRemoteDevicesByClass('accessibility'), isEmpty);
  });
}
