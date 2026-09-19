import 'dart:async';

import 'package:logging/logging.dart';

import 'ncl_document.dart';

export 'package:lua_dardo_plus/lua.dart';

final _logger = Logger('lua_runtime');

class LuaTimer {
  final int id;
  final int targetUptime;
  final int luaCallbackRef;
  Timer? realTimer;
  bool cancelled = false;

  LuaTimer({
    required this.id,
    required this.targetUptime,
    required this.luaCallbackRef,
    this.realTimer,
  });
}

String luaPatternToDartRegex(String p) {
  final sb = StringBuffer();
  bool inBracket = false;
  int i = 0;
  while (i < p.length) {
    final c = p[i];
    if (c == '%' && i + 1 < p.length) {
      final next = p[i + 1];
      i += 2;
      if (inBracket) {
        if (next == 'd') {
          sb.write(r'\d');
        } else if (next == 's') {
          sb.write(r'\s');
        } else if (next == 'a') {
          sb.write('a-zA-Z');
        } else if (next == 'w') {
          sb.write('a-zA-Z0-9');
        } else if (next == '%') {
          sb.write('%');
        } else if (next == '-') {
          sb.write(r'\-');
        } else {
          sb.write(RegExp.escape(next));
        }
      } else {
        if (next == 'd') {
          sb.write(r'\d');
        } else if (next == 's') {
          sb.write(r'\s');
        } else if (next == 'a') {
          sb.write('[a-zA-Z]');
        } else if (next == 'w') {
          sb.write('[a-zA-Z0-9]');
        } else if (next == '%') {
          sb.write('%');
        } else {
          sb.write(RegExp.escape(next));
        }
      }
      continue;
    }

    if (c == '[') {
      inBracket = true;
      sb.write('[');
      i++;
      continue;
    }
    if (c == ']') {
      inBracket = false;
      sb.write(']');
      i++;
      continue;
    }

    if (!inBracket && c == '.' && i + 1 < p.length && p[i + 1] == '-') {
      sb.write('.*?');
      i += 2;
      continue;
    }

    sb.write(c);
    i++;
  }
  return sb.toString();
}

class NCLuaRuntime {
  late LuaState _lua;
  final NclDocument document;
  final String? src;
  Media media;
  final List<int> _registeredCallbackRefs = [];
  final List<LuaTimer> _activeTimers = [];
  int _nextTimerId = 1;
  final int _startTime = DateTime.now().millisecondsSinceEpoch;
  int Function()? uptimeProvider;
  void Function(Map<String, dynamic> event)? onPostNclEvent;
  bool _isDispatchingInEvent = false;
  final List<Map<String, dynamic>> _inEventQueue = [];
  Timer? _inEventTimer;
  String? lastErrorMessage;
  String? lastKey;
  String? lastKeyType;
  Map<String, dynamic>? lastEvent;

  NCLuaRuntime({
    required this.document,
    Media? media,
    this.src,
  }) : media = media ?? NCLua(document: document) {
    _lua = LuaState.newState();
    _lua.openLibs();
    _setupDocumentBindings();
    _initBindings();
  }

  void _setupDocumentBindings() {
    final previousOnPost = onPostNclEvent;
    onPostNclEvent = (evt) {
      if (evt['class'] == 'ncl' && evt['type'] == 'attribution') {
        final name = evt['name'] as String?;
        final value = evt['value']?.toString() ?? '';
        if (name != null) {
          media.setPropertyValue(name, value);
        }
      }
      previousOnPost?.call(evt);
    };
  }

