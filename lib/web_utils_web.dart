import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart' as web;

String? _getSessionStorageItem(String key) {
  try {
    final localVal = web.window.sessionStorage.getItem(key);
    if (localVal != null && localVal.isNotEmpty) return localVal;
  } catch (_) {}
  try {
    final parent = web.window.parent;
    if (parent != null && parent != web.window) {
      final parentVal = parent.sessionStorage.getItem(key);
      if (parentVal != null && parentVal.isNotEmpty) return parentVal;
    }
  } catch (_) {}
  return null;
}

String? _extractAppFromObject(JSObject? obj) {
  if (obj == null) return null;
  if (obj.hasProperty('app'.toJS).toDart) {
    final val = obj.getProperty<JSAny?>('app'.toJS)?.dartify()?.toString();
    if (val != null && val.isNotEmpty) return val;
  }
  if (obj.hasProperty('currentApp'.toJS).toDart) {
    final val =
        obj.getProperty<JSAny?>('currentApp'.toJS)?.dartify()?.toString();
    if (val != null && val.isNotEmpty) return val;
  }
  if (obj.hasProperty('appPath'.toJS).toDart) {
    final val = obj.getProperty<JSAny?>('appPath'.toJS)?.dartify()?.toString();
    if (val != null && val.isNotEmpty) return val;
  }
  return null;
}

String? getGingaApp() {
  try {
    final uri = Uri.parse(web.window.location.href);
    final query = uri.queryParameters;
    var queryApp = query['ginga_app'] ??
        query['app'] ??
        query['src'] ??
        query['appSrc'];
    if (queryApp == null || queryApp.isEmpty) {
      if (uri.hasFragment && uri.fragment.contains('=')) {
        final fragUri = Uri.parse('http://dummy/?${uri.fragment}');
        queryApp = fragUri.queryParameters['ginga_app'] ??
            fragUri.queryParameters['app'] ??
            fragUri.queryParameters['src'];
      }
    }
    if (queryApp != null && queryApp.isNotEmpty) {
      return queryApp;
    }
  } catch (_) {}
  try {
    if (web.window.hasProperty('Ginga'.toJS).toDart) {
      final val = _extractAppFromObject(
          web.window.getProperty<JSObject?>('Ginga'.toJS));
      if (val != null && val.isNotEmpty) return val;
    }
    if (web.window.hasProperty('GingaApp'.toJS).toDart) {
      final val = _extractAppFromObject(
          web.window.getProperty<JSObject?>('GingaApp'.toJS));
      if (val != null && val.isNotEmpty) return val;
    }
  } catch (_) {}
  try {
    final parent = web.window.parent;
    if (parent != null && parent != web.window) {
      if (parent.hasProperty('Ginga'.toJS).toDart) {
        final val =
            _extractAppFromObject(parent.getProperty<JSObject?>('Ginga'.toJS));
        if (val != null && val.isNotEmpty) return val;
      }
      if (parent.hasProperty('GingaApp'.toJS).toDart) {
        final val = _extractAppFromObject(
            parent.getProperty<JSObject?>('GingaApp'.toJS));
        if (val != null && val.isNotEmpty) return val;
      }
      final parentSessionVal = parent.sessionStorage.getItem('GINGA_APP');
      if (parentSessionVal != null && parentSessionVal.isNotEmpty) {
        return parentSessionVal;
      }
    }
  } catch (_) {}
  return null;
}

bool? getGingaPlayground() {
  try {
    final uri = Uri.parse(web.window.location.href);
    if (uri.path.contains('/playground')) {
      return true;
    }
    final query = uri.queryParameters;
    if (query.containsKey('playground') ||
        query.containsKey('ginga_playground')) {
      final val = (query['playground'] ?? query['ginga_playground'] ?? '')
          .toLowerCase();
      if (val == 'false' || val == '0' || val == 'no') return false;
      return true;
    }
    final cleanPath = uri.path.replaceAll(RegExp(r'/index\.html$'), '');
    if (cleanPath.endsWith('/gingaf') ||
        cleanPath.endsWith('/gingaf/') ||
        cleanPath.endsWith('/player') ||
        cleanPath.endsWith('/player/')) {
      return false;
    }
  } catch (_) {}
  try {
    final val = _getSessionStorageItem('GINGA_PLAYGROUND');
    if (val != null) {
      final lower = val.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
  } catch (_) {}
  return null;
}

Map<String, String>? getGingaAppFiles() {
  try {
    if (web.window.hasProperty('GingaApp'.toJS).toDart) {
      final gingaApp = web.window.getProperty<JSObject?>('GingaApp'.toJS);
      if (gingaApp != null && gingaApp.hasProperty('files'.toJS).toDart) {
        final filesObj = gingaApp.getProperty<JSObject?>('files'.toJS);
        if (filesObj != null) {
          final dartified = filesObj.dartify();
          if (dartified is Map) {
            return dartified
                .map((k, v) => MapEntry(k.toString(), v.toString()));
          }
        }
      }
    }
  } catch (_) {}
  try {
    final parent = web.window.parent;
    if (parent != null && parent != web.window) {
      if (parent.hasProperty('GingaApp'.toJS).toDart) {
        final gingaApp = parent.getProperty<JSObject?>('GingaApp'.toJS);
        if (gingaApp != null && gingaApp.hasProperty('files'.toJS).toDart) {
          final filesObj = gingaApp.getProperty<JSObject?>('files'.toJS);
          if (filesObj != null) {
            final dartified = filesObj.dartify();
            if (dartified is Map) {
              return dartified
                  .map((k, v) => MapEntry(k.toString(), v.toString()));
            }
          }
        }
      }
    }
  } catch (_) {}
  try {
    final jsonStr = _getSessionStorageItem('GINGA_PLAYGROUND_FILES');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    }
  } catch (_) {}
  return null;
}

