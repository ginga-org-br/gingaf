import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/gingacc.dart';
import 'package:playground/playground.dart';

void main() {
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
      expect(find.text('Catalog:'), findsOneWidget);
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

    testWidgets('defaults showCatalogSelector to false when filePath is provided',
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

    testWidgets('selecting an item from catalog dropdown loads file content into editor',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final gingacc = GingaCC();
      gingacc.setVirtualFiles({
        'examples/video.ncl': '<ncl><body id="video_body"/></ncl>',
        'examples/image.ncl': '<ncl><body id="image_body"/></ncl>',
      });

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

      final state = tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.effectiveContent, isEmpty);

      await state.selectCatalogExample('video.ncl');
      await tester.pump();

      expect(state.effectiveFilePath, equals('video.ncl'));
      expect(state.selectedExample, equals('video.ncl'));
      expect(state.effectiveContent, contains('video_body'));
      expect(lastChangedContent, contains('video_body'));
      expect(lastSelectedExample, equals('video.ncl'));

      final textField = tester.widget<TextField>(find.byKey(const Key('monaco_editor_text_field')));
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
        find.text('Select an example from the catalog above to view and run code'),
        findsOneWidget,
      );
    });

    testWidgets('groups catalog items by category and renders category header in dropdown',
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

      await tester.tap(find.byKey(const Key('catalog_select')));
      await tester.pumpAndSettle();

      expect(find.text('-- GENERAL --'), findsWidgets);
    });

    testWidgets('displays short filename for URL filePath and hides catalog selector',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              filePath: 'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/examples/video.ncl',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('catalog_select')), findsNothing);
      expect(find.text('video.ncl'), findsOneWidget);
    });

    testWidgets(
        'displays GingaPlayground (powered by gingaf) banner for standalone app and catalog mode',
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
      expect(find.text('GingaPlayground (powered by gingaf)'), findsOneWidget);

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
      expect(find.text('GingaPlayground (powered by gingaf)'), findsOneWidget);
    });

    testWidgets('disables debug icon for HTML application',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              filePath: 'image.html',
              content: '<!DOCTYPE html><html><body><h1>Hello</h1></body></html>',
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

      final gingacc = GingaCC();
      gingacc.setVirtualFiles({
        'examples/sbtvd/main.ncl': '<ncl><body id="sbtvd_body"/></ncl>',
        'examples/sbtvd/ginga_config.json': '{"mainAvSrc": "test.mp4"}',
      });

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
  });
}