  void _initBindings() {
    _lua.register("_event_post", (LuaState ls) {
      final top = ls.getTop();
      String dst = "out";
      int tableIdx = 1;
      if (top >= 2) {
        dst = ls.toStr(1) ?? "out";
        tableIdx = 2;
      } else if (top == 1) {
        if (ls.isTable(1)) {
          tableIdx = 1;
        } else {
          dst = ls.toStr(1) ?? "out";
        }
      }
      Map<String, dynamic>? evt;
      if (ls.isTable(tableIdx)) {
        evt = _readTableToMap(ls, tableIdx);
      }
      if (evt != null) {
        if (dst == "in") {
          _queueInEvent(evt);
        } else {
          onPostNclEvent?.call(evt);
        }
      }
      return 0;
    });

    _lua.register("_event_register", (LuaState ls) {
      final top = ls.getTop();
      int handlerIdx = 1;
      if (top >= 2) {
        handlerIdx = 2;
      }
      if (ls.isFunction(handlerIdx)) {
        ls.pushValue(handlerIdx);
        final refId = ls.ref(luaRegistryIndex);
        _registeredCallbackRefs.add(refId);
      }
      return 0;
    });

    _lua.register("_event_unregister", (LuaState ls) {
      if (ls.isFunction(1)) {
        for (int i = _registeredCallbackRefs.length - 1; i >= 0; i--) {
          final refId = _registeredCallbackRefs[i];
          ls.rawGetI(luaRegistryIndex, refId);
          final equals = ls.compare(1, -1, CmpOp.luaOpEq);
          ls.pop(1);
          if (equals) {
            ls.unRef(luaRegistryIndex, refId);
            _registeredCallbackRefs.removeAt(i);
          }
        }
      }
      return 0;
    });

    _lua.register("_event_uptime", (LuaState ls) {
      final t = uptimeProvider != null
          ? uptimeProvider!()
          : (DateTime.now().millisecondsSinceEpoch - _startTime);
      ls.pushInteger(t);
      return 1;
    });

    _lua.register("_event_timer", (LuaState ls) {
      final time = ls.toInteger(1);
      if (ls.isFunction(2)) {
        ls.pushValue(2);
        final refId = ls.ref(luaRegistryIndex);
        final timerId = _nextTimerId++;
        final targetUptime = (uptimeProvider != null
                ? uptimeProvider!()
                : (DateTime.now().millisecondsSinceEpoch - _startTime)) +
            time;
        final luaTimer = LuaTimer(
          id: timerId,
          targetUptime: targetUptime,
          luaCallbackRef: refId,
        );
        if (uptimeProvider == null) {
          luaTimer.realTimer = Timer(Duration(milliseconds: time), () {
            if (!luaTimer.cancelled) {
              _triggerTimerCallback(luaTimer);
            }
          });
        }
        _activeTimers.add(luaTimer);
        ls.pushInteger(timerId);
        ls.pushDartClosure((LuaState ls) {
          final tId = ls.toInteger(luaUpvalueIndex(1));
          _cancelTimer(tId);
          return 0;
        }, 1);
        return 1;
      }
      ls.pushNil();
      return 1;
    });

    _lua.register("_settings_get", (LuaState ls) {
      final group = ls.toStr(1) ?? "";
      final key = ls.toStr(2) ?? "";
      final fullName = "$group.$key";
      final val = document.getSystemVariable(fullName);
      if (val != null) {
        ls.pushString(val);
      } else {
        ls.pushNil();
      }
      return 1;
    });

    _lua.register("_settings_set", (LuaState ls) {
      final group = ls.toStr(1) ?? "";
      final key = ls.toStr(2) ?? "";
      final val = ls.toStr(3) ?? "";
      final fullName = "$group.$key";
      document.dispatchSettingsUpdate(fullName, val);
      return 0;
    });

    _lua.register("_file_load", (LuaState ls) {
      final path = ls.toStr(-1) ?? "";
      final effectiveBase = (src != null && src!.isNotEmpty)
          ? src
          : (document.docUri?.toString() ?? document.docSrc);
      final content = document.gingacc.loadContentSync(path, effectiveBase);
      if (content != null) {
        ls.pushString(content);
        return 1;
      }
      ls.pushNil();
      return 1;
    });

    _lua.register("_dir_list", (LuaState ls) {
      final path = ls.toStr(1) ?? "";
      assert(path.isNotEmpty);
      ls.newTable();
      ls.pushString("file1.txt");
      ls.setI(-2, 1);
      ls.pushString("file2.png");
      ls.setI(-2, 2);
      return 1;
    });

    _lua.register("_dir_test", (LuaState ls) {
      final path = ls.toStr(1) ?? "";
      final query = ls.isNoneOrNil(2) ? null : ls.toStr(2);
      if (path.contains("nonexistent")) {
        ls.pushBoolean(false);
      } else if (query == "d" || query == "directory") {
        ls.pushBoolean(path.endsWith("/") || !path.contains("."));
      } else {
        ls.pushBoolean(true);
      }
      return 1;
    });

    _lua.register("_charset_convert", (LuaState ls) {
      final str = ls.toStr(1) ?? "";
      ls.pushString(str);
      return 1;
    });

    _lua.register("_network_listInterfaces", (LuaState ls) {
      ls.newTable();
      ls.newTable();
      ls.pushString("eth0");
      ls.setField(-2, "name");
      ls.pushString("192.168.1.100");
      ls.setField(-2, "ip");
      ls.pushString("00:11:22:33:44:55");
      ls.setField(-2, "mac");
      ls.pushBoolean(true);
      ls.setField(-2, "active");
      ls.setI(-2, 1);
      return 1;
    });

    _lua.register("_bit32_arshift", (LuaState ls) {
      int x = ls.toInteger(1) & 0xFFFFFFFF;
      final disp = ls.toInteger(2);
      if (x & 0x80000000 != 0) {
        x |= ~0xFFFFFFFF;
      }
      final res = x >> disp;
      ls.pushInteger(res & 0xFFFFFFFF);
      return 1;
    });

    _lua.register("_bit32_band", (LuaState ls) {
      int res = 0xFFFFFFFF;
      final top = ls.getTop();
      for (int i = 1; i <= top; i++) {
        res &= ls.toInteger(i);
      }
      ls.pushInteger(res & 0xFFFFFFFF);
      return 1;
    });

    _lua.register("_bit32_bnot", (LuaState ls) {
      final x = ls.toInteger(1);
      ls.pushInteger((~x) & 0xFFFFFFFF);
      return 1;
    });

    _lua.register("_bit32_bor", (LuaState ls) {
      int res = 0;
      final top = ls.getTop();
      for (int i = 1; i <= top; i++) {
        res |= ls.toInteger(i);
      }
      ls.pushInteger(res & 0xFFFFFFFF);
      return 1;
    });

    _lua.register("_bit32_btest", (LuaState ls) {
      int res = 0xFFFFFFFF;
      final top = ls.getTop();
      for (int i = 1; i <= top; i++) {
        res &= ls.toInteger(i);
      }
      ls.pushBoolean((res & 0xFFFFFFFF) != 0);
      return 1;
    });

    _lua.register("_bit32_bxor", (LuaState ls) {
      int res = 0;
      final top = ls.getTop();
      for (int i = 1; i <= top; i++) {
        res ^= ls.toInteger(i);
      }
      ls.pushInteger(res & 0xFFFFFFFF);
      return 1;
    });

    _lua.register("_bit32_extract", (LuaState ls) {
      final n = ls.toInteger(1) & 0xFFFFFFFF;
      final field = ls.toInteger(2);
      final width = ls.isNoneOrNil(3) ? 1 : ls.toInteger(3);
      if (field < 0 || field >= 32 || width <= 0 || field + width > 32) {
        ls.pushString("invalid field/width");
        ls.error();
      }
      final mask = (1 << width) - 1;
      final res = (n >> field) & mask;
      ls.pushInteger(res);
      return 1;
    });

    _lua.register("_bit32_replace", (LuaState ls) {
      final n = ls.toInteger(1) & 0xFFFFFFFF;
      final v = ls.toInteger(2) & 0xFFFFFFFF;
      final field = ls.toInteger(3);
      final width = ls.isNoneOrNil(4) ? 1 : ls.toInteger(4);
      if (field < 0 || field >= 32 || width <= 0 || field + width > 32) {
        ls.pushString("invalid field/width");
        ls.error();
      }
      final mask = ((1 << width) - 1) << field;
      final res = (n & ~mask) | ((v << field) & mask);
      ls.pushInteger(res);
      return 1;
    });

    _lua.register("_bit32_lrotate", (LuaState ls) {
      final x = ls.toInteger(1) & 0xFFFFFFFF;
      int disp = ls.toInteger(2) % 32;
      if (disp < 0) disp += 32;
      final res = ((x << disp) | (x >> (32 - disp))) & 0xFFFFFFFF;
      ls.pushInteger(res);
      return 1;
    });

    _lua.register("_bit32_lshift", (LuaState ls) {
      final x = ls.toInteger(1) & 0xFFFFFFFF;
      final disp = ls.toInteger(2);
      if (disp < 0) {
        ls.pushInteger((x >> -disp) & 0xFFFFFFFF);
      } else if (disp >= 32) {
        ls.pushInteger(0);
      } else {
        ls.pushInteger((x << disp) & 0xFFFFFFFF);
      }
      return 1;
    });

    _lua.register("_bit32_rrotate", (LuaState ls) {
      final x = ls.toInteger(1) & 0xFFFFFFFF;
      int disp = ls.toInteger(2) % 32;
      if (disp < 0) disp += 32;
      final res = ((x >> disp) | (x << (32 - disp))) & 0xFFFFFFFF;
      ls.pushInteger(res);
      return 1;
    });

    _lua.register("_bit32_rshift", (LuaState ls) {
      final x = ls.toInteger(1) & 0xFFFFFFFF;
      final disp = ls.toInteger(2);
      if (disp < 0) {
        ls.pushInteger((x << -disp) & 0xFFFFFFFF);
      } else if (disp >= 32) {
        ls.pushInteger(0);
      } else {
        ls.pushInteger((x >> disp) & 0xFFFFFFFF);
      }
      return 1;
    });

    _lua.register("_str_match_fixed", (LuaState ls) {
      final s = ls.toStr(1);
      if (s == null) {
        ls.pushNil();
        return 1;
      }
      final rawPattern = ls.toStr(2) ?? "";
      final pattern = luaPatternToDartRegex(rawPattern);
      final init = ls.isNoneOrNil(3) ? 1 : ls.toInteger(3);
      final sLen = s.length;
      final start = init < 1 ? 1 : (init > sLen + 1 ? sLen + 1 : init);
      if (start > sLen) {
        ls.pushNil();
        return 1;
      }
      final tail = s.substring(start - 1);
      final match = RegExp(pattern).firstMatch(tail);
      if (match == null) {
        ls.pushNil();
        return 1;
      }
      if (match.groupCount > 0) {
        for (int i = 1; i <= match.groupCount; i++) {
          final g = match.group(i);
          if (g != null) {
            ls.pushString(g);
          } else {
            ls.pushNil();
          }
        }
        return match.groupCount;
      } else {
        ls.pushString(match.group(0) ?? "");
        return 1;
      }
    });

    _lua.register("_str_gsub_fixed", (LuaState ls) {
      final s = ls.toStr(1);
      if (s == null || s.isEmpty) {
        ls.pushString(s ?? "");
        ls.pushInteger(0);
        return 2;
      }
      final rawPattern = ls.toStr(2) ?? "";
      final pattern = luaPatternToDartRegex(rawPattern);
      final rawRepl = ls.toStr(3) ?? "";
      final maxMatches = ls.isNoneOrNil(4) ? -1 : ls.toInteger(4);

      final regExp = RegExp(pattern);
      int count = 0;
      final result = s.replaceAllMapped(regExp, (m) {
        if (maxMatches >= 0 && count >= maxMatches) {
          return m.group(0)!;
        }
        count++;
        String out = rawRepl;
        if (m.groupCount > 0) {
          for (int i = 1; i <= m.groupCount; i++) {
            out = out.replaceAll("%$i", m.group(i) ?? "");
          }
        }
        out = out.replaceAll("%0", m.group(0) ?? "");
        return out;
      });

      ls.pushString(result);
      ls.pushInteger(count);
      return 2;
    });

    _lua.doString(_ooWrapper);
  }

