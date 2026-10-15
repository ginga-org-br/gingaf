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
    }
  } catch (_) {}
  return _getSessionStorageItem('GINGA_APP');
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
            return dartified.map((k, v) => MapEntry(k.toString(), v.toString()));
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
              return dartified.map((k, v) => MapEntry(k.toString(), v.toString()));
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

