import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/gingacc.dart';
import 'package:playground/playground.dart';

void main() {
  tearDown(() {
    catalogExamplesBaseUrl = defaultCatalogExamplesBaseUrl;
  });
  const sampleNcl = '<ncl><body/></ncl>';

  final testExamples = [
    const CatalogExample(
      key: 'video',
      mainFile: 'video.ncl',
      category: 'general',
      description: 'Video presentation example',
    ),
    const CatalogExample(
      key: 'image',
      mainFile: 'image.ncl',
      category: 'general',
      description: 'Image presentation example',
    ),
  ];

  group('PlaygroundEditor Catalog Selection Tests', () {
    testWidgets('shows catalog selector when showCatalogSelector is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              showCatalogSelector: true,
              catalogExamples: testExamples,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('catalog_select')), findsOneWidget);
      expect(find.text('Catalog'), findsOneWidget);
    });

    testWidgets('hides catalog selector when showCatalogSelector is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              filePath: 'video.ncl',
              showCatalogSelector: false,
              content: sampleNcl,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('catalog_select')), findsNothing);
      expect(find.text('video.ncl'), findsOneWidget);
    });

    testWidgets('defaults showCatalogSelector to true when filePath is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              catalogExamples: testExamples,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('catalog_select')), findsOneWidget);
    });

    testWidgets(
        'defaults showCatalogSelector to false when filePath is provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              filePath: 'test.ncl',
              content: sampleNcl,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('catalog_select')), findsNothing);
      expect(find.text('test.ncl'), findsOneWidget);
    });

    testWidgets(
        'selecting an item from catalog dropdown loads file content into editor',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('ginga_pg_sel1_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      File('${tempDir.path}/video.ncl')
          .writeAsStringSync('<ncl><body id="video_body"/></ncl>');
      File('${tempDir.path}/image.ncl')
          .writeAsStringSync('<ncl><body id="image_body"/></ncl>');
      catalogExamplesBaseUrl = tempDir.uri.toString();

      final gingacc = GingaCC();

      String? lastChangedContent;
      String? lastSelectedExample;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              gingacc: gingacc,
              catalogExamples: testExamples,
              showCatalogSelector: true,
              onContentChanged: (c) => lastChangedContent = c,
              onCatalogExampleSelected: (e) => lastSelectedExample = e,
            ),
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.effectiveContent, isEmpty);

      await state.selectCatalogExample('video.ncl');
      await tester.pump();

      expect(state.effectiveFilePath, equals('video.ncl'));
      expect(state.selectedExample, equals('video.ncl'));
      expect(state.effectiveContent, contains('video_body'));
      expect(lastChangedContent, contains('video_body'));
      expect(lastSelectedExample, equals('video.ncl'));

      final textField = tester
          .widget<TextField>(find.byKey(const Key('monaco_editor_text_field')));
      expect(textField.controller?.text, contains('video_body'));

      await state.selectCatalogExample('image.ncl');
      await tester.pump();

      expect(state.effectiveFilePath, equals('image.ncl'));
      expect(state.selectedExample, equals('image.ncl'));
      expect(state.effectiveContent, contains('image_body'));
      expect(lastChangedContent, contains('image_body'));
      expect(lastSelectedExample, equals('image.ncl'));
    });

    testWidgets('shows placeholder when empty and catalog selection is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              catalogExamples: testExamples,
              showCatalogSelector: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(
            'Select an example from the catalog above to view and run code'),
        findsOneWidget,
      );
    });

    testWidgets(
        'opens catalog left sidebar list organized by category and supports item click, category filtering, and keyboard navigation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('ginga_pg_sel2_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      File('${tempDir.path}/video360/main.ncl360')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('<ncl id="v360"><body/></ncl>');
      File('${tempDir.path}/video.ncl')
          .writeAsStringSync('<ncl id="vid"><body/></ncl>');
      File('${tempDir.path}/image.ncl')
          .writeAsStringSync('<ncl id="img"><body/></ncl>');
      File('${tempDir.path}/lua/zip_list/main.ncl')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('<ncl id="luazip"><body/></ncl>');
      catalogExamplesBaseUrl = tempDir.uri.toString();

      final gingacc = GingaCC();

      final categorizedExamples = [
        const CatalogExample(
          key: 'video360',
          mainFile: 'video360/main.ncl360',
          category: 'video 360',
          description: 'Interactive 360 presentation',
        ),
        const CatalogExample(
          key: 'video',
          mainFile: 'video.ncl',
          category: 'general',
          description: 'Video presentation example',
        ),
        const CatalogExample(
          key: 'image',
          mainFile: 'image.ncl',
          category: 'general',
          description: 'Image presentation example',
        ),
        const CatalogExample(
          key: 'lua_zip_list',
          mainFile: 'lua/zip_list/main.ncl',
          category: 'lua',
          description: 'Lua zip helper example',
          otherEditableFiles: ['main.lua'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              gingacc: gingacc,
              catalogExamples: categorizedExamples,
              showCatalogSelector: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('monaco_editor_text_field')), findsOneWidget);

      await tester.tap(find.byKey(const Key('catalog_select')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('catalog_grid_dialog')), findsOneWidget);
      expect(find.byKey(const Key('monaco_editor_text_field')), findsOneWidget);
      final editorRect = tester.getRect(find.byType(PlaygroundEditor));
      final catalogRect =
          tester.getRect(find.byKey(const Key('catalog_grid_dialog')));
      final textFieldRect =
          tester.getRect(find.byKey(const Key('monaco_editor_text_field')));
      expect(catalogRect.left, equals(editorRect.left));
      expect(catalogRect.right, lessThan(editorRect.right));
      expect(textFieldRect.left, greaterThanOrEqualTo(catalogRect.right));
      final videoItemRect =
          tester.getRect(find.byKey(const Key('catalog_option_video')));
      final imageItemRect =
          tester.getRect(find.byKey(const Key('catalog_option_image')));
      expect(videoItemRect.left, equals(imageItemRect.left));
      expect(imageItemRect.top, greaterThan(videoItemRect.top));
      expect(find.text('Application Catalog'), findsOneWidget);
      expect(find.text('VIDEO 360'), findsOneWidget);
      expect(find.text('GENERAL'), findsOneWidget);
      expect(find.text('LUA'), findsOneWidget);

      await tester.tap(find.byKey(const Key('catalog_category_chip_lua')));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('catalog_option_lua_zip_list')), findsOneWidget);
      expect(find.byKey(const Key('catalog_option_video')), findsNothing);

      await tester.tap(find.byKey(const Key('catalog_category_chip_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog_option_video')), findsOneWidget);

      await tester.tap(find.byKey(const Key('catalog_option_image')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('catalog_grid_dialog')), findsNothing);
      final state =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.selectedExample, equals('image.ncl'));
      expect(state.effectiveContent, contains('id="img"'));
      expect(find.text('image.ncl'), findsOneWidget);

      await tester.tap(find.byKey(const Key('catalog_select')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog_grid_dialog')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('catalog_grid_dialog')), findsNothing);
      expect(state.selectedExample, equals('lua/zip_list/main.ncl'));
      expect(state.effectiveContent, contains('id="luazip"'));

      await tester.tap(find.byKey(const Key('catalog_select')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog_grid_dialog')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('catalog_grid_dialog')), findsNothing);
    });

    testWidgets(
        'displays short filename for URL filePath and hides catalog selector',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              filePath:
                  'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/video.ncl',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('catalog_select')), findsNothing);
      expect(find.text('video.ncl'), findsOneWidget);
    });

    testWidgets(
        'displays GingaPlayground banner for standalone app and catalog mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              filePath: 'video.ncl',
              showCatalogSelector: false,
              content: sampleNcl,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('GingaPlayground'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              catalogExamples: testExamples,
              showCatalogSelector: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('GingaPlayground'), findsOneWidget);
    });

    testWidgets('disables debug icon for HTML application',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              filePath: 'image.html',
              content:
                  '<!DOCTYPE html><html><body><h1>Hello</h1></body></html>',
            ),
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.isHtmlApplication, isTrue);
      expect(state.canDebug, isFalse);

      final debugButton = tester.widget<IconButton>(
          find.byKey(const Key('monaco_debug_start_button')));
      expect(debugButton.onPressed, isNull);
      expect(debugButton.tooltip, equals('Debugging not supported for HTML'));
    });

    testWidgets('restricts breakpoints to NCL application only',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              filePath: 'image.html',
              content: '<html>\n<body>\n<h1>Hello</h1>\n</body>\n</html>',
            ),
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.isNclApplication, isFalse);

      state.toggleBreakpoint(2);
      await tester.pump();
      expect(state.breakpoints, isEmpty);

      state.setBreakpoints([2, 3]);
      await tester.pump();
      expect(state.breakpoints, isEmpty);
    });

    testWidgets(
        'shows tabs with editableFiles from catalog and switches between them',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('ginga_pg_sel3_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      File('${tempDir.path}/sbtvd/main.ncl')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('<ncl><body id="sbtvd_body"/></ncl>');
      File('${tempDir.path}/sbtvd/ginga_config.json')
          .writeAsStringSync('{"mainAvSrc": "test.mp4"}');
      catalogExamplesBaseUrl = tempDir.uri.toString();

      final gingacc = GingaCC();

      final multiFileExamples = [
        const CatalogExample(
          key: 'sbtvd',
          mainFile: 'sbtvd/main.ncl',
          category: 'general',
          description: 'SBTVD broadcast video example',
          otherEditableFiles: ['ginga_config.json'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              gingacc: gingacc,
              catalogExamples: multiFileExamples,
              showCatalogSelector: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      await state.selectCatalogExample('sbtvd/main.ncl');
      await tester.pumpAndSettle();

      expect(state.editableFiles,
          equals(['sbtvd/main.ncl', 'sbtvd/ginga_config.json']));

      expect(find.byKey(const Key('file_tab_main.ncl')), findsOneWidget);
      expect(
          find.byKey(const Key('file_tab_ginga_config.json')), findsOneWidget);

      expect(state.activeFilePath, equals('sbtvd/main.ncl'));
      expect(state.effectiveContent, contains('sbtvd_body'));
      expect(find.text('NCL'), findsOneWidget);

      await tester.tap(find.byKey(const Key('file_tab_ginga_config.json')));
      await tester.pumpAndSettle();

      expect(state.activeFilePath, equals('sbtvd/ginga_config.json'));
      expect(state.effectiveContent, contains('test.mp4'));
      expect(find.text('JSON'), findsOneWidget);

      expect(state.allFileContents.containsKey('sbtvd/main.ncl'), isTrue);
      expect(
          state.allFileContents.containsKey('sbtvd/ginga_config.json'), isTrue);
    });

    testWidgets(
        'reselecting a catalog item reloads fresh content instead of keeping local edits',
        (WidgetTester tester) async {
      final tempDir = Directory.systemTemp.createTempSync('ginga_pg_reselect_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      File('${tempDir.path}/dirA/main.ncl')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('<ncl id="origA"/>');
      catalogExamplesBaseUrl = tempDir.uri.toString();

      final gingacc = GingaCC(
        config: GingaConfig(enablePlayground: true),
      );
      final examples = [
        const CatalogExample(key: 'dirA', mainFile: 'dirA/main.ncl'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              gingacc: gingacc,
              catalogExamples: examples,
              showCatalogSelector: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      await state.selectCatalogExample('dirA/main.ncl');
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('monaco_editor_text_field')),
        '<ncl id="editedA"/>',
      );
      await tester.pump();
      expect(state.allFileContents['dirA/main.ncl'],
          equals('<ncl id="editedA"/>'));

      await state.selectCatalogExample('dirA/main.ncl');
      await tester.pumpAndSettle();
      expect(state.effectiveContent, equals('<ncl id="origA"/>'));
    });
  });
}
