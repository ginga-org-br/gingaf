import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ncldoc/ncl_document.dart';

import 'base_widget.dart';

abstract class NclCanvasDelegate {
  void attrColor(int r, int g, int b, int a);
  void attrFont(String family, double size, String style, String weight);
  void drawRect(String mode, double x, double y, double w, double h);
  void drawLine(double x1, double y1, double x2, double y2);
  void drawRoundRect(String mode, double x, double y, double w, double h,
      double rx, double ry);
  void drawPolygon(List<double> points);
  void drawEllipse(String mode, double x, double y, double w, double h);
  void drawText(String text, double x, double y);
  void drawTextRect(String text, double x, double y, double w, double h,
      String halign, String valign);
  void compose(String otherId, double x, double y,
      [double? sx, double? sy, double? sw, double? sh]);
  void clear();
  void flush();
}

class CanvasCall {
  final String method;
  final List<dynamic> args;
  CanvasCall(this.method, this.args);
}

(double, double)? parseImageDimensions(List<int> bytes) {
  if (bytes.length < 10) return null;
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    if (bytes.length >= 24) {
      final w =
          (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final h =
          (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      return (w.toDouble(), h.toDouble());
    }
  }
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
    if (bytes.length >= 10) {
      final w = bytes[6] | (bytes[7] << 8);
      final h = bytes[8] | (bytes[9] << 8);
      return (w.toDouble(), h.toDouble());
    }
  }
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
    int i = 2;
    while (i + 8 < bytes.length) {
      if (bytes[i] != 0xFF) break;
      final marker = bytes[i + 1];
      final len = (bytes[i + 2] << 8) | bytes[i + 3];
      if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
        final h = (bytes[i + 5] << 8) | bytes[i + 6];
        final w = (bytes[i + 7] << 8) | bytes[i + 8];
        return (w.toDouble(), h.toDouble());
      }
      i += 2 + len;
    }
  }
  return null;
}

