import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;

import 'ccws.dart';
import 'ginga_app_context.dart';
import 'ginga_config.dart';
import 'remote_device_client.dart';

export 'ccws.dart';
export 'ginga_app.dart';
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

class GingaCC {
  GingaConfig config;
  late final CCWS ccws = CCWS(gingacc: this);
  final Map<String, GingaAppContext> _appContexts = {};
  final Map<String, Map<String, dynamic>> _remoteDevices = {};
  final Map<String, RemoteDeviceChannel> _remoteChannels = {};
  final StreamController<void> _remoteDevicesChangedController =
      StreamController<void>.broadcast();
  final List<Map<String, dynamic>> _forwardedMessages = [];
  int _nextRemoteDeviceIndex = 1;

  Stream<void> get onRemoteDevicesChanged =>
      _remoteDevicesChangedController.stream;

  Map<String, Map<String, dynamic>> get remoteDevices =>
      Map.unmodifiable(_remoteDevices);

  List<RemoteDeviceChannel> get allRemoteDeviceChannels =>
      List.unmodifiable(_remoteChannels.values);

  List<Map<String, dynamic>> get forwardedMessages =>
      List.unmodifiable(_forwardedMessages);

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
