import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:nclui/ncl.dart';
import 'package:plugins/data_binding_controller.dart';
import 'package:plugins/plugins.dart';

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    registerAllPlugins(GetIt.instance);
  });

  group('EBNF Expression Parser & Security Sandboxing', () {
    test('parses valid 1D, 2D, and field binding expressions', () {
      final expr2D = BindingExpression.parse('{movies[row][column]}');
      expect(expr2D.isDynamic, isTrue);
      expect(expr2D.rootIdentifier, equals('movies'));
      expect(expr2D.usesRow, isTrue);
      expect(expr2D.usesColumn, isTrue);
      expect(expr2D.astDepth, equals(3));

      final exprField =
          BindingExpression.parse('data:text/plain,{schedule[row][column].title}');
      expect(exprField.isDynamic, isTrue);
      expect(exprField.astDepth, equals(4));
      final data = <String, dynamic>{
        'schedule': [
          [
            {'title': 'News', 'span': 1},
            {'title': 'Live Match', 'span': 2},
          ],
        ],
      };
      expect(
        exprField.evaluate(data, row: 0, column: 1),
        equals('Live Match'),
      );
      expect(
        exprField.evaluateAsString(data, row: 0, column: 1),
        equals('data:text/plain,Live Match'),
      );
    });

    test('enforces AST depth limit <= 4 and rejects code injection', () {
      expect(
        () => BindingExpression.parse('{a[row][column].b.c}'),
        throwsFormatException,
      );
      expect(
        () => BindingExpression.parse('{os.execute("rm")}'),
        throwsFormatException,
      );
      expect(
        () => BindingExpression.parse('{movies[row[0]]}'),
        throwsFormatException,
      );
    });
  });

  group('Lua Controller Table Parser', () {
    test('parses Lua controller table accurately', () {
      const luaScript = '''
local data = {
  category = { "Action", "Comedy", "Drama" },
  movies = {
    { "action1.png", "action2.png", "action3.png", "action4.png" },
    { "comedy1.png", "comedy2.png", "comedy3.png", "comedy4.png" },
    { "drama1.png", "drama2.png", "drama3.png", "drama4.png" }
  }
}
return data
''';
      final parsed = DataBindingLuaRuntime().execute(luaScript);
      expect(parsed['category'], equals(['Action', 'Comedy', 'Drama']));
      final expr = BindingExpression.parse('{movies[row][column]}');
      expect(
        expr.evaluateAsString(parsed, row: 1, column: 2),
        equals('comedy3.png'),
      );
    });
  });

  group('SlotPool & Operational Semantics Navigation', () {
    test('maintains bounded slot pool capacity during continuous D-pad navigation', () {
      final catalog = <String, dynamic>{
        'movies': List.generate(
          6,
          (r) => List.generate(20, (c) => 'movie_${r}_$c.png'),
        ),
      };
      final controller = DataBindingController(
        contextId: 'nav_ctx',
        visibleRows: 3,
        visibleColumns: 4,
        bufferSlots: 2,
        wrap: true,
        initialData: catalog,
        medias: [
          Media(
            rawAttributes: const {
              'id': 'mMovies',
              'src': '{movies[row][column]}',
            },
          ),
        ],
      );

      expect(controller.slotPool.capacity, equals((3 + 4) * (4 + 4)));

      for (int i = 0; i < 40; i++) {
        controller.handleKey('CURSOR_RIGHT');
      }
      for (int i = 0; i < 10; i++) {
        controller.handleKey('CURSOR_DOWN');
      }

      expect(controller.slotPool.totalReuses, greaterThan(0));
    });

    test('2D EPG preserves temporal alignment and zero scroll tearing', () {
      final epgData = <String, dynamic>{
        'channels': [
          {'id': 101, 'name': 'CH 101'},
          {'id': 102, 'name': 'CH 102'},
          {'id': 103, 'name': 'CH 103'},
        ],
        'timeline': [
          {'time': '20:00', 'minutes': 1200},
          {'time': '20:30', 'minutes': 1230},
          {'time': '21:00', 'minutes': 1260},
        ],
        'schedule': [
          [
            {'title': 'News', 'span': 1},
            {'title': 'Drama', 'span': 2},
          ],
          [
            {'title': 'Sports', 'span': 1},
            {'title': 'Show', 'span': 2},
          ],
          [
            {'title': 'Feature Film', 'span': 2},
            {'title': 'Late Night', 'span': 1},
          ],
        ],
      };
      final epgCtrl = DataBindingController(
        contextId: 'epg_ctx',
        visibleRows: 3,
        visibleColumns: 3,
        initialData: epgData,
        medias: [
          Media(
            rawAttributes: const {
              'id': 'chItem',
              'src': '{channels[row].name}',
            },
          ),
          Media(
            rawAttributes: const {
              'id': 'timeItem',
              'src': '{timeline[column].time}',
            },
          ),
          Media(
            rawAttributes: const {
              'id': 'progItem',
              'src': '{schedule[row][column].title}',
            },
          ),
        ],
      );

      epgCtrl.handleKey('CURSOR_RIGHT');
      epgCtrl.handleKey('CURSOR_DOWN');
      epgCtrl.handleKey('CURSOR_DOWN');
      expect(epgCtrl.focusedRow, equals(2));
      expect(epgCtrl.focusedCol, equals(0));
    });

    test('updatePolicy stream updates in-place without mutating focus or viewport', () {
      final sportsCtrl = DataBindingController(
        contextId: 'sports_ctx',
        visibleRows: 2,
        visibleColumns: 2,
        updateIntervalMs: 3000,
        medias: [
          Media(
            rawAttributes: const {
              'id': 'statCard',
              'src': '{stats[row].value}',
            },
          ),
          Media(
            rawAttributes: const {
              'id': 'camItem',
              'src': '{cameras[column].preview}',
            },
          ),
        ],
      );
      sportsCtrl.executeLua('''
data = {
  stats = {
    { metric = "Ball Speed", value = "108.4 km/h" },
    { metric = "Sprint", value = "34.2 km/h" }
  },
  cameras = {
    { name = "Cam 1", preview = "c1.png" },
    { name = "Cam 2", preview = "c2.png" }
  }
}
function onTick(clockMs)
  data.stats[1].value = "114.8 km/h"
  return data
end
return data
''');
      sportsCtrl.handleKey('CURSOR_DOWN');
      sportsCtrl.handleKey('CURSOR_RIGHT');
      final prevRow = sportsCtrl.focusedRow;
      final prevCol = sportsCtrl.focusedCol;

      sportsCtrl.tickStream(3000);

      expect(sportsCtrl.focusedRow, equals(prevRow));
      expect(sportsCtrl.focusedCol, equals(prevCol));
      expect(
        BindingExpression.parse('{stats[row].value}')
            .evaluateAsString(sportsCtrl.data, row: 0, column: 0),
        equals('114.8 km/h'),
      );
    });

    testWidgets(
      'Executes Extended NCL document with service.currentKeyMaster and renders slots',
      (tester) async {
        const nclXml = '''
<ncl id="streamApp" xmlns="http://www.ncl.org.br/NCL3.0/EDTV">
  <head>
    <regionBase>
      <region id="screen" width="100%" height="100%">
        <region id="gridRegion" rows="3" columns="4" scroll="both" width="100%" height="100%" />
      </region>
    </regionBase>
    <descriptorBase>
      <descriptor id="moviesDesc" region="gridRegion" />
    </descriptorBase>
  </head>
  <body>
    <port id="pCatalog" component="catalog" />
    <media id="settings" type="application/x-ginga-settings">
      <property name="service.currentKeyMaster" value="catalog" />
    </media>
    <context id="catalog" data-binding="hero_carousel.lua">
      <port id="moviePort" component="movie" />
      <media id="movie" src="{movies[row][column]}" descriptor="moviesDesc" type="image/png" />
    </context>
  </body>
</ncl>
''';

        final doc = NclDocument.fromContent(nclXml);
        doc.start();
        doc.tick(100);

        final movieMedia = doc.getMediaById('movie');
        expect(movieMedia, isNotNull);
        expect(movieMedia!.getMainState(), equals(NclStateType.occurring));

        final ctrl = DataBindingMediaPlugin.obtainController(
          document: doc,
          media: movieMedia,
          explicitContextId: 'catalog',
          initialData: {
            'movies': [
              ['Cosmos Odyssey 4K', 'Amazonia Viva', 'Cyber Horizon', 'Sertao Digital'],
              ['Velocity GT', 'Orbital Strike', 'Neon Protocol', 'Quantum Drift'],
            ],
          },
        );

        final widget = NclWidget.createMediaWidget(
          media: movieMedia,
          document: doc,
        );
        expect(widget, isA<DataBindingWidget>());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1280,
                height: 720,
                child: Stack(children: [widget!]),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('Cosmos Odyssey 4K'), findsOneWidget);

        doc.handleKey('CURSOR_RIGHT');
        await tester.pump();

        expect(ctrl.focusedCol, equals(1));
        expect(ctrl.focusedRow, equals(0));
      },
    );

    testWidgets(
      'Renders Media elements for rows, columns, and scroll and enforces service.currentKeyMaster',
      (tester) async {
        const nclXml = '''
<ncl id="multiCtxApp" xmlns="http://www.ncl.org.br/NCL3.0/EDTV">
  <head>
    <regionBase>
      <region id="screen" width="100%" height="100%">
        <region id="railRegion" top="0%" height="20%" columns="4" scroll="horizontal" />
        <region id="matrixRegion" top="20%" height="80%" rows="2" columns="3" scroll="both" />
      </region>
    </regionBase>
    <descriptorBase>
      <descriptor id="dRail" region="railRegion" />
      <descriptor id="dMatrix" region="matrixRegion" />
    </descriptorBase>
  </head>
  <body>
    <port id="pActive" component="activeCtx" />
    <port id="pOther" component="otherCtx" />
    <media id="settings" type="application/x-ginga-settings">
      <property name="service.currentKeyMaster" value="activeCtx" />
    </media>
    <context id="activeCtx" data-binding="hero_carousel.lua">
      <media id="mRail" src="{categories[column]}" descriptor="dRail" type="text/plain" />
      <media id="mMatrix" src="{movies[row][column]}" descriptor="dMatrix" type="image/png" />
    </context>
    <context id="otherCtx" data-binding="hero_carousel.lua">
      <media id="mOther" src="{movies[row][column]}" descriptor="dMatrix" type="image/png" />
    </context>
  </body>
</ncl>
''';
        final doc = NclDocument.fromContent(nclXml);
        doc.start();
        doc.tick(100);

        final activeCtrl = DataBindingMediaPlugin.obtainController(
          document: doc,
          media: doc.getMediaById('mMatrix'),
          explicitContextId: 'activeCtx',
          initialData: {
            'categories': ['Sci-Fi', 'Action', 'Drama', 'Docs'],
            'movies': [
              ['Orbit 1', 'Orbit 2', 'Orbit 3'],
              ['Pulse 1', 'Pulse 2', 'Pulse 3'],
            ],
          },
        );
        final otherCtrl = DataBindingMediaPlugin.obtainController(
          document: doc,
          media: doc.getMediaById('mOther'),
          explicitContextId: 'otherCtx',
          initialData: {
            'movies': [
              ['Other 1', 'Other 2', 'Other 3'],
              ['Other 4', 'Other 5', 'Other 6'],
            ],
          },
        );

        final widgets = doc
            .getActiveMedia()
            .map((m) => NclWidget.createMediaWidget(media: m, document: doc))
            .whereType<Widget>()
            .toList();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1280,
                height: 720,
                child: Stack(children: widgets),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('Sci-Fi'), findsWidgets);
        expect(find.textContaining('Orbit 1'), findsWidgets);

        doc.handleKey('CURSOR_RIGHT');
        doc.handleKey('CURSOR_DOWN');
        await tester.pump();

        expect(activeCtrl.focusedCol, equals(1));
        expect(activeCtrl.focusedRow, equals(1));
        expect(otherCtrl.focusedCol, equals(0));
        expect(otherCtrl.focusedRow, equals(0));
        doc.stop();
      },
    );

    test('NclParserPlugin validates Extended NCL schema and synthesizes ports for all 3 data-binding examples', () {
      const exampleNames = [
        'hero_carousel.ncl',
        'epg_grid.ncl',
        'sports_overlay.ncl',
      ];
      for (final fileName in exampleNames) {
        final candidates = [
          File('../../examples/data-binding/$fileName'),
          File('examples/data-binding/$fileName'),
        ];
        final file = candidates.firstWhere((f) => f.existsSync());
        final xml = file.readAsStringSync();
        final validationErrors = NclParser().validate(xml);
        expect(validationErrors, isEmpty, reason: 'Failed validation for $fileName');

        final doc = NclDocument.fromContent(xml, appSrc: fileName);
        doc.start();
        doc.tick(100);
        expect(doc.getActiveMedia(), isNotEmpty, reason: 'No active media in $fileName');
        doc.stop();
      }
    });

    testWidgets(
      'HardwareKeyboard navigation with NclDocument advances exactly 1 step per key press without duplication',
      (tester) async {
        final epgCandidates = [
          File('../../examples/data-binding/epg_grid.ncl'),
          File('examples/data-binding/epg_grid.ncl'),
        ];
        final luaCandidates = [
          File('../../examples/data-binding/epg_grid.lua'),
          File('examples/data-binding/epg_grid.lua'),
        ];
        final epgXml = epgCandidates.firstWhere((f) => f.existsSync()).readAsStringSync();
        final epgLua = luaCandidates.firstWhere((f) => f.existsSync()).readAsStringSync();
        final parsedData = DataBindingLuaRuntime().execute(epgLua);

        final doc = NclDocument.fromContent(epgXml, appSrc: 'epg_grid.ncl');
        doc.start();
        doc.tick(100);

        final activeMedias = doc.getActiveMedia();
        final ctrl = DataBindingMediaPlugin.obtainController(
          document: doc,
          media: activeMedias.first,
          explicitContextId: 'epgContext',
          initialData: parsedData,
        );

        bool hostKeyHandler(KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              doc.handleKey('RIGHT');
              return true;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              doc.handleKey('LEFT');
              return true;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              doc.handleKey('DOWN');
              return true;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              doc.handleKey('UP');
              return true;
            }
          }
          return false;
        }

        HardwareKeyboard.instance.addHandler(hostKeyHandler);
        addTearDown(() => HardwareKeyboard.instance.removeHandler(hostKeyHandler));

        final widgets = activeMedias
            .map((m) => NclWidget.createMediaWidget(media: m, document: doc))
            .whereType<Widget>()
            .toList();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1280,
                height: 720,
                child: Stack(children: widgets),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(ctrl.focusedRow, equals(0));
        expect(ctrl.focusedCol, equals(0));

        await tester.tap(find.text('102 SBT HD'));
        await tester.pump();
        expect(ctrl.focusedRow, equals(1));
        expect(ctrl.focusedCol, equals(0));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(ctrl.focusedRow, equals(1));
        expect(ctrl.focusedCol, equals(1));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(ctrl.focusedRow, equals(1));
        expect(ctrl.focusedCol, equals(2));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(ctrl.focusedRow, equals(1));
        expect(ctrl.focusedCol, equals(1));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(ctrl.focusedRow, equals(2));
        expect(ctrl.focusedCol, equals(1));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(ctrl.focusedRow, equals(1));
        expect(ctrl.focusedCol, equals(1));

        for (final container in tester.widgetList<Container>(find.byType(Container))) {
          final dec = container.decoration;
          if (dec is BoxDecoration) {
            expect(dec.borderRadius, isNull);
          }
        }

        doc.stop();
      },
    );

    test(
      'EPG grid aligns channel rail region top/height with program grid and hero_carousel selects real video URL',
      () {
        final epgCandidates = [
          File('../../examples/data-binding/epg_grid.ncl'),
          File('examples/data-binding/epg_grid.ncl'),
        ];
        final epgXml =
            epgCandidates.firstWhere((f) => f.existsSync()).readAsStringSync();
        final epgDoc = NclDocument.fromContent(epgXml, appSrc: 'epg_grid.ncl');
        epgDoc.start();
        epgDoc.tick(100);

        final channelItem = epgDoc.getMediaById('chItem')!;
        final programCell = epgDoc.getMediaById('progItem')!;
        expect(
          channelItem.rawAttributes['resolvedTop'],
          equals(programCell.rawAttributes['resolvedTop']),
        );
        expect(
          channelItem.rawAttributes['resolvedHeight'],
          equals(programCell.rawAttributes['resolvedHeight']),
        );
        expect(channelItem.rawAttributes['regionRows'], equals('6'));
        expect(programCell.rawAttributes['regionRows'], equals('6'));
        epgDoc.stop();

        final heroCandidates = [
          File('../../examples/data-binding/hero_carousel.ncl'),
          File('examples/data-binding/hero_carousel.ncl'),
        ];
        final moviesCandidates = [
          File('../../examples/data-binding/hero_carousel.lua'),
          File('examples/data-binding/hero_carousel.lua'),
        ];
        final heroXml = heroCandidates
            .firstWhere((f) => f.existsSync())
            .readAsStringSync();
        final moviesLua = moviesCandidates
            .firstWhere((f) => f.existsSync())
            .readAsStringSync();
        final parsedMovies = DataBindingLuaRuntime().execute(moviesLua);

        final heroDoc =
            NclDocument.fromContent(heroXml, appSrc: 'hero_carousel.ncl');
        heroDoc.start();
        heroDoc.tick(100);

        final movieMedia = heroDoc.getMediaById('movie')!;
        final heroCtrl = DataBindingMediaPlugin.obtainController(
          document: heroDoc,
          media: movieMedia,
          explicitContextId: 'catalog',
          initialData: parsedMovies,
        );
        expect(heroCtrl.hasIndependentRowHorizontalScroll, isTrue);

        final videoMedia = heroDoc.getMediaById('videoPlayer')!;
        heroDoc.handleKey('RIGHT');
        heroDoc.handleKey('RIGHT');
        heroDoc.handleKey('RIGHT');
        heroDoc.handleKey('RIGHT');
        expect(heroCtrl.rowColOffsetForRow(0), equals(1));
        expect(heroCtrl.rowColOffsetForRow(1), equals(0));
        expect(heroCtrl.focusedCol, equals(4));

        heroDoc.handleKey('DOWN');
        expect(heroCtrl.focusedRow, equals(1));
        expect(heroCtrl.focusedCol, equals(3));

        heroDoc.handleKey('UP');
        expect(heroCtrl.focusedRow, equals(0));
        expect(heroCtrl.focusedCol, equals(4));

        heroDoc.handleKey('LEFT');
        heroDoc.handleKey('LEFT');
        heroDoc.handleKey('LEFT');
        heroDoc.handleKey('LEFT');
        heroDoc.tick(100);
        expect(videoMedia.getMainState(), equals(NclStateType.sleeping));

        heroDoc.handleKey('ENTER');
        heroDoc.tick(100);

        expect(videoMedia.getMainState(), equals(NclStateType.occurring));
        expect(videoMedia.rawAttributes['resolvedLeft'], equals('0.00%'));
        expect(videoMedia.rawAttributes['resolvedTop'], equals('0.00%'));
        expect(videoMedia.rawAttributes['resolvedWidth'], equals('100.00%'));
        expect(videoMedia.rawAttributes['resolvedHeight'], equals('45.00%'));
        final resolvedVideoUrl = videoMedia.rawAttributes['resolvedSrc'] ?? '';
        expect(
          resolvedVideoUrl,
          equals(
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
          ),
        );

        heroDoc.handleKey('RIGHT');
        heroDoc.tick(100);
        expect(
          videoMedia.rawAttributes['resolvedSrc'],
          equals(
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
          ),
        );

        heroDoc.handleKey('ENTER');
        heroDoc.tick(100);
        expect(
          videoMedia.rawAttributes['resolvedSrc'],
          equals(
            'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
          ),
        );

        final videoWidget = NclWidget.createMediaWidget(
          media: videoMedia,
          document: heroDoc,
        );
        expect(videoWidget, isA<DataBindingWidget>());
        expect(AVWidget, isNotNull);
        heroDoc.stop();
      },
    );

    test(
      'preserves all descriptor, descriptorParam, and region properties on Media elements and DataBindingController',
      () {
        const xml = '''
<ncl id="propPreserveApp" xmlns="http://www.ncl.org.br/NCL3.0/EDTV">
  <head>
    <regionBase>
      <region id="rParent" left="5%" top="10%" width="90%" height="80%" rows="4" scroll="vertical" wrap="true" bufferSlots="3" zIndex="2">
        <region id="rChild" left="10%" top="20%" width="80%" height="50%" columns="5" scroll="horizontal" title="Carousel Grid" zIndex="5" />
      </region>
    </regionBase>
    <descriptorBase>
      <descriptor id="dChild" region="rChild" focusIndex="1" focusBorderColor="#00FF00" focusBorderWidth="4" selBorderColor="#FF0000" transIn="trFade" explicitDur="5s">
        <descriptorParam name="fontColor" value="#FFFF00" />
        <descriptorParam name="fontSize" value="16" />
        <descriptorParam name="background" value="#121212" />
      </descriptor>
    </descriptorBase>
  </head>
  <body>
    <port id="pMain" component="ctx" />
    <media id="settings" type="application/x-ginga-settings">
      <property name="service.currentKeyMaster" value="ctx" />
    </media>
    <context id="ctx" data-binding="hero_carousel.lua">
      <media id="mGrid" src="{movies[row][column]}" descriptor="dChild" type="text/plain" />
    </context>
  </body>
</ncl>
''';
        final doc = NclDocument.fromContent(xml);
        doc.start();
        doc.tick(100);

        final m = doc.getMediaById('mGrid')!;
        final ctrl = DataBindingMediaPlugin.obtainController(
          document: doc,
          media: m,
        );

        expect(ctrl.visibleRows, equals(4));
        expect(ctrl.visibleColumns, equals(5));
        expect(ctrl.scrollMode, equals(ScrollDirectionMode.both));
        expect(ctrl.wrap, isTrue);
        expect(ctrl.bufferSlots, equals(3));

        expect(m.rawAttributes['regionId'], equals('rChild'));
        expect(m.rawAttributes['regionTitle'], equals('Carousel Grid'));
        expect(m.rawAttributes['regionColumns'], equals('5'));
        expect(m.rawAttributes['regionScroll'], equals('horizontal'));
        expect(m.rawAttributes['parentRegionId'], equals('rParent'));
        expect(m.rawAttributes['parentRegionRows'], equals('4'));
        expect(m.rawAttributes['parentRegionScroll'], equals('vertical'));
        expect(m.rawAttributes['parentRegionWrap'], equals('true'));
        expect(m.rawAttributes['parentRegionBufferSlots'], equals('3'));
        expect(m.rawAttributes['resolvedZIndex'], equals('5'));

        expect(m.rawAttributes['focusIndex'], equals('1'));
        expect(m.rawAttributes['focusBorderColor'], equals('#00FF00'));
        expect(m.rawAttributes['focusBorderWidth'], equals('4'));
        expect(m.rawAttributes['selBorderColor'], equals('#FF0000'));
        expect(m.rawAttributes['transIn'], equals('trFade'));

        expect(m.rawAttributes['descriptorParam.fontColor'], equals('#FFFF00'));
        expect(m.rawAttributes['descriptorParam.fontSize'], equals('16'));
        expect(m.rawAttributes['descriptorParam.background'], equals('#121212'));
        expect(doc.getPropertyValue(m, 'fontColor'), equals('#FFFF00'));

        doc.stop();
      },
    );

    test(
      'DataBindingLuaRuntime executes real Lua code with loops, functions, and standard libraries',
      () {
        const dynamicLuaScript = '''
local data = {
  category = {},
  movies = {}
}

function buildRow(rowIdx, cols)
  local row = {}
  for c = 1, cols do
    row[c] = string.format("r%d_c%d.png", rowIdx, c)
  end
  return row
end

for r = 1, 3 do
  table.insert(data.category, string.format("Genre %d", r * 10))
  data.movies[r] = buildRow(r, 4)
end

function addGenre(name)
  table.insert(data.category, name)
  data.movies[#data.category] = buildRow(#data.category, 4)
  return data
end

return data
''';

        final ctrl = DataBindingController(
          contextId: 'lua_vm_ctx',
          visibleRows: 3,
          visibleColumns: 4,
        );
        ctrl.executeLua(dynamicLuaScript);

        expect(
          ctrl.data['category'],
          equals(['Genre 10', 'Genre 20', 'Genre 30']),
        );
        final movies = ctrl.data['movies'] as List;
        expect(movies.length, equals(3));
        expect(
          movies[0],
          equals(['r1_c1.png', 'r1_c2.png', 'r1_c3.png', 'r1_c4.png']),
        );
        expect(
          movies[2],
          equals(['r3_c1.png', 'r3_c2.png', 'r3_c3.png', 'r3_c4.png']),
        );

        final updated = ctrl.luaRuntime.callLuaFunction('addGenre', ['Sci-Fi']);
        ctrl.updateData(updated);
        expect(ctrl.totalRows, equals(4));
        expect((ctrl.data['category'] as List)[3], equals('Sci-Fi'));
        expect(
          (ctrl.data['movies'] as List)[3],
          equals(['r4_c1.png', 'r4_c2.png', 'r4_c3.png', 'r4_c4.png']),
        );

        ctrl.dispose();
      },
    );
  });
}
