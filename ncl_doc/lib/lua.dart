// lib/lua.dart
import 'package:lua_dardo_plus/lua.dart';

abstract class NCLCanvasDelegate {
  void attrColor(int r, int g, int b, int a);
  void drawRect(String mode, double x, double y, double w, double h);
  void drawLine(double x1, double y1, double x2, double y2);
  void drawRoundRect(String mode, double x, double y, double w, double h, double rx, double ry);
  void drawPolygon(List<double> points);
  void drawEllipse(String mode, double x, double y, double w, double h);
  void drawText(String text, double x, double y);
  void drawTextRect(String text, double x, double y, double w, double h, String halign, String valign);
  void clear();
  void flush();
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
    _lua.register("_canvas_new_image", (LuaState ls) {
      final path = ls.toStr(-1) ?? "";
      canvasCalls.add(CanvasCall('new_image', [path]));
      return 0;
    });

    _lua.register("_canvas_new_size", (LuaState ls) {
      final w = ls.toNumber(-2);
      final h = ls.toNumber(-1);
      canvasCalls.add(CanvasCall('new_size', [w, h]));
      return 0;
    });

    _lua.register("_canvas_new_buff", (LuaState ls) {
      final buff = ls.toStr(-1) ?? "";
      canvasCalls.add(CanvasCall('new_buff', [buff]));
      return 0;
    });

    _lua.register("_canvas_new_empty", (LuaState ls) {
      canvasCalls.add(CanvasCall('new_empty', []));
      return 0;
    });

    _lua.register("_canvas_attrSize", (LuaState ls) {
      final w = ls.toNumber(-2);
      final h = ls.toNumber(-1);
      canvasCalls.add(CanvasCall('attrSize', [w, h]));
      return 0;
    });

    _lua.register("_canvas_attrColor", (LuaState ls) {
      final r = ls.toInteger(-4);
      final g = ls.toInteger(-3);
      final b = ls.toInteger(-2);
      final a = ls.toInteger(-1);
      canvasCalls.add(CanvasCall('attrColor', [r, g, b, a]));
      delegate?.attrColor(r, g, b, a);
      return 0;
    });

    _lua.register("_canvas_attrFont", (LuaState ls) {
      final family = ls.toStr(-4) ?? "";
      final size = ls.toNumber(-3);
      final style = ls.toStr(-2) ?? "";
      final weight = ls.toStr(-1) ?? "";
      canvasCalls.add(CanvasCall('attrFont', [family, size, style, weight]));
      return 0;
    });

    _lua.register("_canvas_attrClip", (LuaState ls) {
      final x = ls.toNumber(-4);
      final y = ls.toNumber(-3);
      final w = ls.toNumber(-2);
      final h = ls.toNumber(-1);
      canvasCalls.add(CanvasCall('attrClip', [x, y, w, h]));
      return 0;
    });

    _lua.register("_canvas_attrCrop", (LuaState ls) {
      final x = ls.toNumber(-4);
      final y = ls.toNumber(-3);
      final w = ls.toNumber(-2);
      final h = ls.toNumber(-1);
      canvasCalls.add(CanvasCall('attrCrop', [x, y, w, h]));
      return 0;
    });

    _lua.register("_canvas_attrFlip", (LuaState ls) {
      final h = ls.toBoolean(-2);
      final v = ls.toBoolean(-1);
      canvasCalls.add(CanvasCall('attrFlip', [h, v]));
      return 0;
    });

    _lua.register("_canvas_attrOpacity", (LuaState ls) {
      final opacity = ls.toNumber(-1);
      canvasCalls.add(CanvasCall('attrOpacity', [opacity]));
      return 0;
    });

    _lua.register("_canvas_attrRotation", (LuaState ls) {
      final angle = ls.toNumber(-1);
      canvasCalls.add(CanvasCall('attrRotation', [angle]));
      return 0;
    });

    _lua.register("_canvas_attrScale", (LuaState ls) {
      final sx = ls.toNumber(-2);
      final sy = ls.toNumber(-1);
      canvasCalls.add(CanvasCall('attrScale', [sx, sy]));
      return 0;
    });

