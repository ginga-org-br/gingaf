import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;

import 'ccws.dart';

export 'ccws.dart';
export 'ginga_app_context.dart';
export 'ginga_config.dart';
export 'gingacc_plugins.dart';
export 'remote_device_client.dart';
export 'ssdp.dart';
export 'users.dart';

final _logger = Logger('gingacc');

const bool _isWeb = bool.fromEnvironment('dart.library.js_interop');

bool isHttpUri(Object? source) {
  if (source is Uri) {
    return source.isScheme('http') || source.isScheme('https');
  }
  if (source is String) {
    return source.startsWith('http://') || source.startsWith('https://');
  }
  return false;
}

bool isXmlString(String? src) {
  if (src == null) return false;
  return src.trim().startsWith('<');
}

enum GingaCCMode {
  primary,
  mirror,
}

class GingaCC {
  final GingaCCMode mode;
  final String primaryCcwsUrl;
  GingaConfig config;
  late final CCWS ccws = CCWS(gingacc: this);
  final Map<String, GingaAppContext> _appContexts = {};
  final Map<String, Map<String, dynamic>> _appSnapshots = {};
  String? _activeAppContextId;
  final Map<String, Map<String, dynamic>> _remoteDevices = {};
  final Map<String, RemoteDeviceChannel> _remoteChannels = {};
  final StreamController<void> _remoteDevicesChangedController =
      StreamController<void>.broadcast();
  final List<Map<String, dynamic>> _forwardedMessages = [];
  int _nextRemoteDeviceIndex = 1;

  Users get users => config.users;

  Map<String, String> get systemVariables => config.systemVariables;

  Stream<({String name, String value, String? userId})> get onVariableChanged =>
      config.onVariableChanged;

  Stream<void> get onRemoteDevicesChanged =>
      _remoteDevicesChangedController.stream;

  Map<String, Map<String, dynamic>> get remoteDevices =>
      Map.unmodifiable(_remoteDevices);

  List<RemoteDeviceChannel> get allRemoteDeviceChannels =>
      List.unmodifiable(_remoteChannels.values);

  List<Map<String, dynamic>> get forwardedMessages =>
      List.unmodifiable(_forwardedMessages);

  Map<String, Map<String, dynamic>> get appSnapshots =>
      Map.unmodifiable(_appSnapshots);

  String? get activeAppContextId => _activeAppContextId;

  Map<String, dynamic>? get activeAppSnapshot =>
      _activeAppContextId != null ? _appSnapshots[_activeAppContextId] : null;

  void saveAppContextSnapshot(
    String appContextId,
    Map<String, dynamic> snapshot,
  ) {
    _activeAppContextId = appContextId;
    _appSnapshots[appContextId] = Map<String, dynamic>.from(snapshot);
    if (mode == GingaCCMode.mirror) {
      unawaited(pushPrimaryAppContextSnapshot(appContextId));
    }
  }

  Map<String, dynamic>? getAppContextSnapshot([String? appContextId]) {
    final targetId = appContextId ?? _activeAppContextId;
    if (targetId == null) return null;
    final snap = _appSnapshots[targetId];
    return snap != null ? Map<String, dynamic>.from(snap) : null;
  }

  void clearAppContextSnapshots([String? appContextId]) {
    if (appContextId != null) {
      _appSnapshots.remove(appContextId);
      if (_activeAppContextId == appContextId) {
        _activeAppContextId =
            _appSnapshots.keys.isNotEmpty ? _appSnapshots.keys.last : null;
      }
    } else {
      _appSnapshots.clear();
      _activeAppContextId = null;
    }
  }

