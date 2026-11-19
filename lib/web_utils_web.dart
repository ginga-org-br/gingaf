import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart' as web;

import 'web_utils_web_tv30_testbed.dart' deferred as tv30_testbed;

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
    var queryApp =
        query['ginga_app'] ?? query['app'] ?? query['src'] ?? query['appSrc'];
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

void notifyParentAppExited() {
  try {
    web.window.parent?.postMessage('ginga_app_exited'.toJS, '*'.toJS);
  } catch (e) {
    debugPrint('Failed to notify parent app exited: $e');
  }
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

Future<void Function()?> attachTv30Testbed({
  required void Function(String nclKey) onKey,
  void Function(double time)? onTime,
  void Function(String event)? onStreamEvent,
}) async {
  if (!isTv30Mode()) return null;
  await tv30_testbed.loadLibrary();
  return tv30_testbed.subscribeTv30Testbed(
    onKey: onKey,
    onTime: onTime,
    onStreamEvent: onStreamEvent,
  );
}
