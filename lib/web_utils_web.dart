import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart' as web;

String? getSessionStorageItem(String key) {
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

String? getGingaAppPath() {
  try {
    if (web.window.hasProperty('GingaApp'.toJS).toDart) {
      final gingaApp = web.window.getProperty<JSObject?>('GingaApp'.toJS);
      if (gingaApp != null && gingaApp.hasProperty('appPath'.toJS).toDart) {
        final path = gingaApp
            .getProperty<JSAny?>('appPath'.toJS)
            ?.dartify()
            ?.toString();
        if (path != null && path.isNotEmpty) return path;
      }
    }
  } catch (_) {}
  try {
    final uri = Uri.parse(web.window.location.href);
    final queryApp = uri.queryParameters['app'];
    if (queryApp != null && queryApp.isNotEmpty) {
      return queryApp;
    }
  } catch (_) {}
  return getSessionStorageItem('GINGA_PLAYGROUND_MAIN');
}

Map<String, dynamic>? getGingaAppFiles() {
  try {
    if (web.window.hasProperty('GingaApp'.toJS).toDart) {
      final gingaApp = web.window.getProperty<JSObject?>('GingaApp'.toJS);
      if (gingaApp != null && gingaApp.hasProperty('files'.toJS).toDart) {
        final filesObj = gingaApp.getProperty<JSObject?>('files'.toJS);
        if (filesObj != null) {
          final dartified = filesObj.dartify();
          if (dartified is Map) {
            return Map<String, dynamic>.from(dartified);
          }
        }
      }
    }
  } catch (_) {}

  try {
    final mockJson = getSessionStorageItem('GINGA_PLAYGROUND_FILES');
    if (mockJson != null) {
      return jsonDecode(mockJson) as Map<String, dynamic>;
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
