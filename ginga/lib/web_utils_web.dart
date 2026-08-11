import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

import 'package:flutter/foundation.dart' show debugPrint;

String? getSessionStorageItem(String key) {
  try {
    final localVal = html.window.sessionStorage[key];
    if (localVal != null && localVal.isNotEmpty) return localVal;
  } catch (_) {}
  try {
    if (html.window.parent != null && html.window.parent != html.window) {
      final parentWin = html.window.parent as html.Window;
      final parentVal = parentWin.sessionStorage[key];
      if (parentVal != null && parentVal.isNotEmpty) return parentVal;
    }
  } catch (_) {}
  return null;
}

String? getGingaAppPath() {
  try {
    if (js.context.hasProperty('GingaApp')) {
      final gingaApp = js.context['GingaApp'];
      if (gingaApp != null && gingaApp['appPath'] != null) {
        final path = gingaApp['appPath'].toString();
        if (path.isNotEmpty) return path;
      }
    }
  } catch (_) {}
  try {
    final uri = Uri.parse(html.window.location.href);
    final queryApp = uri.queryParameters['app'];
    if (queryApp != null && queryApp.isNotEmpty) {
      return queryApp;
    }
  } catch (_) {}
  return getSessionStorageItem('GINGA_PLAYGROUND_MAIN');
}

Map<String, dynamic>? getGingaAppFiles() {
  try {
    if (js.context.hasProperty('GingaApp')) {
      final gingaApp = js.context['GingaApp'];
      if (gingaApp != null && gingaApp['files'] != null) {
        final filesObj = gingaApp['files'];
        final jsKeys = js.context['Object'].callMethod('keys', [filesObj]) as List;
        final map = <String, dynamic>{};
        for (final k in jsKeys) {
          map[k.toString()] = filesObj[k];
        }
        if (map.isNotEmpty) return map;
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
    html.window.parent?.postMessage('ginga_app_exited', '*');
  } catch (e) {
    debugPrint('Failed to notify parent app exited: $e');
  }
}
