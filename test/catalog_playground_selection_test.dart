import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/gingacc.dart';
import 'package:gingaf/args.dart';
import 'package:gingaf/ginga.dart';
import 'package:nclui/main_av_widget.dart';
import 'package:nclui/ncl_widget.dart' as ncl;
import 'package:playground/playground.dart';
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
            },
            "lua_demo": {
              "mainFile": "lua_demo.ncl",
              "category": "lua",
              "description": "Lua demo application"
            }
          }
        }''',
        'examples/video.ncl': '''<ncl id="my_test_video">
          <body>
            <port id="p1" component="v1"/>
            <media id="v1" src="movie.mp4"/>
          </body>
        </ncl>''',
        'examples/lua_demo.ncl': '''<ncl id="my_lua_demo">
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
      expect(
          find.byKey(const Key('no_running_app_placeholder')), findsOneWidget);

      await tester.tap(find.byKey(const Key('catalog_select')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('catalog_grid_dialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('catalog_option_lua_demo')));
      await tester.pump(const Duration(milliseconds: 200));

      final editorState =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(editorState.effectiveContent, contains('my_lua_demo'));
      expect(
        gingacc.config.appSrc,
        equals(
          'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/lua_demo.ncl',
        ),
      );

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

    testWidgets(
        'applies ginga_config.json mainAvSrc when selecting sbtvd example in playground',
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
            "sbtvd": {
              "mainFile": "sbtvd/main.ncl",
              "category": "general",
              "description": "SBTVD broadcast video example",
              "otherEditbleFiles": ["ginga_config.json"]
            }
          }
        }''',
        'examples/sbtvd/main.ncl': '''<ncl>
          <body>
            <port id="init" component="video"/>
            <media id="video" src="sbtvd://video">
              <property name="bounds" value="25%,25%,50%,50%"/>
            </media>
          </body>
        </ncl>''',
        'examples/sbtvd/ginga_config.json':
            '{"mainAvSrc": "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4"}',
      });

      await tester.pumpWidget(Ginga(gingacc: gingacc));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('catalog_select')));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('catalog_option_sbtvd')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        gingacc.config.mainAvSrc,
        equals(
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
      );

      await tester.tap(find.byKey(const Key('monaco_run_button')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      final mainAvFinder = find.byType(MainAVWidget);
      expect(mainAvFinder, findsOneWidget);
      final mainAv = tester.widget<MainAVWidget>(mainAvFinder);
      expect(
        mainAv.src,
        equals(
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
      );

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
