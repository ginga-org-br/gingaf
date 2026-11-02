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
    final query = Uri.parse(web.window.location.href).queryParameters;
    final queryApp = query['ginga_app'] ?? query['app'];
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
