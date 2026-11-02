import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/gingacc.dart';
import 'package:gingaf/ginga.dart';
import 'package:nclui/ncl.dart' as ncl;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mock_video_player.dart';

void main() {
  group('Playground Catalog Selection in Ginga', () {
    setUp(() {
      VideoPlayerPlatform.instance = MockVideoPlayer();
    });

    testWidgets(
        'shows catalog selector when playground is opened without app param',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final gingacc = GingaCC(
        config: GingaConfig(
          enablePlayground: true,
          appSrc: null,
        ),
      );
      gingacc.setVirtualFiles({
        'examples/catalog.json': '''{
          "examples": {
            "video": {
              "mainFile": "video.ncl",
              "category": "general",
              "description": "Video media presentation example"
            }
          }
        }''',
        'examples/video.ncl': '''<ncl id="my_test_video">
          <body>
            <port id="p1" component="v1"/>
            <media id="v1" src="movie.mp4"/>
          </body>
        </ncl>''',
      });

      await tester.pumpWidget(Ginga(gingacc: gingacc));
      await tester.pump(const Duration(milliseconds: 100));

      final editorFinder = find.byType(PlaygroundEditor);
      expect(editorFinder, findsOneWidget);

      expect(find.byKey(const Key('catalog_select')), findsOneWidget);
      expect(find.byKey(const Key('no_running_app_placeholder')), findsOneWidget);

      final editorState =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      await editorState.selectCatalogExample('video.ncl');
      await tester.pump(const Duration(milliseconds: 100));

      expect(editorState.effectiveContent, contains('my_test_video'));
      expect(gingacc.config.appSrc, equals('examples/video.ncl'));

      await tester.tap(find.byKey(const Key('monaco_run_button')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ncl.NclWidget), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'hides catalog selector when playground is opened with app param',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final gingacc = GingaCC(
        config: GingaConfig(
          enablePlayground: true,
          appSrc: 'examples/video.ncl',
        ),
      );
      gingacc.setVirtualFiles({
        'examples/video.ncl': '<ncl id="with_app"><body/></ncl>',
      });

      await tester.pumpWidget(Ginga(gingacc: gingacc));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PlaygroundEditor), findsOneWidget);
      expect(find.byKey(const Key('catalog_select')), findsNothing);
      expect(find.text('video.ncl'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    test('parseArgsCliAndEnv parses playground without app', () {
      final parsed = parseArgsCliAndEnv(['--playground']);
      expect(parsed.playground, isTrue);
      expect(parsed.app, isNull);
    });

    test('parseArgsCliAndEnv parses playground with app', () {
      final parsed =
          parseArgsCliAndEnv(['--playground', '--app=examples/video.ncl']);
      expect(parsed.playground, isTrue);
      expect(parsed.app, equals('examples/video.ncl'));
    });
  });
}