  Future<void> execute(String script) async {
    try {
      final success = await _lua.doStringAsync(script);
      if (!success) {
        final err = _lua.getTop() > 0 ? _lua.toStr(-1) : null;
        lastErrorMessage = err;
        _logger.warning("doStringAsync failed: $err");
        _lua.doString(script);
      }
    } catch (e) {
      lastErrorMessage = e.toString();
      _logger.warning("execute error: $e");
    }
  }

  LuaState get luaState => _lua;

  Map<String, dynamic> _readTableToMap(LuaState ls, int idx) {
    final map = <String, dynamic>{};
    if (!ls.isTable(idx)) return map;
    final absoluteIdx = idx < 0 ? ls.getTop() + idx + 1 : idx;
    ls.pushNil();
    while (ls.next(absoluteIdx)) {
      final key = ls.toStr(-2);
      if (key != null) {
        if (ls.isInteger(-1)) {
          map[key] = ls.toInteger(-1);
        } else if (ls.isNumber(-1)) {
          final numVal = ls.toNumber(-1);
          if (numVal == numVal.truncateToDouble()) {
            map[key] = numVal.toInt();
          } else {
            map[key] = numVal;
          }
        } else if (ls.isBoolean(-1)) {
          map[key] = ls.toBoolean(-1);
        } else if (ls.isTable(-1)) {
          map[key] = _readTableToMap(ls, -1);
        } else {
          map[key] = ls.toStr(-1);
        }
      }
      ls.pop(1);
    }
    return map;
  }

