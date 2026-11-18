import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nclui/ncl_widget.dart';

void main() {
  final sharedAssets = {
    'test.ncl': '''
<ncl>
  <body>
    <port id="init" component="lua_media"/>
    <media id="lua_media" src="test.lua"/>
  </body>
</ncl>
''',
    'test.lua': '''
local c = canvas.new("test")
c:attrColor("red")
c:drawRect("fill", 0, 0, 50, 50)
c:attrColor("blue")
c:drawRect("frame", 60, 60, 40, 40)
c:attrColor(0, 255, 0, 255)
c:drawRect("fill", 110, 110, 20, 20)
''',
  };

  testWidgets('NCL Integration Mounting Verification',
      (WidgetTester tester) async {
    final gingacc = GingaCC()..setVirtualFiles(sharedAssets);
    await tester.pumpWidget(
      MaterialApp(
        home: NclWidget(
          src: 'test.ncl',
          gingacc: gingacc,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NclWidget), findsOneWidget);
  });

  group('LuaWidget Standalone Unit Tests', () {
    testWidgets('LuaWidget should process multiple drawing commands',
        (WidgetTester tester) async {
      final gingacc = GingaCC()..setVirtualFiles(sharedAssets);
      await tester.pumpWidget(
        MaterialApp(
          home: LuaWidget(
            src: 'test.lua',
            gingacc: gingacc,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<LuaWidgetState>(find.byType(LuaWidget));

      final commands = state.canvasState.commands;
      expect(commands.length, 3);
      expect(commands[0].paint.color, const Color(0xFFFF0000));
      expect(commands[1].paint.color, const Color(0xFF0000FF));
      expect(commands[2].paint.color, const Color(0xFF00FF00));
    });

    testWidgets('examples/lua/zip_list/main.ncl opens web zip and navigates entries',
        (WidgetTester tester) async {
      final candidateRoot = File('examples/lua/zip_list/main.ncl');
      final examplePath = candidateRoot.existsSync()
          ? candidateRoot.path
          : '../../examples/lua/zip_list/main.ncl';
      const webZipUrl =
          'https://raw.githubusercontent.com/Stuk/jszip/main/test/ref/all.zip';
      const allZipBase64 =
          'UEsDBAoDAAAAAJxs8Trj5ZWwDAAAAAwAAAAJAAAASGVsbG8udHh0SGVsbG8gV29ybGQK'
          'UEsDBAoDAAAAALFs8ToAAAAAAAAAAAAAAAAHAAAAaW1hZ2VzL1BLAwQKAwAAAAAVZ+o6'
          'PD/riikAAAApAAAAEAAAAGltYWdlcy9zbWlsZS5naWZHSUY4N2EFAAUAgAIAAAAA/94A'
          'LAAAAAAFAAUAAAIIjA+RZ6sKUgEAO1BLAQIUAwoDAAAAAJxs8Trj5ZWwDAAAAAwAAAAJ'
          'AAAAAAAAAAAAIICkgQAAAABIZWxsby50eHRQSwECFAMKAwAAAACxbPE6AAAAAAAAAAAA'
          'AAAABwAAAAAAAAAAABCA7UEzAAAAaW1hZ2VzL1BLAQIUAwoDAAAAABVn6jo8P+uKKQAA'
          'ACkAAAAQAAAAAAAAAAAAIICkgVgAAABpbWFnZXMvc21pbGUuZ2lmUEsFBgAAAAADAAMA'
          'qgAAAK8AAAAAAA==';
      final gingacc = GingaCC()
        ..setVirtualFiles({
          webZipUrl: 'data:application/zip;base64,$allZipBase64',
        });
      final nclKey = GlobalKey<NclWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NclWidget(
              key: nclKey,
              src: examplePath,
              gingacc: gingacc,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final luaState = tester.state<LuaWidgetState>(find.byType(LuaWidget));
      final initialTexts = luaState.canvasState.commands
          .whereType<DrawTextRectCommand>()
          .map((c) => c.text)
          .toList();
      expect(
        initialTexts.any((t) => t.contains('(2 files)')),
        isTrue,
      );
      expect(initialTexts, contains('Hello.txt'));
      expect(initialTexts, contains('images/smile.gif'));
      expect(
        initialTexts.any((t) => t.contains('Hello World')),
        isTrue,
      );

      nclKey.currentState!.handleKeyPress('CURSOR_DOWN');
      await tester.pump(const Duration(milliseconds: 50));

      final nextTexts = luaState.canvasState.commands
          .whereType<DrawTextRectCommand>()
          .map((c) => c.text)
          .toList();
      expect(
        nextTexts.any((t) => t.contains('[Binary content: 41 bytes]')),
        isTrue,
      );
    });
  });
}
