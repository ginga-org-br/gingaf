import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playground/playground.dart';

void main() {
  const sampleNcl = '''<ncl>
  <body>
    <port id="p1" component="video1"/>
    <media id="video1" src="movie.mp4">
      <area id="a1" begin="2s" end="4s"/>
    </media>
    <media id="banner" src="img.png"/>
    <link id="l1">
      <bind role="onBegin" component="video1" interface="a1"/>
      <bind role="start" component="banner"/>
    </link>
  </body>
</ncl>''';

  group('PlaygroundEditor Widget (Monaco Editor)', () {
    testWidgets('renders Monaco editor with gutter, line numbers, and debug actions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              content: sampleNcl,
              filePath: 'test.ncl',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Monaco Editor'), findsOneWidget);
      expect(find.text('test.ncl'), findsOneWidget);
      expect(find.byKey(const Key('monaco_editor_text_field')), findsOneWidget);
      expect(find.byKey(const Key('monaco_debug_start_button')), findsOneWidget);
      expect(find.byKey(const Key('monaco_gutter_line_4')), findsOneWidget);
      expect(find.byKey(const Key('monaco_gutter_line_7')), findsOneWidget);
    });

    testWidgets('toggles breakpoints on gutter line tap in Monaco editor',
        (WidgetTester tester) async {
      final breakpointsChanged = <List<int>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              content: sampleNcl,
              filePath: 'test.ncl',
              onBreakpointsChanged: breakpointsChanged.add,
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.breakpoints, isEmpty);

      // Tap line 4 in Monaco gutter to set breakpoint
      await tester.tap(find.byKey(const Key('monaco_gutter_line_4')));
      await tester.pump();

      expect(state.breakpoints, contains(4));
      expect(breakpointsChanged.last, equals([4]));

      // Tap line 7 in Monaco gutter
      await tester.tap(find.byKey(const Key('monaco_gutter_line_7')));
      await tester.pump();

      expect(state.breakpoints, containsAll([4, 7]));
      expect(breakpointsChanged.last, equals([4, 7]));

      // Tap line 4 again to remove breakpoint
      await tester.tap(find.byKey(const Key('monaco_gutter_line_4')));
      await tester.pump();

      expect(state.breakpoints.contains(4), isFalse);
      expect(state.breakpoints, contains(7));
      expect(breakpointsChanged.last, equals([7]));
    });

    testWidgets('simulates time passing with tick while debugging in Monaco editor',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              content: sampleNcl,
              filePath: 'test.ncl',
              initialBreakpoints: [4, 7],
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.breakpoints, containsAll([4, 7]));
      expect(state.isDebugging, isFalse);

      // Start debugging from Monaco editor toolbar
      await tester.tap(find.byKey(const Key('monaco_debug_start_button')));
      await tester.pump();

      expect(state.isDebugging, isTrue);
      expect(state.isPaused, isTrue);
      expect(state.currentDebugLine, equals(4));
      expect(state.virtualClock, equals(0));
      expect(find.byKey(const Key('monaco_debug_step_button')), findsNothing);
      expect(find.byKey(const Key('monaco_debug_continue_button')), findsOneWidget);

      state.tick(1000);
      await tester.pump();

      expect(state.virtualClock, equals(1000));
      expect(state.isPaused, isFalse);

      state.tick(1000);
      await tester.pump();

      // At 2000ms, link l1 fires and starts banner (line 7), hitting breakpoint
      expect(state.virtualClock, equals(2000));
      expect(state.isPaused, isTrue);
      expect(state.currentDebugLine, equals(7));

      // Stop debugging
      await tester.tap(find.byKey(const Key('monaco_stop_button')));
      await tester.pump();

      expect(state.isDebugging, isFalse);
      expect(state.currentDebugLine, isNull);
    });

    testWidgets('steps and continues debugging timeline with tick in Monaco editor',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              content: sampleNcl,
              filePath: 'test.ncl',
              initialBreakpoints: [7],
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));

      // Start debugging
      state.startDebugging();
      await tester.pump();

      expect(state.isDebugging, isTrue);
      expect(state.isPaused, isFalse);
      expect(state.virtualClock, equals(0));

      // Step by 500ms
      state.step(500);
      await tester.pump();

      expect(state.virtualClock, equals(500));
      expect(state.isPaused, isFalse);

      // Step by 1500ms using state.step(1500) -> reaches 2000ms hitting line 7 breakpoint
      state.step(1500);
      await tester.pump();

      expect(state.virtualClock, equals(2000));
      expect(state.isPaused, isTrue);
      expect(state.currentDebugLine, equals(7));

      // Continue execution
      state.continueExecution();
      await tester.pump();

      // Stop debugging
      state.stopDebugging();
      await tester.pump();
      expect(state.isDebugging, isFalse);
    });

    const videoNcl = '''<ncl>
  <body>
    <port id="init" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4">
      <area id="a1" begin="2s" end="4s"/>
    </media>
    <media id="green_bg">
      <property name="background" value="green"/>
      <property name="bounds" value="0%,80%,20%,20%"/>
    </media>
    <media id="red_bg">
      <property name="background" value="red"/>
      <property name="bounds" value="80%,80%,20%,20%"/>
      <property name="explicitDur" value="2s"/>
    </media>
    <link id="l1">
      <bind role="onBegin" component="video" interface="a1"/>
      <bind role="start" component="green_bg"/>
    </link>
    <link id="l2">
      <bind role="onEnd" component="video" interface="a1"/>
      <bind role="stop" component="green_bg"/>
      <bind role="start" component="red_bg"/>
    </link>
  </body>
</ncl>''';

    testWidgets(
        'pauses execution when breakpoint media starts using PlaygroundEditor',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              content: videoNcl,
              filePath: 'video.ncl',
              initialBreakpoints: [4],
            ),
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.breakpoints, contains(4));
      expect(state.isDebugging, isFalse);

      await tester.tap(find.byKey(const Key('monaco_debug_start_button')));
      await tester.pump();

      expect(state.isDebugging, isTrue);
      expect(state.isPaused, isTrue);
      expect(state.currentDebugLine, equals(4));
      expect(find.byIcon(Icons.arrow_right), findsOneWidget);

      state.continueExecution();
      await tester.pump();
      expect(state.isPaused, isFalse);

      state.tick(1000);
      await tester.pump();
      expect(state.virtualClock, equals(1000));
      expect(state.isPaused, isFalse);
    });

    testWidgets(
        'pauses execution when subsequent breakpoint media starts on link trigger using PlaygroundEditor',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              content: videoNcl,
              filePath: 'video.ncl',
              initialBreakpoints: [7],
            ),
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.breakpoints, contains(7));

      await tester.tap(find.byKey(const Key('monaco_debug_start_button')));
      await tester.pump();

      expect(state.isDebugging, isTrue);
      expect(state.isPaused, isFalse);
      expect(state.virtualClock, equals(0));

      state.tick(2500);
      await tester.pump();

      expect(state.isPaused, isTrue);
      expect(state.currentDebugLine, equals(7));
      expect(find.byIcon(Icons.arrow_right), findsOneWidget);
    });

    testWidgets(
        'pauses execution when breakpoint media stops on link trigger using PlaygroundEditor',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              content: videoNcl,
              filePath: 'video.ncl',
              initialBreakpoints: [22],
            ),
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.breakpoints, contains(22));

      await tester.tap(find.byKey(const Key('monaco_debug_start_button')));
      await tester.pump();

      expect(state.isDebugging, isTrue);
      expect(state.isPaused, isFalse);

      state.tick(2500);
      await tester.pump();

      expect(state.isPaused, isTrue);
      expect(state.currentDebugLine, equals(22));

      state.continueExecution();
      await tester.pump();
      expect(state.isPaused, isFalse);

      state.tick(2000);
      await tester.pump();

      expect(state.isPaused, isTrue);
      expect(state.currentDebugLine, equals(22));
    });

    testWidgets(
        'pauses execution when breakpoint is set on port element using PlaygroundEditor',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              content: videoNcl,
              filePath: 'video.ncl',
              initialBreakpoints: [3],
            ),
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.breakpoints, contains(3));

      await tester.tap(find.byKey(const Key('monaco_debug_start_button')));
      await tester.pump();

      expect(state.isDebugging, isTrue);
      expect(state.isPaused, isTrue);
      expect(state.currentDebugLine, equals(3));
      expect(find.byIcon(Icons.arrow_right), findsOneWidget);
    });

    testWidgets(
        'pauses execution when breakpoint is toggled via gutter tap during active debugging session in PlaygroundEditor',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              content: videoNcl,
              filePath: 'video.ncl',
            ),
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.breakpoints, isEmpty);

      await tester.tap(find.byKey(const Key('monaco_debug_start_button')));
      await tester.pump();

      expect(state.isDebugging, isTrue);
      expect(state.isPaused, isFalse);

      await tester.tap(find.byKey(const Key('monaco_gutter_line_7')));
      await tester.pump();

      expect(state.breakpoints, contains(7));

      state.tick(2500);
      await tester.pump();

      expect(state.isPaused, isTrue);
      expect(state.currentDebugLine, equals(7));
    });

    testWidgets('toolbar buttons reflect enabled and disabled states for idle, running, and debugging',
        (WidgetTester tester) async {
      bool stopCalled = false;
      bool runCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              content: videoNcl,
              filePath: 'video.ncl',
              isRunning: false,
              onStop: () => stopCalled = true,
              onRun: () => runCalled = true,
            ),
          ),
        ),
      );
      await tester.pump();

      final runBtnIdle = tester.widget<IconButton>(find.byKey(const Key('monaco_run_button')));
      final debugBtnIdle = tester.widget<IconButton>(find.byKey(const Key('monaco_debug_start_button')));

      expect(runBtnIdle.onPressed, isNotNull);
      expect(debugBtnIdle.onPressed, isNotNull);
      expect(find.byKey(const Key('monaco_stop_button')), findsNothing);
      expect(find.byKey(const Key('monaco_debug_continue_button')), findsNothing);

      await tester.tap(find.byKey(const Key('monaco_run_button')));
      await tester.pump();
      expect(runCalled, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              key: const Key('editor_debug'),
              content: videoNcl,
              filePath: 'video.ncl',
              initialBreakpoints: [4],
              onStop: () => stopCalled = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('monaco_debug_start_button')));
      await tester.pump();

      final runBtnRunning = tester.widget<IconButton>(find.byKey(const Key('monaco_run_button')));
      final debugBtnRunning = tester.widget<IconButton>(find.byKey(const Key('monaco_debug_start_button')));
      final stopBtnRunning = tester.widget<IconButton>(find.byKey(const Key('monaco_stop_button')));

      expect(runBtnRunning.onPressed, isNull);
      expect(debugBtnRunning.onPressed, isNull);
      expect(stopBtnRunning.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('monaco_stop_button')));
      await tester.pump();
      expect(stopCalled, isTrue);
    });

    testWidgets('toolbar enables continue and stop buttons and disables run and debug during debugging',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              content: videoNcl,
              filePath: 'video.ncl',
              initialBreakpoints: [4, 7],
              isRunning: false,
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.canDebug, isTrue);
      expect(state.canStop, isFalse);
      expect(state.canRun, isTrue);

      await tester.tap(find.byKey(const Key('monaco_debug_start_button')));
      await tester.pump();

      expect(state.isDebugging, isTrue);
      expect(state.canDebug, isFalse);
      expect(state.canRun, isFalse);
      expect(state.canStop, isTrue);

      final continueBtnDebug = tester.widget<IconButton>(find.byKey(const Key('monaco_debug_continue_button')));
      final stopBtnDebug = tester.widget<IconButton>(find.byKey(const Key('monaco_stop_button')));
      final runBtnDebug = tester.widget<IconButton>(find.byKey(const Key('monaco_run_button')));
      final debugBtnDebug = tester.widget<IconButton>(find.byKey(const Key('monaco_debug_start_button')));

      expect(continueBtnDebug.onPressed, isNotNull);
      expect(continueBtnDebug.color, equals(const Color(0xFF75BEFF)));
      expect(find.descendant(of: find.byKey(const Key('monaco_debug_continue_button')), matching: find.byType(SvgPicture)), findsOneWidget);
      expect(stopBtnDebug.onPressed, isNotNull);
      expect(runBtnDebug.onPressed, isNull);
      expect(debugBtnDebug.onPressed, isNull);

      await tester.tap(find.byKey(const Key('monaco_debug_continue_button')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('monaco_stop_button')));
      await tester.pump();

      expect(state.isDebugging, isFalse);
      expect(state.canRun, isTrue);
      expect(state.canDebug, isTrue);
      expect(state.canStop, isFalse);
    });

    testWidgets(
        'continueExecution with player remains running without prematurely stopping until next breakpoint',
        (WidgetTester tester) async {
      int continueCalled = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              content: videoNcl,
              filePath: 'video.ncl',
              initialBreakpoints: [7, 11],
              onContinue: () => continueCalled++,
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.effectiveHasPlayer, isTrue);

      state.startDebugging();
      await tester.pump();
      expect(state.isDebugging, isTrue);
      expect(state.isPaused, isFalse);
      expect(state.currentDebugLine, isNull);

      state.pauseAtLine(7);
      await tester.pump();
      expect(state.isPaused, isTrue);
      expect(state.currentDebugLine, equals(7));
      expect(find.byKey(const Key('monaco_debug_controls_box')), findsOneWidget);

      await tester.tap(find.byKey(const Key('monaco_debug_continue_button')));
      await tester.pump();
      expect(continueCalled, equals(1));
      expect(state.isPaused, isFalse);
      expect(state.currentDebugLine, isNull);

      state.pauseAtLine(11);
      await tester.pump();
      expect(state.isPaused, isTrue);
      expect(state.currentDebugLine, equals(11));

      await tester.tap(find.byKey(const Key('monaco_stop_button')));
      await tester.pump();
      expect(state.isDebugging, isFalse);
    });

    testWidgets('highlights all lines of the media changing font background when debugging',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaygroundEditor(
              content: videoNcl,
              filePath: 'video.ncl',
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<PlaygroundEditorState>(find.byType(PlaygroundEditor));
      expect(state.highlightedMediaLines, isEmpty);

      // Pause at line 4 (video media, lines 4 to 6)
      state.pauseAtLine(4);
      await tester.pump();

      expect(state.currentDebugLine, equals(4));
      expect(state.highlightedMediaLines, containsAll([4, 5, 6]));

      // Verify text field controller buildTextSpan has styled spans
      final textField = tester.widget<TextField>(find.byKey(const Key('monaco_editor_text_field')));
      final controller = textField.controller as PlaygroundTextEditingController;
      expect(controller.highlightedMediaLines, containsAll([4, 5, 6]));
      expect(controller.currentDebugLine, equals(4));

      final element = tester.element(find.byKey(const Key('monaco_editor_text_field')));
      final span = controller.buildTextSpan(context: element, withComposing: false);
      expect(span.children, isNotEmpty);

      // Line 4 span (current line: i=3, index = 3*2 = 6) has amber background
      final line4Span = span.children![6] as TextSpan;
      expect(line4Span.style?.backgroundColor, equals(const Color(0x66FFC107)));

      // Line 5 span (media child line: i=4, index = 4*2 = 8) has yellow media background
      final line5Span = span.children![8] as TextSpan;
      expect(line5Span.style?.backgroundColor, equals(const Color(0x33FFC107)));

      // Pause at line 8 (inside green_bg media: lines 7 to 10)
      state.pauseAtLine(8);
      await tester.pump();
      expect(state.currentDebugLine, equals(8));
      expect(state.highlightedMediaLines, containsAll([7, 8, 9, 10]));

      // Resuming or stopping clears media highlights
      state.continueExecution();
      await tester.pump();
      expect(state.currentDebugLine, isNull);
      expect(state.highlightedMediaLines, isEmpty);
    });
  });
}