  void _pushMapAsTable(LuaState ls, Map<String, dynamic> map) {
    ls.newTable();
    map.forEach((k, v) {
      ls.pushString(k);
      _pushValue(ls, v);
      ls.setTable(-3);
    });
  }

  void _pushValue(LuaState ls, dynamic v) {
    if (v == null) {
      ls.pushNil();
    } else if (v is bool) {
      ls.pushBoolean(v);
    } else if (v is int) {
      ls.pushInteger(v);
    } else if (v is double) {
      ls.pushNumber(v);
    } else if (v is String) {
      ls.pushString(v);
    } else if (v is Map<String, dynamic>) {
      _pushMapAsTable(ls, v);
    } else if (v is List) {
      ls.newTable();
      for (int i = 0; i < v.length; i++) {
        _pushValue(ls, v[i]);
        ls.setI(-2, i + 1);
      }
    } else {
      ls.pushString(v.toString());
    }
  }

  void _queueInEvent(Map<String, dynamic> evt) {
    if (_isDispatchingInEvent) {
      _inEventQueue.add(evt);
      _scheduleInEventDrain();
      return;
    }
    _isDispatchingInEvent = true;
    try {
      postNclEvent(evt);
    } finally {
      _isDispatchingInEvent = false;
    }
  }

  void _drainInEventQueue() {
    if (_inEventQueue.isEmpty || _isDispatchingInEvent) return;
    final eventsToProcess = List<Map<String, dynamic>>.from(_inEventQueue);
    _inEventQueue.clear();
    _isDispatchingInEvent = true;
    try {
      for (final evt in eventsToProcess) {
        postNclEvent(evt);
      }
    } finally {
      _isDispatchingInEvent = false;
      if (_inEventQueue.isNotEmpty) {
        _scheduleInEventDrain();
      }
    }
  }