  Map<String, dynamic> toSnapshotJson() {
    return {
      'currentUserId': users.currentUserId,
      'users': users.allUsers
          .map(
            (u) => {
              'id': u.id,
              'name': u.name,
              'properties': u.properties,
            },
          )
          .toList(),
      'systemVariables': Map<String, String>.from(config.systemVariables),
      'remoteDevices': _remoteDevices.values
          .map((d) => Map<String, dynamic>.from(d))
          .toList(),
      'activeAppContextId': _activeAppContextId,
      'appSnapshots': _appSnapshots.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v)),
      ),
    };
  }

  void restoreFromSnapshotJson(Map<String, dynamic> json) {
    final rawUsers = json['users'];
    if (rawUsers is List) {
      users.clear();
      users.importUsers(rawUsers);
    }
    final currentUserId = json['currentUserId']?.toString();
    if (currentUserId != null && currentUserId.isNotEmpty) {
      users.setCurrentUser(currentUserId);
    }
    final rawVars = json['systemVariables'];
    if (rawVars is Map) {
      for (final entry in rawVars.entries) {
        config.setVariable(entry.key.toString(), entry.value.toString());
      }
    }
    final rawDevices = json['remoteDevices'];
    if (rawDevices is List) {
      for (final item in rawDevices.whereType<Map>()) {
        final handle = item['handle']?.toString();
        final deviceClass = item['deviceClass']?.toString() ?? '';
        if (deviceClass.isEmpty) continue;
        if (handle != null && _remoteDevices.containsKey(handle)) continue;
        final supportedTypes = (item['supportedTypes'] is List)
            ? (item['supportedTypes'] as List)
                .map((e) => e.toString())
                .toList()
            : <String>['text/html'];
        registerRemoteDevice(
          deviceClass: deviceClass,
          supportedTypes: supportedTypes,
          screenSize: item['screenSize']?.toString() ?? '1280, 720',
          screenGraphicSize:
              item['screenGraphicSize']?.toString() ?? '1280, 720',
        );
      }
    }
    final rawSnaps = json['appSnapshots'];
    if (rawSnaps is Map) {
      _appSnapshots.clear();
      for (final entry in rawSnaps.entries) {
        if (entry.value is Map) {
          _appSnapshots[entry.key.toString()] =
              Map<String, dynamic>.from(entry.value as Map);
        }
      }
    }
    final activeId = json['activeAppContextId']?.toString();
    if (activeId != null && activeId.isNotEmpty) {
      _activeAppContextId = activeId;
    }
  }

  Future<bool> pullPrimaryState([String? baseUrl]) async {
    final base = (baseUrl ?? primaryCcwsUrl).replaceAll(RegExp(r'/+$'), '');
    try {
      final response = await http.get(Uri.parse('$base/tv3/gingacc'));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          restoreFromSnapshotJson(Map<String, dynamic>.from(decoded));
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<bool> pushPrimaryState([String? baseUrl]) async {
    final base = (baseUrl ?? primaryCcwsUrl).replaceAll(RegExp(r'/+$'), '');
    try {
      final response = await http.put(
        Uri.parse('$base/tv3/gingacc'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode(toSnapshotJson()),
      );
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  Future<bool> pushPrimaryAppContextSnapshot(
    String appContextId, [
    String? baseUrl,
  ]) async {
    final snap = _appSnapshots[appContextId];
    if (snap == null) return false;
    final base = (baseUrl ?? primaryCcwsUrl).replaceAll(RegExp(r'/+$'), '');
    try {
      final response = await http.put(
        Uri.parse(
          '$base/tv3/gingacc/app-context/${Uri.encodeComponent(appContextId)}',
        ),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode(snap),
      );
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  Map<String, dynamic> registerRemoteDevice({
    required String deviceClass,
    required List<String> supportedTypes,
    String screenSize = '1280, 720',
    String screenGraphicSize = '1280, 720',
  }) {
    final portIdx = _nextRemoteDeviceIndex++;
    var classIdx = 1;
    while (_remoteDevices.containsKey('rd-$deviceClass-$classIdx')) {
      classIdx++;
    }
    final handle = 'rd-$deviceClass-$classIdx';
    final wsPort = 45000 + ((portIdx - 1) % 200);
    final wsUrl = 'ws://localhost:$wsPort';
    final channel = RemoteDeviceChannel(
      deviceClass: deviceClass,
      deviceId: handle,
      wsPort: wsPort,
      wsUrl: wsUrl,
      supportedTypes: List<String>.from(supportedTypes),
      screenSize: screenSize,
      screenGraphicSize: screenGraphicSize,
    );
    final device = {
      'handle': handle,
      'deviceClass': deviceClass,
      'supportedTypes': List<String>.from(supportedTypes),
      'url': wsUrl,
      'wsPort': wsPort,
      'screenSize': screenSize,
      'screenGraphicSize': screenGraphicSize,
    };
    _remoteDevices[handle] = device;
    _remoteChannels[handle] = channel;
    channel.onClose.listen((_) {
      if (_remoteDevices.remove(handle) != null) {
        _remoteChannels.remove(handle);
        if (!_remoteDevicesChangedController.isClosed) {
          _remoteDevicesChangedController.add(null);
        }
      }
    });
    if (!_remoteDevicesChangedController.isClosed) {
      _remoteDevicesChangedController.add(null);
    }
    return device;
  }

  RemoteDeviceChannel? getRemoteDeviceChannel(String handle) =>
      _remoteChannels[handle];

  List<RemoteDeviceChannel> getRemoteDeviceChannelsByClass(String classId) {
    return _remoteChannels.values
        .where((c) => !c.isClosed && c.deviceClass == classId)
        .toList();
  }

  bool unregisterRemoteDevice(String handle) {
    final removedDevice = _remoteDevices.remove(handle);
    final channel = _remoteChannels.remove(handle);
    if (channel != null && !channel.isClosed) {
      unawaited(channel.close());
    }
    if (removedDevice != null && !_remoteDevicesChangedController.isClosed) {
      _remoteDevicesChangedController.add(null);
    }
    return removedDevice != null;
  }

  List<Map<String, dynamic>> getRemoteDevicesByClass(String classId) {
    return _remoteDevices.values
        .where((d) => d['deviceClass'] == classId)
        .map(
          (d) => {
            'handle': d['handle'],
            'supportedTypes': d['supportedTypes'],
            'url': d['url'],
          },
        )
        .toList();
  }

  void recordForwardedMessage(Map<String, dynamic> payload) {
    _forwardedMessages.add(payload);
  }

  Future<({int statusCode, Map<String, String> headers, String body})>
      dispatchLocalCcwsRequest({
    required String method,
    required String path,
    Map<String, String>? headers,
    String? body,
  }) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('http://localhost:${ccws.port}$normalizedPath');
    final request = shelf.Request(
      method.toUpperCase(),
      uri,
      headers: headers,
      body: body,
    );
    final response = await ccws.handler(request);
    final responseBody = await response.readAsString();
    return (
      statusCode: response.statusCode,
      headers: Map<String, String>.from(response.headers),
      body: responseBody,
    );
  }

  void clearRemoteDevices() {
    final channels = List<RemoteDeviceChannel>.from(_remoteChannels.values);
    _remoteDevices.clear();
    _remoteChannels.clear();
    _forwardedMessages.clear();
    _nextRemoteDeviceIndex = 1;
    for (final ch in channels) {
      if (!ch.isClosed) {
        unawaited(ch.close());
      }
    }
    if (!_remoteDevicesChangedController.isClosed) {
      _remoteDevicesChangedController.add(null);
    }
  }

  void setSystemVariable(String name, String value, {String? userId}) {
    config.setVariable(name, value, userId: userId);
    if (mode == GingaCCMode.mirror) {
      unawaited(pushPrimaryState());
    }
  }

  void switchCurrentUser(String userId) {
    final user = config.users.getUser(userId);
    if (user == null) return;
    final changes = config.users.diffNewCurrentUser(user);
    config.users.setCurrentUser(userId);
    config.setVariable('currentUser', user.id, userId: 'currentUser');
    config.setVariable('system.user', user.id, userId: 'currentUser');
    config.setVariable('user.id', user.id, userId: 'currentUser');
    config.setVariable('user.name', user.name, userId: 'currentUser');
    for (final entry in user.properties.entries) {
      final valStr = entry.value.toString();
      config.setVariable('user.${entry.key}', valStr, userId: 'currentUser');
      config.setVariable(entry.key, valStr, userId: 'currentUser');
    }
    for (final entry in changes.entries) {
      config.setVariable(entry.key, entry.value, userId: 'currentUser');
    }
    if (mode == GingaCCMode.mirror) {
      unawaited(pushPrimaryState());
    }
  }

  Uri resolveUri(String src, [String? baseDirSrc]) => resolvePathUri(
        src,
        baseDirSrc: baseDirSrc,
      );

  Future<String?> loadContent(dynamic srcOrUri, [String? baseDirSrc]) =>
      loadPathContent(
        srcOrUri,
        baseDirSrc: baseDirSrc,
      );

  String? loadContentSync(dynamic srcOrUri, [String? baseDirSrc]) =>
      loadPathContentSync(
        srcOrUri,
        baseDirSrc: baseDirSrc,
      );

  GingaAppContext getAppContext({
    String? appContextId,
    String? applicationId,
    Uri? baseUri,
    Map<String, String>? virtualFiles,
  }) {
    final id = appContextId ?? applicationId;
    if (id == null) {
      throw ArgumentError('Either appContextId or applicationId is required');
    }
    final existing = _appContexts[id];
    if (existing != null) {
      if (baseUri != null) {
        existing.baseUri = baseUri;
      }
      if (virtualFiles != null) {
        existing.setVirtualFiles(virtualFiles);
      }
      return existing;
    }
    final ctx = GingaAppContext(
      appContextId: id,
      gingacc: this,
      baseUri: baseUri,
      virtualFiles: virtualFiles,
    );
    _appContexts[id] = ctx;
    return ctx;
  }

  List<String> get appContextIds => List.unmodifiable(_appContexts.keys);

  bool hasAppContext(String appContextId) =>
      _appContexts.containsKey(appContextId);

  GingaAppContext? findAppContext(String appContextId) =>
      _appContexts[appContextId];

  void removeAppContext(String appContextId) {
    final removed = _appContexts.remove(appContextId);
    removed?.dispose();
  }

  GingaCC({
    GingaConfig? config,
    this.mode = GingaCCMode.primary,
    this.primaryCcwsUrl = 'http://localhost:$ccwsDefaultPort',
  }) : config = config ?? GingaConfig();

  FutureOr<GingaConfig> loadConfig([dynamic configOrSrc, String? appSrc]) {
    if (configOrSrc is GingaConfig) {
      if (appSrc != null) {
        configOrSrc.appSrc = appSrc;
      }
      config = configOrSrc;
      return config;
    }
    if (configOrSrc == null && appSrc == null) {
      config = GingaConfig();
      return config;
    }
    return _resolveConfigFromAppFolder(configOrSrc, appSrc).then((cfg) {
      config = cfg;
      return cfg;
    });
  }

  Future<GingaConfig> _resolveConfigFromAppFolder([
    dynamic configOrSrc,
    String? appSrc,
  ]) async {
    String? effectiveAppSrc = appSrc;
    String? effectiveConfigSrc = configOrSrc is String ? configOrSrc : null;

    if (!_isWeb) {
      final appFile =
          (appSrc != null && !isHttpUri(appSrc)) ? File(appSrc).absolute : null;
      final isJsonConfig = effectiveConfigSrc != null &&
          (effectiveConfigSrc.trim().startsWith('{') ||
              effectiveConfigSrc.trim().startsWith('['));
      final configFile = (effectiveConfigSrc != null &&
              !isHttpUri(effectiveConfigSrc) &&
              !isJsonConfig)
          ? File(effectiveConfigSrc).absolute
          : null;

      if (appFile != null && appFile.existsSync()) {
        Directory.current = appFile.parent.path;
        effectiveAppSrc = path.basename(appFile.path);
        if (configFile != null && configFile.existsSync()) {
          effectiveConfigSrc = configFile.path;
        }
      } else if (configFile != null && configFile.existsSync()) {
        Directory.current = configFile.parent.path;
        effectiveConfigSrc = path.basename(configFile.path);
      }
    }

    GingaConfig cfg;
    if (effectiveConfigSrc != null) {
      try {
        cfg = await GingaConfig.fromJson(
          effectiveConfigSrc,
          effectiveAppSrc,
          this,
        );
      } catch (e) {
        _logger.severe('Failed to load config: $e');
        if (!_isWeb) {
          exit(1);
        }
        cfg = GingaConfig(startWithCCWS: true);
      }
    } else if (effectiveAppSrc != null) {
      try {
        final configUri = resolveUri('ginga_config.json', effectiveAppSrc);
        final hasConfig = await loadContent(configUri) != null;
        if (hasConfig) {
          cfg = await GingaConfig.fromJson(
            'ginga_config.json',
            effectiveAppSrc,
            this,
          );
        } else if (!_isWeb && File('ginga_config.json').existsSync()) {
          cfg = await GingaConfig.fromJson(
            'ginga_config.json',
            effectiveAppSrc,
            this,
          );
        } else {
          cfg = GingaConfig(startWithCCWS: true);
        }
      } catch (e) {
        _logger.warning('Failed to load config: $e');
        cfg = GingaConfig(startWithCCWS: true);
      }
    } else {
      cfg = GingaConfig(startWithCCWS: true);
    }

    final initialAppSrc = effectiveAppSrc ?? cfg.appSrc;
    String? resolvedAppSrc = initialAppSrc;
    if (!_isWeb && initialAppSrc != null && !isHttpUri(initialAppSrc)) {
      try {
        final file = File(initialAppSrc).absolute;
        if (file.existsSync()) {
          Directory.current = file.parent.path;
          resolvedAppSrc = path.basename(file.path);
        }
      } catch (e) {
        _logger.severe('Failed to set working directory: $e');
      }
    }

    if (resolvedAppSrc != null) {
      cfg.appSrc = resolvedAppSrc;
    }

    return cfg;
  }
}