List<double> _readDoubleTable(LuaState ls, int idx) {
  final list = <double>[];
  if (!ls.isTable(idx)) return list;
  final absoluteIdx = idx < 0 ? ls.getTop() + idx + 1 : idx;
  for (int i = 1;; i++) {
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

void initCanvasBindings(
  NCLuaRuntime engine,
  NclCanvasDelegate delegate, {
  double canvasWidth = 1920.0,
  double canvasHeight = 1080.0,
  (double, double) Function()? rootSizeProvider,
  (double, double)? Function(String path)? imageSizeProvider,
}) {
  final ls = engine.luaState;

  ls.register("_canvas_new_image", (LuaState ls) {
    final path = ls.toStr(-1) ?? "";
    double w = 0;
    double h = 0;
    if (imageSizeProvider != null) {
      final sz = imageSizeProvider(path);
      if (sz != null) {
        w = sz.$1;
        h = sz.$2;
      }
    }
    ls.pushNumber(w);
    ls.pushNumber(h);
    return 2;
  });

  ls.register("_canvas_get_root_size", (LuaState ls) {
    double w = canvasWidth;
    double h = canvasHeight;
    if (rootSizeProvider != null) {
      final sz = rootSizeProvider();
      w = sz.$1;
      h = sz.$2;
    }
    ls.pushNumber(w);
    ls.pushNumber(h);
    return 2;
  });

  ls.register("_canvas_new_size", (LuaState ls) {
    return 0;
  });

  ls.register("_canvas_new_buff", (LuaState ls) {
    return 0;
  });

  ls.register("_canvas_new_empty", (LuaState ls) {
    return 0;
  });

  ls.register("_canvas_attrSize", (LuaState ls) {
    return 0;
  });

  ls.register("_canvas_attrColor", (LuaState ls) {
    final r = ls.toInteger(-4);
    final g = ls.toInteger(-3);
    final b = ls.toInteger(-2);
    final a = ls.toInteger(-1);
    delegate.attrColor(r, g, b, a);
    return 0;
  });

  ls.register("_canvas_attrFont", (LuaState ls) {
    final family = ls.toStr(-4) ?? "";
    final size = ls.toNumber(-3);
    final style = ls.toStr(-2) ?? "";
    final weight = ls.toStr(-1) ?? "";
    delegate.attrFont(family, size, style, weight);
    return 0;
  });

  ls.register("_canvas_attrClip", (LuaState ls) {
    return 0;
  });

  ls.register("_canvas_attrCrop", (LuaState ls) {
    return 0;
  });

  ls.register("_canvas_attrFlip", (LuaState ls) {
    return 0;
  });

  ls.register("_canvas_attrOpacity", (LuaState ls) {
    return 0;
  });

  ls.register("_canvas_attrRotation", (LuaState ls) {
    return 0;
  });

  ls.register("_canvas_attrScale", (LuaState ls) {
    return 0;
  });

  ls.register("_canvas_drawLine", (LuaState ls) {
    final x1 = ls.toNumber(-4);
    final y1 = ls.toNumber(-3);
    final x2 = ls.toNumber(-2);
    final y2 = ls.toNumber(-1);
    delegate.drawLine(x1, y1, x2, y2);
    return 0;
  });

  ls.register("_canvas_drawRect", (LuaState ls) {
    final mode = ls.toStr(-5) ?? "fill";
    final x = ls.toNumber(-4);
    final y = ls.toNumber(-3);
    final w = ls.toNumber(-2);
    final h = ls.toNumber(-1);
    delegate.drawRect(mode, x, y, w, h);
    return 0;
  });

  ls.register("_canvas_drawRoundRect", (LuaState ls) {
    final mode = ls.toStr(-7) ?? "fill";
    final x = ls.toNumber(-6);
    final y = ls.toNumber(-5);
    final w = ls.toNumber(-4);
    final h = ls.toNumber(-3);
    final rx = ls.toNumber(-2);
    final ry = ls.toNumber(-1);
    delegate.drawRoundRect(mode, x, y, w, h, rx, ry);
    return 0;
  });

  ls.register("_canvas_drawPolygon", (LuaState ls) {
    final points = _readDoubleTable(ls, -1);
    delegate.drawPolygon(points);
    return 0;
  });

  ls.register("_canvas_drawEllipse", (LuaState ls) {
    final mode = ls.toStr(-5) ?? "fill";
    final x = ls.toNumber(-4);
    final y = ls.toNumber(-3);
    final w = ls.toNumber(-2);
    final h = ls.toNumber(-1);
    delegate.drawEllipse(mode, x, y, w, h);
    return 0;
  });

  ls.register("_canvas_drawText", (LuaState ls) {
    final text = ls.toStr(-3) ?? "";
    final x = ls.toNumber(-2);
    final y = ls.toNumber(-1);
    delegate.drawText(text, x, y);
    return 0;
  });

  ls.register("_canvas_drawTextRect", (LuaState ls) {
    final text = ls.toStr(-7) ?? "";
    final x = ls.toNumber(-6);
    final y = ls.toNumber(-5);
    final w = ls.toNumber(-4);
    final h = ls.toNumber(-3);
    final halign = ls.toStr(-2) ?? "left";
    final valign = ls.toStr(-1) ?? "top";
    delegate.drawTextRect(text, x, y, w, h, halign, valign);
    return 0;
  });

  ls.register("_canvas_dump", (LuaState ls) {
    return 0;
  });

  ls.register("_canvas_clear", (LuaState ls) {
    delegate.clear();
    return 0;
  });

  ls.register("_canvas_flush", (LuaState ls) {
    delegate.flush();
    return 0;
  });

  ls.register("_canvas_compose", (LuaState ls) {
    final top = ls.getTop();
    final otherId = ls.toStr(1) ?? "canvas";
    final x = ls.toNumber(2);
    final y = ls.toNumber(3);
    double? sx, sy, sw, sh;
    if (top >= 7) {
      sx = ls.toNumber(4);
      sy = ls.toNumber(5);
      sw = ls.toNumber(6);
      sh = ls.toNumber(7);
    }
    delegate.compose(otherId, x, y, sx, sy, sw, sh);
    return 0;
  });

  ls.register("_canvas_getPixel", (LuaState ls) {
    ls.pushInteger(0);
    ls.pushInteger(0);
    ls.pushInteger(0);
    ls.pushInteger(255);
    return 4;
  });

  ls.register("_canvas_setPixel", (LuaState ls) {
    return 0;
  });

  ls.register("_canvas_measureText", (LuaState ls) {
    final text = ls.toStr(-1) ?? "";
    final w = text.length * 14.0 * 0.6;
    final h = 14.0 * 1.2;
    ls.pushNumber(w);
    ls.pushNumber(h);
    return 2;
  });

  ls.doString(_canvasLuaCode);
}

const String _canvasLuaCode = '''
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
        local w, h = _canvas_new_image(arg1)
        obj._image_path = arg1
        if w and w > 0 then obj._width = w end
        if h and h > 0 then obj._height = h end
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
        if self._width and self._height then
            return self._width, self._height
        end
        return _canvas_get_root_size()
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

function canvas:compose(...)
    local args = {...}
    local dst_x, dst_y, src, sx, sy, sw, sh
    if type(args[1]) == "number" and type(args[2]) == "number" then
        dst_x = args[1]
        dst_y = args[2]
        src = args[3]
        sx = args[4]
        sy = args[5]
        sw = args[6]
        sh = args[7]
    elseif type(args[1]) == "table" then
        src = args[1]
        dst_x = args[2] or 0
        dst_y = args[3] or 0
        sx = args[4]
        sy = args[5]
        sw = args[6]
        sh = args[7]
    end
    if src and not sx and src._crop_x then
        sx = src._crop_x
        sy = src._crop_y
        sw = src._crop_w
        sh = src._crop_h
    end
    local other_id = src and (src._image_path or "canvas") or "nil"
    if sx ~= nil and sy ~= nil and sw ~= nil and sh ~= nil then
        _canvas_compose(other_id, dst_x or 0, dst_y or 0, sx, sy, sw, sh)
    else
        _canvas_compose(other_id, dst_x or 0, dst_y or 0)
    end
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

class LuaWidget extends BaseWidget {
  const LuaWidget({
    super.key,
    required super.src,
    super.media,
    super.document,
    super.gingacc,
  });

  @override
  State<LuaWidget> createState() => LuaWidgetState();
}

class LuaWidgetState extends MediaState<LuaWidget> {
  late NCLuaRuntime _engine;
  NCLuaRuntime get engine => _engine;
  final CanvasState canvasState = CanvasState();
  final Set<String> _loadingImages = {};
  bool _scriptRan = false;

  @override
  void initState() {
    super.initState();
    parseProperties(widget.media);

    final parentBounds = widget.document?.config.graphsPlaneBounds;
    final planeW = parentBounds?.width ?? 1920.0;
    final planeH = parentBounds?.height ?? 1080.0;
    final resolvedW = resolveDim(widthStr, planeW);
    final resolvedH = resolveDim(heightStr, planeH);
    final initialW = resolvedW > 0 ? resolvedW : planeW;
    final initialH = resolvedH > 0 ? resolvedH : planeH;

    final media = widget.media;
    if (media is NCLua) {
      _engine = media.runtime;
    } else {
      final doc = widget.document ??
          NclDocument.fromContent(
            '<ncl><head/><body/></ncl>',
            gingacc: widget.gingacc,
          );
      final luaNode = NCLua(
        document: doc,
        rawAttributes: {'src': widget.src},
      );
      _engine = luaNode.runtime;
    }

    initCanvasBindings(
      _engine,
      canvasState,
      canvasWidth: initialW,
      canvasHeight: initialH,
      rootSizeProvider: () {
        if (rect.width > 0 && rect.height > 0) {
          return (rect.width, rect.height);
        }
        final curW = resolveDim(widthStr, planeW);
        final curH = resolveDim(heightStr, planeH);
        return (curW > 0 ? curW : initialW, curH > 0 ? curH : initialH);
      },
      imageSizeProvider: _getImageSize,
    );

    canvasState.onUpdate = () {
      if (mounted) setState(() {});
    };
    canvasState.imageLoader = _loadImage;
  }

  ImageProvider _resolveImageProvider(String path) {
    final gingacc = widget.gingacc ?? widget.document?.gingacc ?? GingaCC();
    final base = (widget.media?.uri.isNotEmpty == true)
        ? widget.media!.uri
        : (widget.document?.docUri?.toString() ?? widget.src);
    final uri = gingacc.resolveUri(path, base);
    final resolvedPath =
        uri.isScheme('file') ? uri.toFilePath() : uri.toString();
    if (gingacc.virtualFiles != null) {
      final vf =
          gingacc.virtualFiles![resolvedPath] ?? gingacc.virtualFiles![path];
      if (vf != null) {
        if (vf.startsWith('data:')) {
          final comma = vf.indexOf(',');
          if (comma != -1) {
            return MemoryImage(base64.decode(vf.substring(comma + 1)));
          }
        }
        return MemoryImage(Uint8List.fromList(utf8.encode(vf)));
      }
    }
    final file = File(resolvedPath);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return FileImage(File(path));
  }

  void _loadImage(String path) {
    if (canvasState.imageCache.containsKey(path) ||
        _loadingImages.contains(path)) {
      return;
    }
    _loadingImages.add(path);
    final provider = _resolveImageProvider(path);
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        _loadingImages.remove(path);
        canvasState.imageCache[path] = info.image;
        if (!synchronousCall && mounted) {
          setState(() {});
        }
      },
      onError: (dynamic error, StackTrace? stackTrace) {
        _loadingImages.remove(path);
      },
    );
    stream.addListener(listener);
  }

  (double, double)? _getImageSize(String path) {
    _loadImage(path);
    final cached = canvasState.imageCache[path];
    if (cached != null) {
      return (cached.width.toDouble(), cached.height.toDouble());
    }
    final gingacc = widget.gingacc ?? widget.document?.gingacc ?? GingaCC();
    final base = (widget.media?.uri.isNotEmpty == true)
        ? widget.media!.uri
        : (widget.document?.docUri?.toString() ?? widget.src);
    final uri = gingacc.resolveUri(path, base);
    final resolvedPath =
        uri.isScheme('file') ? uri.toFilePath() : uri.toString();
    if (gingacc.virtualFiles != null) {
      final vf =
          gingacc.virtualFiles![resolvedPath] ?? gingacc.virtualFiles![path];
      if (vf != null) {
        final bytes = vf.startsWith('data:') && vf.contains(',')
            ? base64.decode(vf.substring(vf.indexOf(',') + 1))
            : Uint8List.fromList(utf8.encode(vf));
        final dims = parseImageDimensions(bytes);
        if (dims != null) return dims;
      }
    }
    final file = File(resolvedPath);
    if (file.existsSync()) {
      try {
        final bytes = file.readAsBytesSync();
        return parseImageDimensions(bytes);
      } catch (_) {}
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_scriptRan) {
      _scriptRan = true;
      _runScript();
    }
  }

  Future<void> _runScript() async {
    canvasState.reset();
    try {
      final gingacc = widget.gingacc ?? widget.document?.gingacc ?? GingaCC();
      final script = await gingacc.loadContent(widget.src);
      if (script != null) {
        await _engine.execute(script);
        if (widget.media == null ||
            widget.media?.getMainState() == NclStateType.occurring) {
          _engine.start();
        }
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint("Lua Runtime Error: $e");
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    return ClipRect(
      child: SizedBox.expand(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _LuaPainter(canvasState.commands),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

abstract class DrawCommand {
  Paint get paint;
  void draw(Canvas canvas);
}

class DrawRectCommand extends DrawCommand {
  final Rect rect;
  @override
  final Paint paint;
  DrawRectCommand(this.rect, this.paint);

  @override
  void draw(Canvas canvas) {
    canvas.drawRect(rect, paint);
  }
}

class DrawLineCommand extends DrawCommand {
  final Offset p1;
  final Offset p2;
  @override
  final Paint paint;
  DrawLineCommand(this.p1, this.p2, this.paint);

  @override
  void draw(Canvas canvas) {
    canvas.drawLine(p1, p2, paint);
  }
}

class DrawRoundRectCommand extends DrawCommand {
  final RRect rrect;
  @override
  final Paint paint;
  DrawRoundRectCommand(this.rrect, this.paint);

  @override
  void draw(Canvas canvas) {
    canvas.drawRRect(rrect, paint);
  }
}

class DrawPolygonCommand extends DrawCommand {
  final List<Offset> points;
  @override
  final Paint paint;
  DrawPolygonCommand(this.points, this.paint);

  @override
  void draw(Canvas canvas) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}

class DrawEllipseCommand extends DrawCommand {
  final Rect rect;
  @override
  final Paint paint;
  DrawEllipseCommand(this.rect, this.paint);

  @override
  void draw(Canvas canvas) {
    canvas.drawOval(rect, paint);
  }
}

class DrawTextCommand extends DrawCommand {
  final String text;
  final Offset offset;
  final Color color;
  final String fontFamily;
  final double fontSize;
  final String fontStyle;
  final String fontWeight;

  DrawTextCommand({
    required this.text,
    required this.offset,
    required this.color,
    this.fontFamily = 'default',
    this.fontSize = 14.0,
    this.fontStyle = 'normal',
    this.fontWeight = 'normal',
  });

  @override
  Paint get paint => Paint()..color = color;

  @override
  void draw(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize > 0 ? fontSize : 14.0,
          fontFamily: (fontFamily.isNotEmpty && fontFamily != 'default')
              ? fontFamily
              : null,
          fontWeight: (fontWeight == 'bold' || fontWeight == '700')
              ? FontWeight.bold
              : FontWeight.normal,
          fontStyle:
              fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }
}

class DrawTextRectCommand extends DrawCommand {
  final String text;
  final Rect rect;
  final Color color;
  final String halign;
  final String valign;
  final String fontFamily;
  final double fontSize;
  final String fontStyle;
  final String fontWeight;

  DrawTextRectCommand({
    required this.text,
    required this.rect,
    required this.color,
    required this.halign,
    required this.valign,
    this.fontFamily = 'default',
    this.fontSize = 14.0,
    this.fontStyle = 'normal',
    this.fontWeight = 'normal',
  });

  @override
  Paint get paint => Paint()..color = color;

  @override
  void draw(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize > 0 ? fontSize : 14.0,
          fontFamily: (fontFamily.isNotEmpty && fontFamily != 'default')
              ? fontFamily
              : null,
          fontWeight: (fontWeight == 'bold' || fontWeight == '700')
              ? FontWeight.bold
              : FontWeight.normal,
          fontStyle:
              fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width);

    double dx = rect.left;
    if (halign == 'center') {
      dx += (rect.width - textPainter.width) / 2;
    } else if (halign == 'right') {
      dx += rect.width - textPainter.width;
    }

    double dy = rect.top;
    if (valign == 'center') {
      dy += (rect.height - textPainter.height) / 2;
    } else if (valign == 'bottom') {
      dy += rect.height - textPainter.height;
    }

    textPainter.paint(canvas, Offset(dx, dy));
  }
}

class DrawComposeCommand extends DrawCommand {
  final String imagePath;
  final double dx;
  final double dy;
  final double? sx;
  final double? sy;
  final double? sw;
  final double? sh;
  final ui.Image? image;
  final Map<String, ui.Image>? imageCache;
  final Paint? customPaint;

  DrawComposeCommand({
    required this.imagePath,
    required this.dx,
    required this.dy,
    this.sx,
    this.sy,
    this.sw,
    this.sh,
    this.image,
    this.imageCache,
    this.customPaint,
  });

  @override
  Paint get paint => customPaint ?? Paint();

  @override
  void draw(Canvas canvas) {
    final effectiveImage = image ?? imageCache?[imagePath];
    if (effectiveImage == null) return;
    final srcRect = (sx != null && sy != null && sw != null && sh != null)
        ? Rect.fromLTWH(sx!, sy!, sw!, sh!)
        : Rect.fromLTWH(
            0, 0, effectiveImage.width.toDouble(), effectiveImage.height.toDouble());
    final dstWidth = sw ?? effectiveImage.width.toDouble();
    final dstHeight = sh ?? effectiveImage.height.toDouble();
    final dstRect = Rect.fromLTWH(dx, dy, dstWidth, dstHeight);
    canvas.drawImageRect(effectiveImage, srcRect, dstRect, paint);
  }
}

class CanvasState implements NclCanvasDelegate {
  final List<DrawCommand> commands = [];
  Color currentColor = Colors.black;
  String currentFontFamily = 'default';
  double currentFontSize = 14.0;
  String currentFontStyle = 'normal';
  String currentFontWeight = 'normal';
  final Map<String, ui.Image> imageCache = {};
  VoidCallback? onUpdate;
  void Function(String path)? imageLoader;

  void reset() {
    commands.clear();
    currentColor = Colors.black;
    currentFontFamily = 'default';
    currentFontSize = 14.0;
    currentFontStyle = 'normal';
    currentFontWeight = 'normal';
  }

  @override
  void attrColor(int r, int g, int b, int a) {
    currentColor = Color.fromARGB(a, r, g, b);
  }

  @override
  void attrFont(String family, double size, String style, String weight) {
    currentFontFamily = family;
    currentFontSize = size;
    currentFontStyle = style;
    currentFontWeight = weight;
  }

  @override
  void drawRect(String mode, double x, double y, double w, double h) {
    commands.add(DrawRectCommand(Rect.fromLTWH(x, y, w, h), _buildPaint(mode)));
    onUpdate?.call();
  }

  @override
  void drawLine(double x1, double y1, double x2, double y2) {
    final paint = Paint()
      ..color = currentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    commands.add(DrawLineCommand(Offset(x1, y1), Offset(x2, y2), paint));
    onUpdate?.call();
  }

  @override
  void drawRoundRect(String mode, double x, double y, double w, double h,
      double rx, double ry) {
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h), Radius.elliptical(rx, ry));
    commands.add(DrawRoundRectCommand(rrect, _buildPaint(mode)));
    onUpdate?.call();
  }

  @override
  void drawPolygon(List<double> points) {
    final List<Offset> offsets = [];
    for (int i = 0; i < points.length - 1; i += 2) {
      offsets.add(Offset(points[i], points[i + 1]));
    }
    commands.add(DrawPolygonCommand(offsets, _buildPaint('fill')));
    onUpdate?.call();
  }

  @override
  void drawEllipse(String mode, double x, double y, double w, double h) {
    commands
        .add(DrawEllipseCommand(Rect.fromLTWH(x, y, w, h), _buildPaint(mode)));
    onUpdate?.call();
  }

  @override
  void drawText(String text, double x, double y) {
    commands.add(DrawTextCommand(
      text: text,
      offset: Offset(x, y),
      color: currentColor,
      fontFamily: currentFontFamily,
      fontSize: currentFontSize,
      fontStyle: currentFontStyle,
      fontWeight: currentFontWeight,
    ));
    onUpdate?.call();
  }

  @override
  void drawTextRect(String text, double x, double y, double w, double h,
      String halign, String valign) {
    commands.add(DrawTextRectCommand(
      text: text,
      rect: Rect.fromLTWH(x, y, w, h),
      color: currentColor,
      halign: halign,
      valign: valign,
      fontFamily: currentFontFamily,
      fontSize: currentFontSize,
      fontStyle: currentFontStyle,
      fontWeight: currentFontWeight,
    ));
    onUpdate?.call();
  }

  @override
  void compose(String otherId, double x, double y,
      [double? sx, double? sy, double? sw, double? sh]) {
    imageLoader?.call(otherId);
    final img = imageCache[otherId];
    commands.add(DrawComposeCommand(
      imagePath: otherId,
      dx: x,
      dy: y,
      sx: sx,
      sy: sy,
      sw: sw,
      sh: sh,
      image: img,
      imageCache: imageCache,
    ));
    onUpdate?.call();
  }

  @override
  void clear() {
    commands.clear();
    onUpdate?.call();
  }

  @override
  void flush() {
    onUpdate?.call();
  }

  Paint _buildPaint(String mode) {
    final paint = Paint()..color = currentColor;
    if (mode == 'frame') {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.0;
    } else {
      paint.style = PaintingStyle.fill;
    }
    return paint;
  }
}

class _LuaPainter extends CustomPainter {
  final List<DrawCommand> commands;

  _LuaPainter(this.commands);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final command in commands) {
      command.draw(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LuaPainter oldDelegate) {
    return true;
  }
}