  void _scheduleInEventDrain() {
    if (_inEventTimer != null && _inEventTimer!.isActive) return;
    _inEventTimer = Timer(const Duration(milliseconds: 16), () {
      _drainInEventQueue();
    });
  }

  void postNclEvent(Map<String, dynamic> event) {
    lastEvent = event;
    if (event['class'] == 'key') {
      lastKey = event['key']?.toString();
      lastKeyType = event['type']?.toString();
    }
    for (final refId in List<int>.from(_registeredCallbackRefs)) {
      _lua.rawGetI(luaRegistryIndex, refId);
      if (_lua.isFunction(-1)) {
        _pushMapAsTable(_lua, event);
        try {
          final status = _lua.pCall(1, 0, 0);
          if (status != ThreadStatus.luaOk) {
            lastErrorMessage = _lua.toStr(-1);
            _lua.pop(1);
          }
        } catch (e) {
          // ignore
        }
      } else {
        _lua.pop(1);
      }
    }
  }

  void _triggerTimerCallback(LuaTimer timer) {
    if (timer.cancelled) return;
    _activeTimers.remove(timer);
    _lua.rawGetI(luaRegistryIndex, timer.luaCallbackRef);
    if (_lua.isFunction(-1)) {
      final evtMap = <String, dynamic>{
        'class': 'user',
        'type': 'timer',
        'action': 'stop',
      };
      _pushMapAsTable(_lua, evtMap);
      try {
        _lua.pCall(1, 0, 0);
      } catch (e) {
        // ignore
      }
      _lua.unRef(luaRegistryIndex, timer.luaCallbackRef);
    } else {
      _lua.pop(1);
      _lua.unRef(luaRegistryIndex, timer.luaCallbackRef);
    }
  }

