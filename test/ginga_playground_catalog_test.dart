import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/gingacc.dart';
import 'package:gingaf/args.dart';
import 'package:gingaf/ginga.dart';
import 'package:gingaf/web_utils_stub.dart'
    if (dart.library.js_interop) 'package:gingaf/web_utils_web.dart';
import 'package:ginga_appui/html_widget.dart' as html;
import 'package:ginga_appui/main_av_widget.dart';
import 'package:ginga_appui/ncl_widget.dart' as ncl;
import 'package:playground/playground.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mock_video_player.dart';

void main() {
  group('Playground Catalog Selection in Ginga', () {
    setUp(() {
      VideoPlayerPlatform.instance = MockVideoPlayer();
    });

    tearDown(() {
      catalogExamplesBaseUrl = defaultCatalogExamplesBaseUrl;
    });

    testWidgets(
        'shows catalog selector when playground is opened without app param',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('ginga_cat_sel1_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      File('${tempDir.path}/catalog.json').writeAsStringSync('''{
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
      }''');
      File('${tempDir.path}/video.ncl')
          .writeAsStringSync('''<ncl id="my_test_video">
        <body>
          <port id="p1" component="v1"/>
          <media id="v1" src="movie.mp4"/>
        </body>
      </ncl>''');
      File('${tempDir.path}/lua_demo.ncl')
          .writeAsStringSync('''<ncl id="my_lua_demo">
        <body>
          <port id="p1" component="v1"/>
          <media id="v1" src="movie.mp4"/>
        </body>
      </ncl>''');
      catalogExamplesBaseUrl = tempDir.uri.toString();

      final gingacc = GingaCC(
        config: GingaConfig(
          enablePlayground: true,
          appSrc: null,
        ),
      );

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
      expect(
          find.byKey(const Key('no_running_app_placeholder')), findsNothing);
      final catalogRect =
          tester.getRect(find.byKey(const Key('catalog_grid_dialog')));
      expect(catalogRect.left, equals(0.0));
      expect(catalogRect.width, equals(1920.0));

      await tester.tap(find.byKey(const Key('catalog_option_lua_demo')));
      await tester.pump(const Duration(milliseconds: 200));

      final editorState =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(editorState.effectiveContent, contains('my_lua_demo'));
      expect(
        gingacc.config.appSrc,
        equals(resolveCatalogExampleUrl('lua_demo.ncl')),
      );
      expect(
        lastSyncedBrowserUrl,
        contains('app=${resolveCatalogExampleUrl('lua_demo.ncl')}'),
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

      await tester.pumpWidget(
        Ginga.fromContent(
          '<ncl id="with_app"><body/></ncl>',
          gingacc: gingacc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PlaygroundEditor), findsOneWidget);
      expect(find.byKey(const Key('catalog_select')), findsNothing);
      expect(find.text('video.ncl'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'loads otherEditbleFiles tabs from catalog when opened directly with app param',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('ginga_cat_direct_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      File('${tempDir.path}/catalog.json').writeAsStringSync('''{
        "examples": {
          "ncl_media_nclua": {
            "mainFile": "ginga.org.br/media_nclua.ncl",
            "category": "ginga.org.br",
            "otherEditbleFiles": ["media_nclua.lua"]
          }
        }
      }''');
      File('${tempDir.path}/ginga.org.br/media_nclua.ncl')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('<ncl><body><port id="p0" component="lua"/><media id="lua" src="media_nclua.lua"/></body></ncl>');
      File('${tempDir.path}/ginga.org.br/media_nclua.lua')
          .writeAsStringSync("canvas:attrColor('blue')\ncanvas:flush()\n");
      catalogExamplesBaseUrl = tempDir.uri.toString();

      final appUrl = resolveCatalogExampleUrl('ginga.org.br/media_nclua.ncl');
      final gingacc = GingaCC(
        config: GingaConfig(
          enablePlayground: true,
          appSrc: appUrl,
        ),
      );

      await tester.pumpWidget(Ginga(gingacc: gingacc));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('catalog_select')), findsNothing);
      expect(find.text('media_nclua.ncl'), findsOneWidget);
      expect(find.text('media_nclua.lua'), findsOneWidget);

      await tester.tap(find.text('media_nclua.lua'));
      await tester.pump(const Duration(milliseconds: 100));

      final editorState =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(editorState.effectiveContent, contains("canvas:attrColor('blue')"));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'applies ginga_config.json mainAvSrc when selecting sbtvd example in playground',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('ginga_cat_sel3_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      File('${tempDir.path}/catalog.json').writeAsStringSync('''{
        "examples": {
          "sbtvd": {
            "mainFile": "sbtvd/main.ncl",
            "category": "general",
            "description": "SBTVD broadcast video example",
            "otherEditbleFiles": ["ginga_config.json"]
          }
        }
      }''');
      File('${tempDir.path}/sbtvd/main.ncl')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('''<ncl>
          <body>
            <port id="init" component="video"/>
            <media id="video" src="sbtvd://video">
              <property name="bounds" value="25%,25%,50%,50%"/>
            </media>
          </body>
        </ncl>''');
      File('${tempDir.path}/sbtvd/ginga_config.json').writeAsStringSync(
          '{"mainAvSrc": "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4"}');
      catalogExamplesBaseUrl = tempDir.uri.toString();

      final gingacc = GingaCC(
        config: GingaConfig(
          enablePlayground: true,
          appSrc: null,
        ),
      );

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

    test('buildGingaBrowserUrl updates app and remote-devices query params',
        () {
      final updated = buildGingaBrowserUrl(
        'http://localhost:8080/playground',
        'multidevice/multidevice_vlibras_vr360.ncl?remote-devices=ncl-360-vr,acessibility',
        resolvedAppUrl:
            'http://localhost:8080/examples/multidevice/multidevice_vlibras_vr360.ncl?remote-devices=ncl-360-vr,acessibility',
      );
      expect(
        updated,
        'http://localhost:8080/playground?app=http://localhost:8080/examples/multidevice/multidevice_vlibras_vr360.ncl&remote-devices=ncl-360-vr,acessibility',
      );
      final uri = Uri.parse(updated);
      expect(
        uri.queryParameters['app'],
        'http://localhost:8080/examples/multidevice/multidevice_vlibras_vr360.ncl',
      );
      expect(
        uri.queryParameters['remote-devices'],
        'ncl-360-vr,acessibility',
      );
    });

    testWidgets(
        'shows full-screen catalog with left sandwich category menu and search in player-only mode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('ginga_cat_player_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      File('${tempDir.path}/catalog.json').writeAsStringSync('''{
        "examples": {
          "video": {
            "mainFile": "video.ncl",
            "category": "general",
            "description": "Video example"
          },
          "lua_demo": {
            "mainFile": "lua.ncl",
            "category": "lua",
            "description": "Lua interactive script"
          }
        }
      }''');
      File('${tempDir.path}/video.ncl')
          .writeAsStringSync('<ncl id="v"><body/></ncl>');
      File('${tempDir.path}/lua.ncl')
          .writeAsStringSync('<ncl id="l"><body/></ncl>');
      catalogExamplesBaseUrl = tempDir.uri.toString();

      final gingacc = GingaCC(
        config: GingaConfig(
          enablePlayground: false,
          appSrc: null,
        ),
      );

      await tester.pumpWidget(Ginga(gingacc: gingacc));
      await tester.pump(const Duration(milliseconds: 150));

      await tester.tap(find.byKey(const Key('catalog_select')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('catalog_grid_dialog')), findsOneWidget);
      final catalogRect =
          tester.getRect(find.byKey(const Key('catalog_grid_dialog')));
      expect(catalogRect.left, equals(0.0));
      expect(catalogRect.width, equals(1280.0));
      expect(find.byKey(const Key('catalog_search_input')), findsOneWidget);
      expect(find.byKey(const Key('catalog_nav_toggle')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('catalog_search_input')),
        'interactive',
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('catalog_option_lua_demo')), findsOneWidget);
      expect(find.byKey(const Key('catalog_option_video')), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'keeps catalog full-screen before, during, and after running multi-file lua_zip_list example',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('ginga_cat_luazip_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      File('${tempDir.path}/catalog.json').writeAsStringSync('''{
        "examples": {
          "lua_zip_list": {
            "mainFile": "lua/zip_list/main.ncl",
            "category": "lua",
            "description": "NCLua zip helper module archive explorer example",
            "otherEditbleFiles": ["main.lua"]
          }
        }
      }''');
      File('${tempDir.path}/lua/zip_list/main.ncl')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('''<ncl id="zip_list">
          <head>
            <regionBase><region id="rgMain" left="5%" top="5%" width="90%" height="90%"/></regionBase>
            <descriptorBase><descriptor id="dMain" region="rgMain"/></descriptorBase>
          </head>
          <body>
            <port id="pInit" component="luaZip"/>
            <media id="luaZip" src="main.lua" descriptor="dMain"/>
          </body>
        </ncl>''');
      File('${tempDir.path}/lua/zip_list/main.lua').writeAsStringSync('''
        canvas:attrColor(48, 48, 48, 255)
        canvas:drawRect('fill', 0, 0, 100, 100)
        canvas:flush()
      ''');
      catalogExamplesBaseUrl = tempDir.uri.toString();

      final gingacc = GingaCC(
        config: GingaConfig(
          enablePlayground: true,
          appSrc: null,
        ),
      );

      await tester.pumpWidget(Ginga(gingacc: gingacc));
      await tester.pump(const Duration(milliseconds: 150));

      await tester.tap(find.byKey(const Key('catalog_select')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.getRect(find.byKey(const Key('catalog_grid_dialog'))).width,
        equals(1920.0),
      );

      await tester.tap(find.byKey(const Key('catalog_option_lua_zip_list')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('catalog_grid_dialog')), findsNothing);

      await tester.tap(find.byKey(const Key('monaco_run_button')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ncl.NclWidget), findsOneWidget);

      await tester.tap(find.byKey(const Key('catalog_select')));
      await tester.pump(const Duration(milliseconds: 200));
      final rectWhileRunning =
          tester.getRect(find.byKey(const Key('catalog_grid_dialog')));
      expect(rectWhileRunning.left, equals(0.0));
      expect(rectWhileRunning.width, equals(1920.0));

      await tester.tap(find.byKey(const Key('monaco_stop_button')));
      await tester.pump(const Duration(milliseconds: 200));
      final rectAfterStop =
          tester.getRect(find.byKey(const Key('catalog_grid_dialog')));
      expect(rectAfterStop.left, equals(0.0));
      expect(rectAfterStop.width, equals(1920.0));

      await tester.tap(find.byKey(const Key('monaco_run_button')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('catalog_grid_dialog')), findsNothing);
      expect(find.byType(ncl.NclWidget), findsOneWidget);

      await tester.tap(find.byKey(const Key('catalog_select')));
      await tester.pump(const Duration(milliseconds: 200));
      final rectReopened =
          tester.getRect(find.byKey(const Key('catalog_grid_dialog')));
      expect(rectReopened.left, equals(0.0));
      expect(rectReopened.width, equals(1920.0));

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Playground Catalog Examples Launch Tests', () {
    setUp(() {
      VideoPlayerPlatform.instance = MockVideoPlayer();
    });

    final catalogFile = File('examples/catalog.json');
    final examples = parseCatalog(catalogFile.readAsStringSync());

    for (final item in examples) {
      final exampleKey = item.key;
      final mainFile = item.mainFile;
      final examplePath = 'examples/$mainFile';

      testWidgets(
          'launches playground with catalog example $exampleKey ($examplePath)',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final config = GingaConfig(
          enablePlayground: true,
          appSrc: examplePath,
        );
        final gingacc = GingaCC(config: config);

        await tester.pumpWidget(Ginga(gingacc: gingacc));
        await tester.pump(const Duration(milliseconds: 100));

        final editorFinder = find.byType(PlaygroundEditor);
        expect(editorFinder, findsOneWidget);

        final editorRect = tester.getRect(editorFinder);
        expect(editorRect.left, equals(0.0));

        await tester.tap(find.byKey(const Key('monaco_run_button')));
        await tester.pump(const Duration(milliseconds: 100));

        if (item.type == 'HTML') {
          expect(find.byType(html.HtmlWidget), findsWidgets);
        } else {
          expect(find.byType(ncl.NclWidget), findsWidgets);
          final nclRect = tester.getRect(find.byType(ncl.NclWidget).first);
          expect(editorRect.right, lessThanOrEqualTo(nclRect.left));
        }

        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
