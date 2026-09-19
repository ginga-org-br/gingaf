import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nclui/ncl.dart';

void main() {
  group('Lua Canvas and Key Integration Tests', () {
    const luaCanvasContent = '''
local event = event or require('event')

local logo = canvas.new('../assets/ginga-logo.png')

local x = 200
local y = 150
local w = 300
local h = 200
local step = 20

local function draw()
    canvas:clear()

    local screen_w, screen_h = canvas:attrSize()
    screen_w = screen_w or 1280
    screen_h = screen_h or 720
    canvas:attrColor('black')
    canvas:drawRect('fill', 0, 0, screen_w, screen_h)

    canvas:attrColor('white')
    canvas:attrFont('default', 20, 'normal', 'bold')
    canvas:drawTextRect('Guide: move the canvas items with cursor UP, DOWN, LEFT, RIGHT', 0, 20, screen_w, 40, 'center', 'center')

    canvas:attrColor(0, 156, 59, 255)
    canvas:drawRect('fill', x, y, w, h)

    canvas:attrColor(255, 223, 0, 255)
    canvas:drawPolygon({
        x + w / 2, y + 20,
        x + w - 25, y + h / 2,
        x + w / 2, y + h - 20,
        x + 25, y + h / 2
    })

    local d = 110
    canvas:attrColor(0, 39, 118, 255)
    canvas:drawEllipse('fill', x + (w - d) / 2, y + (h - d) / 2, d, d)

    canvas:attrColor(255, 255, 255, 255)
    canvas:attrFont('default', 14, 'normal', 'bold')
    canvas:drawTextRect('draw from nclua', x, y, w, h, 'center', 'center')

    canvas:compose(x + w + 40, y, logo)

    canvas:flush()
end

draw()

event.register(function(evt)
    if evt.class == 'key' and evt.type == 'press' then
        local key = evt.key
        if key == 'CURSOR_UP' then
            y = y - step
            draw()
        elseif key == 'CURSOR_DOWN' then
            y = y + step
            draw()
        elseif key == 'CURSOR_LEFT' then
            x = x - step
            draw()
        elseif key == 'CURSOR_RIGHT' then
            x = x + step
            draw()
        end
    end
end)
''';

    testWidgets('Lua script renders canvas commands and handles key events',
        (WidgetTester tester) async {
      const nclContent = '''
<ncl id="pure_test" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="rg" width="100%" height="100%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="d1" region="rg"/>
    </descriptorBase>
  </head>
  <body>
    <port id="p1" component="luaMedia"/>
    <media type="application/x-ginga-settings" id="settings">
      <property name="service.currentKeyMaster" value="luaMedia"/>
    </media>
    <media id="luaMedia" src="script.lua" descriptor="d1" type="application/x-ginga-NCLua"/>
  </body>
</ncl>
''';

      const luaContent = '''
canvas:attrColor('red')
canvas:drawRect('fill', 10, 20, 100, 200)
canvas:attrFont('default', 16, 'normal', 'bold')
canvas:drawText('Hello NCLua', 30, 40)
canvas:flush()

event.register(function(evt)
  if evt.class == 'key' then
    if evt.type == 'press' then
      canvas:attrColor('blue')
      canvas:drawRect('fill', 50, 50, 80, 80)
      canvas:drawText('KEY:' .. tostring(evt.key), 60, 60)
      canvas:flush()
    elseif evt.type == 'release' then
      canvas:attrColor('green')
      canvas:drawRect('fill', 100, 100, 40, 40)
      canvas:flush()
    end
  end
end)
''';

      final gingacc = GingaCC(virtualFiles: {
        'main.ncl': nclContent,
        'script.lua': luaContent,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NclWidget(
              src: 'main.ncl',
              gingacc: gingacc,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final nclState = tester.state<NclWidgetState>(find.byType(NclWidget));
      expect(nclState.nclDocument, isNotNull);

      expect(find.byType(LuaWidget), findsOneWidget);
      final luaState = tester.state<LuaWidgetState>(find.byType(LuaWidget));

      final initialCommandCount = luaState.canvasState.commands.length;
      expect(initialCommandCount, greaterThan(0));

      final firstRect =
          luaState.canvasState.commands.whereType<DrawRectCommand>().first;
      expect(firstRect.rect, equals(const Rect.fromLTWH(10, 20, 100, 200)));
      expect(firstRect.paint.color, equals(const Color(0xFFFF0000)));

      nclState.handleKeyPress('CURSOR_UP');
      await tester.pump();

      expect(luaState.canvasState.commands.length,
          greaterThan(initialCommandCount));
      final blueRect = luaState.canvasState.commands
          .whereType<DrawRectCommand>()
          .firstWhere((r) => r.rect == const Rect.fromLTWH(50, 50, 80, 80));
      expect(blueRect.paint.color, equals(const Color(0xFF0000FF)));

      final countBeforeRelease = luaState.canvasState.commands.length;
      nclState.handleKeyRelease('CURSOR_UP');
      await tester.pump();

      expect(luaState.canvasState.commands.length,
          greaterThan(countBeforeRelease));
      final greenRect = luaState.canvasState.commands
          .whereType<DrawRectCommand>()
          .firstWhere((r) => r.rect == const Rect.fromLTWH(100, 100, 40, 40));
      expect(greenRect.paint.color, equals(const Color(0xFF00FF00)));
    });

    testWidgets('NCL and Lua react to keys and repaint canvas',
        (WidgetTester tester) async {
      const nclContent = '''
<ncl>
  <head>
    <regionBase>
      <region id="rgCanvas" left="10%" top="10%" width="80%" height="80%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dCanvas" region="rgCanvas"/>
    </descriptorBase>
  </head>
  <body>
    <port id="init" component="lua"/>
    <media type="application/x-ginga-settings" id="settings">
      <property name="service.currentKeyMaster" value="lua"/>
    </media>
    <media id="lua" src="lua_canvas.lua" descriptor="dCanvas">
      <property name="background" value="black"/>
    </media>
  </body>
</ncl>
''';

      final gingacc = GingaCC(virtualFiles: {
        'main.ncl': nclContent,
        'lua_canvas.lua': luaCanvasContent,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NclWidget(
              src: 'main.ncl',
              gingacc: gingacc,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final nclFinder = find.byType(NclWidget);
      expect(nclFinder, findsOneWidget);
      final nclState = tester.state<NclWidgetState>(nclFinder);
      expect(nclState.errorMsg, isEmpty);
      expect(nclState.nclDocument, isNotNull);

      final luaFinder = find.byType(LuaWidget);
      expect(luaFinder, findsOneWidget);
      final luaState = tester.state<LuaWidgetState>(luaFinder);

      expect(luaState.rect.width, equals(640.0));
      expect(luaState.rect.height, equals(480.0));
      expect(luaState.rect.left, equals(80.0));
      expect(luaState.rect.top, equals(60.0));

      final rects =
          luaState.canvasState.commands.whereType<DrawRectCommand>().toList();
      expect(rects.length, equals(2));
      expect(
          rects.any((r) => r.paint.color == const Color(0xFF000000)), isTrue);
      final flagRect =
          rects.firstWhere((r) => r.paint.color != const Color(0xFF000000));
      expect(flagRect.rect, equals(const Rect.fromLTWH(200, 150, 300, 200)));

      final polygons = luaState.canvasState.commands
          .whereType<DrawPolygonCommand>()
          .toList();
      expect(polygons.length, equals(1));

      final ellipses = luaState.canvasState.commands
          .whereType<DrawEllipseCommand>()
          .toList();
      expect(ellipses.length, equals(1));
      expect(ellipses[0].rect, equals(const Rect.fromLTWH(295, 195, 110, 110)));

      final texts = luaState.canvasState.commands
          .whereType<DrawTextRectCommand>()
          .toList();
      expect(texts.length, equals(2));
      expect(texts.any((t) => t.text.contains('Guide: move the canvas items')),
          isTrue);
      expect(texts.any((t) => t.text == 'draw from nclua'), isTrue);

      final composes = luaState.canvasState.commands
          .whereType<DrawComposeCommand>()
          .toList();
      expect(composes.length, equals(1));
      expect(composes[0].dx, equals(540));
      expect(composes[0].dy, equals(150));
      expect(composes[0].imagePath, equals('../assets/ginga-logo.png'));

      nclState.handleKeyPress('CURSOR_UP');
      await tester.pump();

      expect(luaState.engine.lastKey, equals('CURSOR_UP'));
      expect(luaState.engine.lastKeyType, equals('press'));

      final rectsUp =
          luaState.canvasState.commands.whereType<DrawRectCommand>().toList();
      final flagRectUp =
          rectsUp.firstWhere((r) => r.paint.color != const Color(0xFF000000));
      expect(flagRectUp.rect, equals(const Rect.fromLTWH(200, 130, 300, 200)));

      nclState.handleKeyPress('CURSOR_RIGHT');
      await tester.pump();

      expect(luaState.engine.lastKey, equals('CURSOR_RIGHT'));
      expect(luaState.engine.lastKeyType, equals('press'));

      final rectsRight =
          luaState.canvasState.commands.whereType<DrawRectCommand>().toList();
      final flagRectRight = rectsRight
          .firstWhere((r) => r.paint.color != const Color(0xFF000000));
      expect(
          flagRectRight.rect, equals(const Rect.fromLTWH(220, 130, 300, 200)));

      nclState.handleKeyPress('CURSOR_DOWN');
      await tester.pump();

      final rectsDown =
          luaState.canvasState.commands.whereType<DrawRectCommand>().toList();
      final flagRectDown =
          rectsDown.firstWhere((r) => r.paint.color != const Color(0xFF000000));
      expect(
          flagRectDown.rect, equals(const Rect.fromLTWH(220, 150, 300, 200)));

      nclState.handleKeyPress('CURSOR_LEFT');
      await tester.pump();

      final rectsLeft =
          luaState.canvasState.commands.whereType<DrawRectCommand>().toList();
      final flagRectLeft =
          rectsLeft.firstWhere((r) => r.paint.color != const Color(0xFF000000));
      expect(
          flagRectLeft.rect, equals(const Rect.fromLTWH(200, 150, 300, 200)));

      nclState.handleKeyRelease('CURSOR_LEFT');
      await tester.pump();
      expect(luaState.engine.lastKey, equals('CURSOR_LEFT'));
      expect(luaState.engine.lastKeyType, equals('release'));
    });

    testWidgets(
        'cursor UP, DOWN, LEFT, RIGHT should not trigger when media lua is not currentKeyMaster',
        (WidgetTester tester) async {
      const nclContent = '''
<ncl>
  <head>
    <regionBase>
      <region id="rgCanvas" left="10%" top="10%" width="80%" height="80%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dCanvas" region="rgCanvas"/>
    </descriptorBase>
  </head>
  <body>
    <port id="init" component="lua"/>
    <media type="application/x-ginga-settings" id="settings">
      <property name="service.currentKeyMaster" value="other"/>
    </media>
    <media id="lua" src="lua_canvas.lua" descriptor="dCanvas">
      <property name="background" value="black"/>
    </media>
  </body>
</ncl>
''';

      final gingacc = GingaCC(virtualFiles: {
        'main.ncl': nclContent,
        'lua_canvas.lua': luaCanvasContent,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NclWidget(
              src: 'main.ncl',
              gingacc: gingacc,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final nclState = tester.state<NclWidgetState>(find.byType(NclWidget));
      final luaState = tester.state<LuaWidgetState>(find.byType(LuaWidget));

      final initialFlagRect = luaState.canvasState.commands
          .whereType<DrawRectCommand>()
          .firstWhere((r) => r.paint.color != const Color(0xFF000000));
      expect(initialFlagRect.rect,
          equals(const Rect.fromLTWH(200, 150, 300, 200)));

      nclState.handleKeyPress('CURSOR_UP');
      await tester.pump();
      expect(luaState.engine.lastKey, isNull);

      nclState.handleKeyPress('CURSOR_DOWN');
      await tester.pump();
      expect(luaState.engine.lastKey, isNull);

      nclState.handleKeyPress('CURSOR_LEFT');
      await tester.pump();
      expect(luaState.engine.lastKey, isNull);

      nclState.handleKeyPress('CURSOR_RIGHT');
      await tester.pump();
      expect(luaState.engine.lastKey, isNull);

      final rectAfterKeys = luaState.canvasState.commands
          .whereType<DrawRectCommand>()
          .firstWhere((r) => r.paint.color != const Color(0xFF000000));
      expect(
          rectAfterKeys.rect, equals(const Rect.fromLTWH(200, 150, 300, 200)));

      nclState.nclDocument
          ?.dispatchSettingsUpdate('service.currentKeyMaster', 'lua');

      nclState.handleKeyPress('CURSOR_UP');
      await tester.pump();
      expect(luaState.engine.lastKey, equals('CURSOR_UP'));

      final rectAfterMaster = luaState.canvasState.commands
          .whereType<DrawRectCommand>()
          .firstWhere((r) => r.paint.color != const Color(0xFF000000));
      expect(rectAfterMaster.rect,
          equals(const Rect.fromLTWH(200, 130, 300, 200)));
    });

    testWidgets(
        'if not set currentKeyMaster the key should not be processed by lua_runtime',
        (WidgetTester tester) async {
      const nclContent = '''
<ncl>
  <head>
    <regionBase>
      <region id="rgCanvas" left="10%" top="10%" width="80%" height="80%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dCanvas" region="rgCanvas"/>
    </descriptorBase>
  </head>
  <body>
    <port id="init" component="lua"/>
    <media id="lua" src="lua_canvas.lua" descriptor="dCanvas">
      <property name="background" value="black"/>
    </media>
  </body>
</ncl>
''';

      final gingacc = GingaCC(virtualFiles: {
        'main.ncl': nclContent,
        'lua_canvas.lua': luaCanvasContent,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NclWidget(
              src: 'main.ncl',
              gingacc: gingacc,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final nclState = tester.state<NclWidgetState>(find.byType(NclWidget));
      expect(nclState.nclDocument?.currentKeyMaster, isNull);

      final luaState = tester.state<LuaWidgetState>(find.byType(LuaWidget));

      final initialFlagRect = luaState.canvasState.commands
          .whereType<DrawRectCommand>()
          .firstWhere((r) => r.paint.color != const Color(0xFF000000));
      expect(initialFlagRect.rect,
          equals(const Rect.fromLTWH(200, 150, 300, 200)));

      nclState.handleKeyPress('CURSOR_UP');
      await tester.pump();
      expect(luaState.engine.lastKey, isNull);

      nclState.handleKeyPress('CURSOR_DOWN');
      await tester.pump();
      expect(luaState.engine.lastKey, isNull);

      nclState.handleKeyPress('CURSOR_LEFT');
      await tester.pump();
      expect(luaState.engine.lastKey, isNull);

      nclState.handleKeyPress('CURSOR_RIGHT');
      await tester.pump();
      expect(luaState.engine.lastKey, isNull);

      final rectAfterKeys = luaState.canvasState.commands
          .whereType<DrawRectCommand>()
          .firstWhere((r) => r.paint.color != const Color(0xFF000000));
      expect(
          rectAfterKeys.rect, equals(const Rect.fromLTWH(200, 150, 300, 200)));
    });
  });
}