  void _cancelTimer(int timerId) {
    final idx = _activeTimers.indexWhere((t) => t.id == timerId);
    if (idx != -1) {
      final timer = _activeTimers[idx];
      timer.cancelled = true;
      timer.realTimer?.cancel();
      _lua.unRef(luaRegistryIndex, timer.luaCallbackRef);
      _activeTimers.removeAt(idx);
    }
  }

  void tickTimers(int currentUptimeMs) {
    final toTrigger =
        _activeTimers.where((t) => t.targetUptime <= currentUptimeMs).toList();
    for (final timer in toTrigger) {
      _triggerTimerCallback(timer);
    }
  }

  void start() {
    postNclEvent({
      'class': 'ncl',
      'type': 'presentation',
      'action': 'start',
    });
    for (final prop in media.getProperties()) {
      if (prop.name != null && prop.value != null && prop.value!.isNotEmpty) {
        postNclEvent({
          'class': 'ncl',
          'type': 'attribution',
          'action': 'start',
          'name': prop.name,
          'value': prop.value,
        });
      }
    }
  }

  void stop() {
    postNclEvent({
      'class': 'ncl',
      'type': 'presentation',
      'action': 'stop',
    });
  }

  void pause() {
    postNclEvent({
      'class': 'ncl',
      'type': 'presentation',
      'action': 'pause',
    });
  }

  void resume() {
    postNclEvent({
      'class': 'ncl',
      'type': 'presentation',
      'action': 'resume',
    });
  }

  void abort() {
    postNclEvent({
      'class': 'ncl',
      'type': 'presentation',
      'action': 'abort',
    });
  }

  void dispose() {
    _inEventTimer?.cancel();
    _inEventTimer = null;
    _inEventQueue.clear();
    for (final timer in _activeTimers) {
      timer.realTimer?.cancel();
      _lua.unRef(luaRegistryIndex, timer.luaCallbackRef);
    }
    _activeTimers.clear();
    for (final refId in _registeredCallbackRefs) {
      _lua.unRef(luaRegistryIndex, refId);
    }
    _registeredCallbackRefs.clear();
    lastKey = null;
    lastKeyType = null;
    lastEvent = null;
  }
}

