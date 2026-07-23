// lib/lua.dart
import 'package:lua_dardo_plus/lua.dart';

abstract class NCLCanvasDelegate {
  void attrColor(int r, int g, int b, int a);
  void drawRect(String mode, double x, double y, double w, double h);
}

class CanvasCall {
  final String method;
  final List<dynamic> args;
  CanvasCall(this.method, this.args);

  @override
  String toString() => 'CanvasCall(method: $method, args: $args)';
}

class NCLua {
  late LuaState _lua;
  final NCLCanvasDelegate? delegate;
  final List<CanvasCall> canvasCalls = [];
  final Map<String, String> _persistentVars = {};
  String? Function(String propertyName)? settingsProvider;
  String? Function(String name)? getPersistentVar;
  void Function(String name, String value)? setPersistentVar;

  NCLua({this.delegate}) {
    _lua = LuaState.newState();
    _lua.openLibs();
    getPersistentVar ??= (name) => _persistentVars[name];
    setPersistentVar ??= (name, value) => _persistentVars[name] = value;
    _initBindings();
  }

  void _initBindings() {
    _lua.register("_canvas_attrColor", (LuaState ls) {
      final r = ls.toInteger(-4);
      final g = ls.toInteger(-3);
      final b = ls.toInteger(-2);
      final a = ls.toInteger(-1);

      canvasCalls.add(CanvasCall('attrColor', [r, g, b, a]));
      delegate?.attrColor(r, g, b, a);
      return 0;
    });

    _lua.register("_canvas_drawRect", (LuaState ls) {
      final mode = ls.toStr(-5) ?? "fill";
      final x = ls.toNumber(-4);
      final y = ls.toNumber(-3);
      final w = ls.toNumber(-2);
      final h = ls.toNumber(-1);

      canvasCalls.add(CanvasCall('drawRect', [mode, x, y, w, h]));
      delegate?.drawRect(mode, x, y, w, h);
      return 0;
    });

    _lua.doString(_ooWrapper);
  }

  void execute(String script) {
    try {
      _lua.doString(script);
    } catch (e) {
      // ignore
    }
  }

  void clearBuffer() {
    canvasCalls.clear();
  }
}

const String _ooWrapper = '''
canvas = {}
canvas.__index = canvas

local color_names = {
  red = {255, 0, 0, 255},
  black = {0, 0, 0, 255},
  white = {255, 255, 255, 255},
  blue = {0, 0, 255, 255},
  green = {0, 255, 0, 255}
}

function canvas.new(...)
   return setmetatable({}, canvas)
end

function canvas:attrColor(...)
    local args = {...}
    if type(args[1]) == "string" then
        local c = color_names[args[1]]
        if c then
            _canvas_attrColor(c[1], c[2], c[3], c[4])
        end
    elseif type(args[1]) == "number" then
        local r = args[1]
        local g = args[2]
        local b = args[3]
        local a = args[4] or 255
        _canvas_attrColor(r, g, b, a)
    end
    return true
end

function canvas:drawRect(mode, x, y, w, h)
    _canvas_drawRect(mode, x, y, w, h)
end
''';