void notifyParentAppExited() {
  try {
    web.window.parent?.postMessage('ginga_app_exited'.toJS, '*'.toJS);
  } catch (e) {
    debugPrint('Failed to notify parent app exited: $e');
  }
}

void updateWebUrlApp(String appName) {
  try {
    final uri = Uri.parse(web.window.location.href);
    final newParams = Map<String, String>.from(uri.queryParameters);
    newParams['app'] = appName;
    newParams.remove('playground');
    newParams.remove('ginga_playground');
    var currentPath = uri.path;
    if (!currentPath.contains('/playground')) {
      if (currentPath.endsWith('/')) {
        currentPath = '${currentPath}playground/';
      } else {
        currentPath = '$currentPath/playground/';
      }
    }
    final newUri = uri.replace(
      path: currentPath,
      queryParameters: newParams.isEmpty ? null : newParams,
    );
    web.window.history.replaceState(null, '', newUri.toString());
  } catch (e) {
    debugPrint('Failed to update web url app: $e');
  }
}

final StreamController<String> _tv30KeyController =
    StreamController<String>.broadcast();
final StreamController<double> _tv30TimeController =
    StreamController<double>.broadcast();
final StreamController<String> _tv30StreamEventController =
    StreamController<String>.broadcast();
bool _tv30ListenerInitialized = false;

void _ensureTv30Listener() {
  if (_tv30ListenerInitialized) return;
  _tv30ListenerInitialized = true;

  try {
    web.window.addEventListener(
      'message',
      (web.MessageEvent event) {
        try {
          final data = event.data;
          if (data == null) return;
          final dartified = data.dartify();
          if (dartified is Map) {
            final type = dartified['type']?.toString();
            if (type == 'tv30-aop-event') {
              final ev = dartified['event']?.toString();
              if (ev == 'keydown') {
                final key = dartified['key']?.toString();
                if (key != null && key.isNotEmpty) {
                  _tv30KeyController.add(key);
                }
              } else if (ev == 'timeupdate') {
                final detail = dartified['detail'];
                if (detail is num) {
                  _tv30TimeController.add(detail.toDouble());
                } else if (detail != null) {
                  final parsed = double.tryParse(detail.toString());
                  if (parsed != null) _tv30TimeController.add(parsed);
                }
              } else if (ev == 'stream_event') {
                final detail = dartified['detail'];
                if (detail != null) {
                  _tv30StreamEventController.add(detail is String
                      ? detail
                      : jsonEncode(detail));
                }
              }
            } else if (dartified.containsKey('time')) {
              final t = dartified['time'];
              if (t is num) {
                _tv30TimeController.add(t.toDouble());
              } else if (t != null) {
                final parsed = double.tryParse(t.toString());
                if (parsed != null) _tv30TimeController.add(parsed);
              }
            }
          }
        } catch (e) {
          debugPrint('Error processing TV3.0 message event: $e');
        }
      }.toJS,
    );
  } catch (e) {
    debugPrint('Failed to attach TV3.0 message listener: $e');
  }
}

Stream<String> get tv30KeyStream {
  _ensureTv30Listener();
  return _tv30KeyController.stream;
}

Stream<double> get tv30TimeStream {
  _ensureTv30Listener();
  return _tv30TimeController.stream;
}

Stream<String> get tv30StreamEventStream {
  _ensureTv30Listener();
  return _tv30StreamEventController.stream;
}

bool isTv30Mode() {
  try {
    final query = Uri.parse(web.window.location.href).queryParameters;
    if (query['tv30'] == 'true' ||
        query['tv30'] == '1' ||
        query['overlay'] == 'true' ||
        query['transparent'] == 'true') {
      return true;
    }
    final parent = web.window.parent;
    if (parent != null && parent != web.window) {
      return true;
    }
  } catch (_) {}
  return false;
}

String? mapTv30KeyToNclKey(String rawKey) {
  final k = rawKey.trim();
  final lower = k.toLowerCase();
  if (lower == 'arrowup' || lower == 'up') return 'UP';
  if (lower == 'arrowdown' || lower == 'down') return 'DOWN';
  if (lower == 'arrowleft' || lower == 'left') return 'LEFT';
  if (lower == 'arrowright' || lower == 'right') return 'RIGHT';
  if (lower == 'enter' || lower == 'select' || lower == 'ok') return 'ENTER';
  if (lower == 'f1' || lower == 'red' || lower == 'r' || lower == 'colorf0red') {
    return 'RED';
  }
  if (lower == 'f2' ||
      lower == 'green' ||
      lower == 'g' ||
      lower == 'colorf1green') {
    return 'GREEN';
  }
  if (lower == 'f3' ||
      lower == 'yellow' ||
      lower == 'y' ||
      lower == 'colorf2yellow') {
    return 'YELLOW';
  }
  if (lower == 'f4' || lower == 'blue' || lower == 'b' || lower == 'colorf3blue') {
    return 'BLUE';
  }
  if (lower == 'f5' || lower == 'info' || lower == 'i') return 'INFO';
  if (lower == 'escape' || lower == 'back' || lower == 'exit') return 'ESCAPE';
  if (RegExp(r'^[0-9]$').hasMatch(k)) return k;
  return null;
}