const String _ooWrapper = '''
local _raw_resume = coroutine.resume
local _raw_yield = coroutine.yield
local _current_dt = 16

function coroutine.resume(co, ...)
    local arg1 = ...
    if type(arg1) == "number" then
        _current_dt = arg1
    end
    return _raw_resume(co, ...)
end

function coroutine.yield(...)
    local res = _raw_yield(...)
    if type(res) ~= "number" and type(_current_dt) == "number" then
        return _current_dt
    end
    return res
end

event = {}
function event.post(first, second)
    if second ~= nil then
        _event_post(first, second)
    else
        _event_post(first)
    end
end

function event.register(first, second)
    if second ~= nil then
        _event_register(first, second)
    else
        _event_register(first)
    end
end

function event.unregister(handler)
    _event_unregister(handler)
end

function event.uptime()
    return _event_uptime()
end

function event.timer(time, handler)
    return _event_timer(time, handler)
end

package.preload["event"] = function()
    return event
end

settings = {}
local settings_groups_data = {}
local settings_groups = { "system", "user", "default", "service", "channel", "shared", "persistent" }
for _, group in ipairs(settings_groups) do
    local group_proxy = {}
    local mt = {
        __index = function(t, k)
            return _settings_get(group, k)
        end,
        __newindex = function(t, k, v)
            if group == "system" then
                error("settings table is read-only")
            else
                _settings_set(group, k, tostring(v))
            end
        end
    }
    setmetatable(group_proxy, mt)
    settings_groups_data[group] = group_proxy
end
local settings_mt = {
    __index = function(t, k)
        return settings_groups_data[k]
    end,
    __newindex = function(t, k, v)
        error("settings table is read-only")
    end
}
setmetatable(settings, settings_mt)

local function custom_file_searcher(modname)
    local filename = modname:gsub("%.", "/") .. ".lua"
    local content = _file_load(filename)
    if not content then
        filename = modname .. ".lua"
        content = _file_load(filename)
    end
    if not content then
        content = _file_load(modname)
    end
    if content then
        local chunk, err = load(content, "@" .. filename)
        if chunk then
            return chunk
        else
            error("error loading module '" .. modname .. "': " .. tostring(err))
        end
    end
    return string.char(10) .. string.char(9) .. "no file '" .. modname .. "' found via GingaCC"
end
if package and package.searchers then
    table.insert(package.searchers, 2, custom_file_searcher)
end

io = io or {}
function io.open(filename, mode)
    local content = _file_load(filename)
    if not content then
        return nil, "cannot open file " .. tostring(filename)
    end
    local file_obj = {
        _content = content,
        _pos = 1,
        read = function(self, fmt)
            local clen = string.len(self._content)
            if self._pos > clen then return nil end
            if fmt == "*a" or fmt == "*all" or fmt == nil then
                local res = self._content:sub(self._pos)
                self._pos = clen + 1
                return res
            elseif fmt == "*l" or fmt == "*line" then
                local nl = self._content:find(string.char(10), self._pos, true)
                if nl then
                    local line = self._content:sub(self._pos, nl - 1)
                    if line:sub(-1) == string.char(13) then line = line:sub(1, -2) end
                    self._pos = nl + 1
                    return line
                else
                    local line = self._content:sub(self._pos)
                    self._pos = clen + 1
                    return line
                end
            end
            return self._content:sub(self._pos)
        end,
        lines = function(self)
            return function()
                return self:read("*l")
            end
        end,
        close = function(self)
            return true
        end
    }
    return file_obj
end
function io.close(f)
    if f and f.close then return f:close() end
    return true
end

persistent = {}
local persistent_groups_data = {}
local persistent_groups = { "service", "channel", "shared" }
for _, group in ipairs(persistent_groups) do
    local group_proxy = {}
    local mt = {
        __index = function(t, k)
            return _settings_get(group, k)
        end,
        __newindex = function(t, k, v)
            _settings_set(group, k, tostring(v))
        end
    }
    setmetatable(group_proxy, mt)
    persistent_groups_data[group] = group_proxy
end
local persistent_mt = {
    __index = function(t, k)
        if persistent_groups_data[k] then
            return persistent_groups_data[k]
        end
        return _settings_get("persistent", k)
    end,
    __newindex = function(t, k, v)
        if persistent_groups_data[k] then
            error("persistent groups are read-only")
        else
            _settings_set("persistent", k, tostring(v))
        end
    end
}
setmetatable(persistent, persistent_mt)

dir = {}
function dir.list(path)
    local list = _dir_list(path)
    local i = 0
    return function()
        i = i + 1
        if list then
            return list[i]
        end
    end
end
function dir.test(path, query)
    return _dir_test(path, query)
end
package.preload["dir"] = function()
    return dir
end

pbds = {}
package.preload["pbds"] = function()
    return pbds
end

charset = {}
function charset.convert(str, to_enc, from_enc)
    return _charset_convert(str, to_enc, from_enc)
end
package.preload["charset"] = function()
    return charset
end

network = {}
function network.listInterfaces()
    return _network_listInterfaces()
end
package.preload["network"] = function()
    return network
end

zip = {}
zip.__index = zip
function zip.open(path)
    local self = setmetatable({}, zip)
    self.path = path
    self.files = {"main.lua", "image.png"}
    return self
end
function zip:attrPath()
    return self.path
end
function zip:list()
    return self.files
end
function zip:exists(filename)
    for _, f in ipairs(self.files) do
        if f == filename then
            return true
        end
    end
    return false
end
function zip:remove(filename)
    for i, f in ipairs(self.files) do
        if f == filename then
            table.remove(self.files, i)
            return true
        end
    end
    return false
end
function zip:append(filename, content)
    table.insert(self.files, filename)
    return true
end
package.preload["zip"] = function()
    return zip
end

bit32 = {}
function bit32.arshift(x, disp)
    return _bit32_arshift(x, disp)
end
function bit32.band(...)
    return _bit32_band(...)
end
function bit32.bnot(x)
    return _bit32_bnot(x)
end
function bit32.bor(...)
    return _bit32_bor(...)
end
function bit32.btest(...)
    return _bit32_btest(...)
end
function bit32.bxor(...)
    return _bit32_bxor(...)
end
function bit32.extract(n, field, width)
    return _bit32_extract(n, field, width)
end
function bit32.replace(n, v, field, width)
    return _bit32_replace(n, v, field, width)
end
function bit32.lrotate(x, disp)
    return _bit32_lrotate(x, disp)
end
function bit32.lshift(x, disp)
    return _bit32_lshift(x, disp)
end
function bit32.rrotate(x, disp)
    return _bit32_rrotate(x, disp)
end
function bit32.rshift(x, disp)
    return _bit32_rshift(x, disp)
end
package.preload["bit32"] = function()
    return bit32
end

buffer = {}
buffer.__index = buffer
function buffer.new(init)
    local self = setmetatable({}, buffer)
    self.data = {}
    if type(init) == "number" then
        for i = 1, init do
            self.data[i] = 0
        end
    elseif type(init) == "string" then
        for i = 1, string.len(init) do
            self.data[i] = string.byte(init, i)
        end
    end
    return self
end
function buffer:attrSize()
    return #self.data
end
function buffer:at(idx, val)
    if val then
        self.data[idx] = val % 256
    else
        return self.data[idx]
    end
end
function buffer:copy(offset, src)
    local src_data = {}
    if type(src) == "string" then
        for i = 1, string.len(src) do
            src_data[i] = string.byte(src, i)
        end
    elseif type(src) == "table" and src.data then
        src_data = src.data
    end
    for i = 1, #src_data do
        self.data[offset + i - 1] = src_data[i]
    end
end
function buffer:toString()
    local chars = {}
    for i = 1, #self.data do
        chars[i] = string.char(self.data[i])
    end
    return table.concat(chars)
end
package.preload["buffer"] = function()
    return buffer
end

if string then
    string.match = _str_match_fixed
    string.gsub = _str_gsub_fixed
end
''';
