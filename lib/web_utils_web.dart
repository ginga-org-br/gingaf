import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart' as web;

import 'arg_parsers.dart';
import 'web_utils_web_tv30_testbed.dart' deferred as tv30_testbed;

export 'arg_parsers.dart' show buildGingaBrowserUrl;

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
  for (final prop in const ['app', 'currentApp', 'appPath']) {
    if (obj.hasProperty(prop.toJS).toDart) {
      final val = obj.getProperty<JSAny?>(prop.toJS)?.dartify()?.toString();
      if (val != null && val.isNotEmpty) return val;
    }
  }
  return null;
}

Map<String, String> _fragmentParams(Uri uri) {
  if (!uri.hasFragment || !uri.fragment.contains('=')) return const {};
  try {
    return Uri.parse('http://dummy/?${uri.fragment}').queryParameters;
  } catch (_) {
    return const {};
  }
}

String? getGingaApp() {
  const appKeys = ['ginga_app', 'app', 'src', 'appSrc'];
  try {
    final uri = Uri.parse(web.window.location.href);
    final queryApp = lookupQueryParam(uri.queryParameters, appKeys) ??
        lookupQueryParam(_fragmentParams(uri), appKeys);
    if (queryApp != null) return queryApp;
  } catch (_) {}
  try {
    for (final name in const ['Ginga', 'GingaApp']) {
      if (web.window.hasProperty(name.toJS).toDart) {
        final val =
            _extractAppFromObject(web.window.getProperty<JSObject?>(name.toJS));
        if (val != null && val.isNotEmpty) return val;
      }
    }
  } catch (_) {}
  try {
    final parent = web.window.parent;
    if (parent != null && parent != web.window) {
      for (final name in const ['Ginga', 'GingaApp']) {
        if (parent.hasProperty(name.toJS).toDart) {
          final val =
              _extractAppFromObject(parent.getProperty<JSObject?>(name.toJS));
          if (val != null && val.isNotEmpty) return val;
        }
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
      final val = query['playground'] ?? query['ginga_playground'];
      return parseBoolFlag(val) ?? true;
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
    return parseBoolFlag(_getSessionStorageItem('GINGA_PLAYGROUND'));
  } catch (_) {}
  return null;
}

List<String>? getGingaRemoteDevices() {
  String? raw;
  try {
    final uri = Uri.parse(web.window.location.href);
    raw = lookupQueryParam(uri.queryParameters, remoteDeviceParamKeys) ??
        lookupQueryParam(_fragmentParams(uri), remoteDeviceParamKeys);
  } catch (_) {}
  if (raw == null || raw.isEmpty) {
    try {
      raw = _getSessionStorageItem('GINGA_REMOTE_DEVICES');
    } catch (_) {}
  }
  return parseRemoteDevices(raw);
}

String? lastSyncedBrowserUrl;

void updateGingaBrowserUrl(
  String selectedFile, {
  String? resolvedAppUrl,
}) {
  try {
    final newUrl = buildGingaBrowserUrl(
      web.window.location.href,
      selectedFile,
      resolvedAppUrl: resolvedAppUrl,
    );
    lastSyncedBrowserUrl = newUrl;
    web.window.history.replaceState(null, '', newUrl);
  } catch (e) {
    debugPrint('Failed to update browser URL: $e');
  }
}

void notifyParentAppExited() {
  try {
    web.window.parent?.postMessage('ginga_app_exited'.toJS, '*'.toJS);
  } catch (e) {
    debugPrint('Failed to notify parent app exited: $e');
  }
}

bool isTv30Testbed() {
  try {
    final query = Uri.parse(web.window.location.href).queryParameters;
    if (parseBoolFlag(query['tv30']) == true ||
        parseBoolFlag(query['overlay']) == true ||
        parseBoolFlag(query['transparent']) == true) {
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
  if (!isTv30Testbed()) return null;
  await tv30_testbed.loadLibrary();
  return tv30_testbed.subscribeTv30Testbed(
    onKey: onKey,
    onTime: onTime,
    onStreamEvent: onStreamEvent,
  );
}