    _lua.register("_canvas_drawLine", (LuaState ls) {
      final x1 = ls.toNumber(-4);
      final y1 = ls.toNumber(-3);
      final x2 = ls.toNumber(-2);
      final y2 = ls.toNumber(-1);
      canvasCalls.add(CanvasCall('drawLine', [x1, y1, x2, y2]));
      delegate?.drawLine(x1, y1, x2, y2);
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

    _lua.register("_canvas_drawRoundRect", (LuaState ls) {
      final mode = ls.toStr(-7) ?? "fill";
      final x = ls.toNumber(-6);
      final y = ls.toNumber(-5);
      final w = ls.toNumber(-4);
      final h = ls.toNumber(-3);
      final rx = ls.toNumber(-2);
      final ry = ls.toNumber(-1);
      canvasCalls.add(CanvasCall('drawRoundRect', [mode, x, y, w, h, rx, ry]));
      delegate?.drawRoundRect(mode, x, y, w, h, rx, ry);
      return 0;
    });

    _lua.register("_canvas_drawPolygon", (LuaState ls) {
      final points = _readDoubleTable(ls, -1);
      canvasCalls.add(CanvasCall('drawPolygon', [points]));
      delegate?.drawPolygon(points);
      return 0;
    });

    _lua.register("_canvas_drawEllipse", (LuaState ls) {
      final mode = ls.toStr(-5) ?? "fill";
      final x = ls.toNumber(-4);
      final y = ls.toNumber(-3);
      final w = ls.toNumber(-2);
      final h = ls.toNumber(-1);
      canvasCalls.add(CanvasCall('drawEllipse', [mode, x, y, w, h]));
      delegate?.drawEllipse(mode, x, y, w, h);
      return 0;
    });

    _lua.register("_canvas_drawText", (LuaState ls) {
      final text = ls.toStr(-3) ?? "";
      final x = ls.toNumber(-2);
      final y = ls.toNumber(-1);
      canvasCalls.add(CanvasCall('drawText', [text, x, y]));
      delegate?.drawText(text, x, y);
      return 0;
    });

    _lua.register("_canvas_drawTextRect", (LuaState ls) {
      final text = ls.toStr(-7) ?? "";
      final x = ls.toNumber(-6);
      final y = ls.toNumber(-5);
      final w = ls.toNumber(-4);
      final h = ls.toNumber(-3);
      final halign = ls.toStr(-2) ?? "left";
      final valign = ls.toStr(-1) ?? "top";
      canvasCalls.add(CanvasCall('drawTextRect', [text, x, y, w, h, halign, valign]));
      delegate?.drawTextRect(text, x, y, w, h, halign, valign);
      return 0;
    });

    _lua.register("_canvas_dump", (LuaState ls) {
      final format = ls.toStr(-1) ?? "png";
      canvasCalls.add(CanvasCall('dump', [format]));
      return 0;
    });

    _lua.register("_canvas_clear", (LuaState ls) {
      canvasCalls.add(CanvasCall('clear', []));
      delegate?.clear();
      return 0;
    });

    _lua.register("_canvas_flush", (LuaState ls) {
      canvasCalls.add(CanvasCall('flush', []));
      delegate?.flush();
      return 0;
    });

    _lua.register("_canvas_compose", (LuaState ls) {
      final otherId = ls.toStr(-3) ?? "canvas";
      final x = ls.toNumber(-2);
      final y = ls.toNumber(-1);
      canvasCalls.add(CanvasCall('compose', [otherId, x, y]));
      return 0;
    });

    _lua.register("_canvas_getPixel", (LuaState ls) {
      final x = ls.toNumber(-2);
      final y = ls.toNumber(-1);
      canvasCalls.add(CanvasCall('getPixel', [x, y]));
      ls.pushInteger(0);
      ls.pushInteger(0);
      ls.pushInteger(0);
      ls.pushInteger(255);
      return 4;
    });

    _lua.register("_canvas_setPixel", (LuaState ls) {
      final x = ls.toNumber(-6);
      final y = ls.toNumber(-5);
      final r = ls.toInteger(-4);
      final g = ls.toInteger(-3);
      final b = ls.toInteger(-2);
      final a = ls.toInteger(-1);
      canvasCalls.add(CanvasCall('setPixel', [x, y, r, g, b, a]));
      return 0;
    });

    _lua.register("_canvas_measureText", (LuaState ls) {
      final text = ls.toStr(-1) ?? "";
      canvasCalls.add(CanvasCall('measureText', [text]));
      final w = text.length * 10.0;
      final h = 12.0;
      ls.pushNumber(w);
      ls.pushNumber(h);
      return 2;
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

  List<double> _readDoubleTable(LuaState ls, int idx) {
    final list = <double>[];
    if (!ls.isTable(idx)) return list;
    final absoluteIdx = idx < 0 ? ls.getTop() + idx + 1 : idx;
    for (int i = 1; ; i++) {
      ls.rawGetI(absoluteIdx, i);
      if (ls.isNil(-1)) {
        ls.pop(1);
        break;
      }
      list.add(ls.toNumber(-1));
      ls.pop(1);
    }
    return list;
  }
}

const String _ooWrapper = '''
canvas = {}
canvas.__index = function(t, k)
    local raw = rawget(t, k)
    if raw ~= nil then return raw end
    
    local method = canvas[k]
    if method ~= nil then return method end
    
    if k == "size" then
        return {t:attrSize()}
    elseif k == "color" then
        return {t:attrColor()}
    elseif k == "font" then
        return {t:attrFont()}
    elseif k == "clip" then
        return {t:attrClip()}
    elseif k == "crop" then
        return {t:attrCrop()}
    elseif k == "flip" then
        return {t:attrFlip()}
    elseif k == "opacity" then
        return t:attrOpacity()
    elseif k == "rotation" then
        return t:attrRotation()
    elseif k == "scale" then
        return {t:attrScale()}
    end
end

canvas.__newindex = function(t, k, v)
    if k == "size" then
        if type(v) == "table" then t:attrSize(v[1], v[2]) else t:attrSize(v) end
    elseif k == "color" then
        if type(v) == "table" then t:attrColor(table.unpack(v)) else t:attrColor(v) end
    elseif k == "font" then
        if type(v) == "table" then t:attrFont(table.unpack(v)) else t:attrFont(v) end
    elseif k == "clip" then
        if type(v) == "table" then t:attrClip(table.unpack(v)) else t:attrClip(v) end
    elseif k == "crop" then
        if type(v) == "table" then t:attrCrop(table.unpack(v)) else t:attrCrop(v) end
    elseif k == "flip" then
        if type(v) == "table" then t:attrFlip(v[1], v[2]) else t:attrFlip(v) end
    elseif k == "opacity" then
        t:attrOpacity(v)
    elseif k == "rotation" then
        t:attrRotation(v)
    elseif k == "scale" then
        if type(v) == "table" then t:attrScale(v[1], v[2]) else t:attrScale(v) end
    else
        rawset(t, k, v)
    end
end

local color_names = {
  red = {255, 0, 0, 255},
  black = {0, 0, 0, 255},
  white = {255, 255, 255, 255},
  blue = {0, 0, 255, 255},
  green = {0, 255, 0, 255}
}

function canvas.new(first, second, third)
    local obj = {}
    setmetatable(obj, canvas)
    
    local arg1 = first
    local arg2 = second
    local arg3 = third
    if first == canvas then
        arg1 = second
        arg2 = third
        arg3 = nil
    end

    if type(arg1) == "string" then
        _canvas_new_image(arg1)
        obj._image_path = arg1
    elseif type(arg1) == "number" and type(arg2) == "number" then
        _canvas_new_size(arg1, arg2)
        obj._width = arg1
        obj._height = arg2
    elseif arg1 ~= nil then
        _canvas_new_buff(tostring(arg1))
        obj._buff = tostring(arg1)
    else
        _canvas_new_empty()
    end
    
    return obj
end

function canvas:attrSize(...)
    local args = {...}
    if #args == 0 then
        return self._width or 0, self._height or 0
    end
    self._width = args[1]
    self._height = args[2]
    _canvas_attrSize(args[1], args[2])
    return true
end

function canvas:attrColor(...)
    local args = {...}
    if #args == 0 then
        return self._color_r or 0, self._color_g or 0, self._color_b or 0, self._color_a or 255
    end
    if type(args[1]) == "string" then
        local c = color_names[args[1]]
        if c then
            self._color_r, self._color_g, self._color_b, self._color_a = c[1], c[2], c[3], c[4]
            _canvas_attrColor(c[1], c[2], c[3], c[4])
        end
    elseif type(args[1]) == "number" then
        local r = args[1]
        local g = args[2]
        local b = args[3]
        local a = args[4] or 255
        self._color_r, self._color_g, self._color_b, self._color_a = r, g, b, a
        _canvas_attrColor(r, g, b, a)
    end
    return true
end

function canvas:attrFont(...)
    local args = {...}
    if #args == 0 then
        return self._font_family or "default", self._font_size or 12, self._font_style or "normal", self._font_weight or "normal"
    end
    self._font_family = args[1] or "default"
    self._font_size = args[2] or 12
    self._font_style = args[3] or "normal"
    self._font_weight = args[4] or "normal"
    _canvas_attrFont(self._font_family, self._font_size, self._font_style, self._font_weight)
    return true
end

function canvas:attrClip(...)
    local args = {...}
    if #args == 0 then
        return self._clip_x, self._clip_y, self._clip_w, self._clip_h
    end
    self._clip_x = args[1]
    self._clip_y = args[2]
    self._clip_w = args[3]
    self._clip_h = args[4]
    _canvas_attrClip(args[1], args[2], args[3], args[4])
    return true
end

function canvas:attrCrop(...)
    local args = {...}
    if #args == 0 then
        return self._crop_x, self._crop_y, self._crop_w, self._crop_h
    end
    self._crop_x = args[1]
    self._crop_y = args[2]
    self._crop_w = args[3]
    self._crop_h = args[4]
    _canvas_attrCrop(args[1], args[2], args[3], args[4])
    return true
end

function canvas:attrFlip(...)
    local args = {...}
    if #args == 0 then
        return self._flip_h or false, self._flip_v or false
    end
    self._flip_h = args[1]
    self._flip_v = args[2]
    _canvas_attrFlip(args[1], args[2])
    return true
end

function canvas:attrOpacity(...)
    local args = {...}
    if #args == 0 then
        return self._opacity or 255
    end
    self._opacity = args[1]
    _canvas_attrOpacity(args[1])
    return true
end

function canvas:attrRotation(...)
    local args = {...}
    if #args == 0 then
        return self._rotation or 0
    end
    self._rotation = args[1]
    _canvas_attrRotation(args[1])
    return true
end

function canvas:attrScale(...)
    local args = {...}
    if #args == 0 then
        return self._scale_x or 1.0, self._scale_y or 1.0
    end
    self._scale_x = args[1]
    self._scale_y = args[2]
    _canvas_attrScale(args[1], args[2])
    return true
end

function canvas:drawLine(x1, y1, x2, y2)
    _canvas_drawLine(x1, y1, x2, y2)
end

function canvas:drawRect(mode, x, y, w, h)
    _canvas_drawRect(mode, x, y, w, h)
end

function canvas:drawRoundRect(mode, x, y, w, h, rx, ry)
    _canvas_drawRoundRect(mode, x, y, w, h, rx, ry)
end

function canvas:drawPolygon(points)
    _canvas_drawPolygon(points)
end

function canvas:drawEllipse(mode, x, y, w, h)
    _canvas_drawEllipse(mode, x, y, w, h)
end

function canvas:drawText(...)
    local args = {...}
    if type(args[1]) == "string" then
        _canvas_drawText(args[1], args[2] or 0, args[3] or 0)
    else
        _canvas_drawText(args[3] or "", args[1] or 0, args[2] or 0)
    end
end

function canvas:drawTextRect(...)
    local args = {...}
    if type(args[1]) == "string" then
        _canvas_drawTextRect(args[1], args[2] or 0, args[3] or 0, args[4] or 0, args[5] or 0, args[6] or "left", args[7] or "top")
    else
        _canvas_drawTextRect(args[5] or "", args[1] or 0, args[2] or 0, args[3] or 0, args[4] or 0, args[6] or "left", args[7] or "top")
    end
end

function canvas:dump(format)
    _canvas_dump(format or "png")
end

function canvas:clear()
    _canvas_clear()
end

function canvas:flush()
    _canvas_flush()
end

function canvas:compose(other, x, y)
    local other_id = other and (other._image_path or "canvas") or "nil"
    _canvas_compose(other_id, x or 0, y or 0)
end

function canvas:pixel(x, y, ...)
    local args = {...}
    if #args == 0 then
        return _canvas_getPixel(x, y)
    else
        if type(args[1]) == "table" then
            _canvas_setPixel(x, y, args[1][1], args[1][2], args[1][3], args[1][4] or 255)
        else
            _canvas_setPixel(x, y, args[1], args[2], args[3], args[4] or 255)
        end
    end
end

function canvas:measureText(text)
    return _canvas_measureText(text or "")
end

''';
