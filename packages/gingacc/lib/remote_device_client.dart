import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'gingacc.dart';

final _logger = Logger('remote-device-client');

class RemoteDeviceChannel {
  final String deviceClass;
  final String deviceId;
  final int wsPort;
  final String wsUrl;
  final List<String> supportedTypes;
  final String screenSize;
  final String screenGraphicSize;
  final List<Map<String, dynamic>> _pendingHostMessages = [];
  bool _hasHostListener = false;
  late final StreamController<Map<String, dynamic>> _hostToDeviceController =
      StreamController<Map<String, dynamic>>.broadcast(
    onListen: () {
      _hasHostListener = true;
      if (_pendingHostMessages.isNotEmpty) {
        final queued = List<Map<String, dynamic>>.from(_pendingHostMessages);
        _pendingHostMessages.clear();
        for (final msg in queued) {
          if (!_isClosed) {
            _hostToDeviceController.add(msg);
          }
        }
      }
    },
    onCancel: () {
      _hasHostListener = _hostToDeviceController.hasListener;
    },
  );
  final StreamController<Map<String, dynamic>> _deviceToHostController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<void> _closeController =
      StreamController<void>.broadcast();
  bool _isClosed = false;

  RemoteDeviceChannel({
    required this.deviceClass,
    required this.deviceId,
    required this.wsPort,
    required this.wsUrl,
    this.supportedTypes = const [],
    this.screenSize = '1280, 720',
    this.screenGraphicSize = '1280, 720',
  });

  bool get isClosed => _isClosed;

  Stream<Map<String, dynamic>> get onHostMessage =>
      _hostToDeviceController.stream;

  Stream<Map<String, dynamic>> get onDeviceMessage =>
      _deviceToHostController.stream;

  Stream<void> get onClose => _closeController.stream;

  bool supportsType(String? mimeType) {
    if (supportedTypes.isEmpty || mimeType == null || mimeType.isEmpty) {
      return true;
    }
    return supportedTypes.contains(mimeType);
  }

  void sendToDevice(Map<String, dynamic> message) {
    if (_isClosed) return;
    if (_hasHostListener && _hostToDeviceController.hasListener) {
      _hostToDeviceController.add(message);
    } else {
      _pendingHostMessages.add(message);
    }
  }

  void sendToHost(Map<String, dynamic> message) {
    if (!_isClosed) {
      _deviceToHostController.add(message);
    }
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    _closeController.add(null);
    await _closeController.close();
    await _hostToDeviceController.close();
    await _deviceToHostController.close();
  }
}

enum RemoteDeviceState {
  idle,
  discovering,
  registering,
  connecting,
  running,
  deregistering,
  halted,
  failed,
}

class RemoteDeviceClient {
  final GingaCC gingacc;
  final String deviceClass;
  final List<String> supportedTypes;
  final String screenSize;
  final String screenGraphicSize;
  final bool useSsdpDiscovery;
  final int ssdpPort;
  final Duration ssdpTimeout;
  final bool useRealWebSocket;
  final String baseUrl;
  final http.Client? _httpClient;
  final http.Client _client;
  String? _accessToken;
  String? _refreshToken;
  int _nextDynamicPort = 45000;

  RemoteDeviceState _state = RemoteDeviceState.idle;
  SsdpDiscoveredReceiver? _discoveredReceiver;
  String? _resolvedBaseUrl;
  String? _handle;
  String? _wsUrl;
  RemoteDeviceChannel? _channel;
  WebSocket? _webSocket;
  StreamSubscription<Map<String, dynamic>>? _channelSub;
  StreamSubscription<dynamic>? _wsSub;

  final StreamController<Map<String, dynamic>> _nodeMetadataController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _actionMetadataController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<RemoteDeviceState> _stateController =
      StreamController<RemoteDeviceState>.broadcast();

  RemoteDeviceClient({
    GingaCC? gingacc,
    this.deviceClass = 'ncl-360-vr',
    this.supportedTypes = const [
      'application/x-ncl360',
      'text/html',
      'application/x-ginga-NCL',
      'application/x-vlibras-gloss',
      'application/ttml+xml',
      'text/srt',
      'video/mp4',
      'audio/mpeg',
      'text/plain',
    ],
    this.screenSize = '1280, 720',
    this.screenGraphicSize = '1280, 720',
    this.useSsdpDiscovery = false,
    this.ssdpPort = ssdpDefaultPort,
    this.ssdpTimeout = const Duration(seconds: 2),
    this.useRealWebSocket = false,
    String? baseUrl,
    http.Client? client,
    http.Client? httpClient,
    String? accessToken,
  })  : gingacc = gingacc ?? GingaCC(),
        baseUrl = (baseUrl ?? 'http://127.0.0.1:44642')
            .replaceAll(RegExp(r'/+$'), ''),
        _httpClient = httpClient ?? client,
        _client = client ?? httpClient ?? http.Client(),
        _accessToken = accessToken;

  RemoteDeviceState get state => _state;
  SsdpDiscoveredReceiver? get discoveredReceiver => _discoveredReceiver;
  String? get handle => _handle;
  String? get wsUrl => _wsUrl;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Stream<Map<String, dynamic>> get onNodeMetadata =>
      _nodeMetadataController.stream;
  Stream<Map<String, dynamic>> get onActionMetadata =>
      _actionMetadataController.stream;
  Stream<RemoteDeviceState> get onStateChanged => _stateController.stream;

  Map<String, String> _buildHeaders() {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (_accessToken != null && _accessToken!.isNotEmpty)
        'Authorization': 'Bearer $_accessToken',
    };
  }

  void _setState(RemoteDeviceState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  void _dispatchIncoming(Map<String, dynamic> msg) {
    if (msg.containsKey('type') && !msg.containsKey('eventType')) {
      if (!_nodeMetadataController.isClosed) {
        _nodeMetadataController.add(msg);
      }
    } else if (msg.containsKey('eventType')) {
      if (!_actionMetadataController.isClosed) {
        _actionMetadataController.add(msg);
      }
    }
  }

  Future<bool> register() async {
    if (_state == RemoteDeviceState.running && _handle != null) return true;

    try {
      if (useSsdpDiscovery) {
        _setState(RemoteDeviceState.discovering);
        final receivers = await SsdpClient.discover(
          port: ssdpPort,
          timeout: ssdpTimeout,
          httpClient: _httpClient,
        );
        if (receivers.isEmpty) {
          _logger.warning(
            'No TV 3.0 Web Services receiver discovered via SSDP on port $ssdpPort',
          );
          _setState(RemoteDeviceState.failed);
          return false;
        }
        _discoveredReceiver = receivers.first;
        _resolvedBaseUrl = _discoveredReceiver!.httpBaseUrl;
      }

      _setState(RemoteDeviceState.registering);

      final reqPayload = jsonEncode({
        'deviceClass': deviceClass,
        'supportedTypes': supportedTypes,
        'screenSize': screenSize,
        'screenGraphicSize': screenGraphicSize,
      });

      int statusCode;
      String resBody;

      if (_resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty) {
        final client = _httpClient ?? http.Client();
        final base = _resolvedBaseUrl!.replaceAll(RegExp(r'/+$'), '');
        final res = await client.post(
          Uri.parse('$base/tv3/remote-device'),
          headers: {'Content-Type': 'application/json'},
          body: reqPayload,
        );
        statusCode = res.statusCode;
        resBody = res.body;
        if (_httpClient == null) {
          client.close();
        }
      } else {
        final res = await gingacc.dispatchLocalCcwsRequest(
          method: 'POST',
          path: '/tv3/remote-device',
          headers: {'content-type': 'application/json'},
          body: reqPayload,
        );
        statusCode = res.statusCode;
        resBody = res.body;
      }

      if (statusCode != 200 && statusCode != 201) {
        _setState(RemoteDeviceState.failed);
        return false;
      }

      final decoded = jsonDecode(resBody);
      if (decoded is! Map || decoded['handle'] == null) {
        _setState(RemoteDeviceState.failed);
        return false;
      }

      _handle = decoded['handle'].toString();
      _wsUrl = decoded['url']?.toString();
      _setState(RemoteDeviceState.connecting);

      if ((_resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty) ||
          useRealWebSocket) {
        if (_wsUrl == null || _wsUrl!.isEmpty) {
          await deregister();
          return false;
        }
        _webSocket = await WebSocket.connect(_wsUrl!);
        _wsSub = _webSocket!.listen(
          (dynamic raw) {
            try {
              final data = raw is String ? jsonDecode(raw) : raw;
              if (data is Map) {
                _dispatchIncoming(Map<String, dynamic>.from(data));
              }
            } catch (_) {}
          },
          onDone: () {
            if (_state == RemoteDeviceState.running) {
              _setState(RemoteDeviceState.halted);
            }
          },
        );
      } else {
        _channel = gingacc.getRemoteDeviceChannel(_handle!);
        if (_channel == null) {
          await deregister();
          return false;
        }
        _channelSub = _channel!.onHostMessage.listen(_dispatchIncoming);
      }

      _setState(RemoteDeviceState.running);
      return true;
    } catch (e) {
      _logger.warning('Failed to register remote device client ($deviceClass): $e');
      _setState(RemoteDeviceState.failed);
      return false;
    }
  }

  void sendTransitionMetadata({
    required String nodeId,
    required String appId,
    required String eventType,
    required String transition,
    String? label,
    String? value,
    String? user,
  }) {
    if (_state != RemoteDeviceState.running) return;
    final msg = <String, dynamic>{
      'nodeId': nodeId,
      if (label != null && label.isNotEmpty) 'label': label,
      'appId': appId,
      'eventType': eventType,
      'transition': transition,
      if (value != null) 'value': value,
      if (user != null) 'user': user,
    };
    if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
      _webSocket!.add(jsonEncode(msg));
    } else if (_channel != null && !_channel!.isClosed) {
      _channel!.sendToHost(msg);
    }
  }

  Future<void> deregister() async {
    final activeHandle = _handle;
    if (activeHandle == null) {
      _setState(RemoteDeviceState.halted);
      return;
    }
    _setState(RemoteDeviceState.deregistering);
    _handle = null;

    final channelSub = _channelSub;
    _channelSub = null;
    final wsSub = _wsSub;
    _wsSub = null;
    final ws = _webSocket;
    _webSocket = null;
    _channel = null;

    try {
      if (_resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty) {
        final client = _httpClient ?? http.Client();
        final base = _resolvedBaseUrl!.replaceAll(RegExp(r'/+$'), '');
        await client.delete(Uri.parse('$base/tv3/remote-device/$activeHandle'));
        if (_httpClient == null) {
          client.close();
        }
      } else {
        await gingacc.dispatchLocalCcwsRequest(
          method: 'DELETE',
          path: '/tv3/remote-device/$activeHandle',
        );
      }
    } catch (_) {}

    await channelSub?.cancel();
    await wsSub?.cancel();
    if (ws != null) {
      await ws.close();
    }

    _setState(RemoteDeviceState.halted);
  }

  Future<void> dispose() async {
    await deregister();
    await _nodeMetadataController.close();
    await _actionMetadataController.close();
    await _stateController.close();
  }

  Future<bool> pairWithPin(
    String pin, {
    String appId = 'gingaf-companion',
  }) async {
    try {
      final reqUri = Uri.parse('$baseUrl/dtv/pairing/request');
      final reqRes = await _client.post(
        reqUri,
        headers: _buildHeaders(),
        body: jsonEncode({'appId': appId}),
      );
      String challengeId = 'default-challenge';
      if (reqRes.statusCode == 200 || reqRes.statusCode == 201) {
        try {
          final reqBody = jsonDecode(reqRes.body);
          if (reqBody is Map && reqBody['challengeId'] != null) {
            challengeId = reqBody['challengeId'].toString();
          }
        } catch (_) {}
      }

      final checkUri = Uri.parse('$baseUrl/dtv/pairing/check');
      final checkRes = await _client.post(
        checkUri,
        headers: _buildHeaders(),
        body: jsonEncode({
          'appId': appId,
          'challengeId': challengeId,
          'pin': pin,
        }),
      );
      if (checkRes.statusCode == 200) {
        final decoded = jsonDecode(checkRes.body);
        if (decoded is Map) {
          _accessToken = (decoded['access_token'] ?? decoded['accessToken'])
              ?.toString();
          _refreshToken = (decoded['refresh_token'] ?? decoded['refreshToken'])
              ?.toString();
          return _accessToken != null && _accessToken!.isNotEmpty;
        }
      }
    } catch (e) {
      _logger.warning('Failed to pair using PIN: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>?> getCurrentService() async {
    try {
      final uri = Uri.parse('$baseUrl/tv3/current-service');
      final res = await _client.get(uri, headers: _buildHeaders());
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e) {
      _logger.warning('Failed to fetch current service: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getServiceList() async {
    try {
      final uri = Uri.parse('$baseUrl/tv3/service-list');
      final res = await _client.get(uri, headers: _buildHeaders());
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded is Map && decoded['services'] is List
                ? decoded['services'] as List
                : const []);
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      _logger.warning('Failed to fetch service list: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getApps() async {
    try {
      final uri = Uri.parse('$baseUrl/dtv/apps');
      final res = await _client.get(uri, headers: _buildHeaders());
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded is Map && decoded['apps'] is List
                ? decoded['apps'] as List
                : const []);
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      _logger.warning('Failed to fetch apps: $e');
    }
    return [];
  }

  Future<bool> launchApp(String appId) async {
    try {
      final uri = Uri.parse('$baseUrl/dtv/apps/$appId/launch');
      final res = await _client.post(uri, headers: _buildHeaders());
      return res.statusCode == 200 || res.statusCode == 202;
    } catch (e) {
      _logger.warning('Failed to launch app $appId: $e');
      return false;
    }
  }

  Future<bool> sendKeys(List<String> keys) async {
    try {
      final uri = Uri.parse('$baseUrl/dtv/remote/keys');
      final res = await _client.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode({'keys': keys}),
      );
      return res.statusCode == 200 || res.statusCode == 202;
    } catch (e) {
      _logger.warning('Failed to send remote keys: $e');
      return false;
    }
  }

  Future<RemoteDeviceChannel> openRemoteDeviceChannel({
    required String deviceClass,
    String? deviceId,
    List<String> supportedTypes = const ['application/x-ncl360'],
    String screenSize = '1280, 720',
    String screenGraphicSize = '1280, 720',
  }) async {
    String effectiveId = deviceId ?? '$deviceClass-${_nextDynamicPort - 44999}';
    int allocatedPort = _nextDynamicPort;
    if (_nextDynamicPort < 45199) {
      _nextDynamicPort++;
    }
    String wsUrl = 'ws://localhost:$allocatedPort';

    try {
      final uri = Uri.parse('$baseUrl/tv3/remote-device');
      final res = await _client.post(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode({
          'deviceClass': deviceClass,
          'supportedTypes': supportedTypes,
          'screenSize': screenSize,
          'screenGraphicSize': screenGraphicSize,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          if (decoded['handle'] is String) {
            effectiveId = decoded['handle'] as String;
          }
          if (decoded['url'] is String) {
            wsUrl = decoded['url'] as String;
            final parsedWs = Uri.tryParse(wsUrl);
            if (parsedWs != null && parsedWs.hasPort) {
              allocatedPort = parsedWs.port;
            }
          } else if (decoded['port'] is int) {
            allocatedPort = decoded['port'] as int;
            wsUrl = 'ws://localhost:$allocatedPort';
          }
        }
      }
    } catch (_) {}

    return RemoteDeviceChannel(
      deviceClass: deviceClass,
      deviceId: effectiveId,
      wsPort: allocatedPort,
      wsUrl: wsUrl,
      supportedTypes: List<String>.from(supportedTypes),
      screenSize: screenSize,
      screenGraphicSize: screenGraphicSize,
    );
  }

  Future<bool> unregisterRemoteDevice(String handle) async {
    try {
      final uri = Uri.parse('$baseUrl/tv3/remote-device/$handle');
      final res = await _client.delete(uri, headers: _buildHeaders());
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      _logger.warning('Failed to unregister remote device $handle: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getRemoteDevicesByClass(
    String classId, {
    String apiVersion = '2.0',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/tv3/remote-device/devices/$classId');
      final headers = {
        ..._buildHeaders(),
        'Accept-Version': apiVersion,
      };
      final res = await _client.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['devices'] is List) {
          return (decoded['devices'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      _logger.warning('Failed to get remote devices for class $classId: $e');
    }
    return [];
  }

  Future<UserData?> fetchCurrentUser([
    String serviceContextId = 'current-service',
  ]) async {
    try {
      final uri =
          Uri.parse('$baseUrl/tv3/$serviceContextId/users/current-user');
      final res = await _client.get(uri, headers: _buildHeaders());
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final userId = map['userId']?.toString() ??
              map['id']?.toString() ??
              map['user_id']?.toString() ??
              '';
          final name =
              map['name']?.toString() ?? map['nickname']?.toString() ?? userId;
          final attributes = map['attributes'];
          final props = <String, dynamic>{};
          if (attributes is Map) {
            props.addAll(Map<String, dynamic>.from(attributes));
          }
          map.forEach((key, val) {
            if (key != 'userId' &&
                key != 'id' &&
                key != 'user_id' &&
                key != 'name' &&
                key != 'nickname' &&
                key != 'attributes') {
              props[key] = val;
            }
          });
          return UserData(id: userId, name: name, initialProperties: props);
        }
      }
    } catch (e) {
      _logger.warning('Failed to fetch TV3.0 current user: $e');
    }
    return null;
  }

  Future<List<String>> fetchUserList([
    String serviceContextId = 'current-service',
  ]) async {
    try {
      final uri = Uri.parse('$baseUrl/tv3/$serviceContextId/users/');
      final res = await _client.post(uri, headers: _buildHeaders());
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        } else if (decoded is Map && decoded['users'] is List) {
          return (decoded['users'] as List).map((e) => e.toString()).toList();
        }
      }
    } catch (e) {
      _logger.warning('Failed to fetch TV3.0 user list: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> fetchUserAttributes(
    String userId, [
    String serviceContextId = 'current-service',
  ]) async {
    try {
      final uri = Uri.parse('$baseUrl/tv3/$serviceContextId/users/$userId');
      final res = await _client.get(uri, headers: _buildHeaders());
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e) {
      _logger.warning('Failed to fetch TV3.0 user attributes for $userId: $e');
    }
    return null;
  }

  Future<bool> syncWithGingaCC(
    GingaCC gingacc, [
    String serviceContextId = 'current-service',
  ]) async {
    final user = await fetchCurrentUser(serviceContextId);
    if (user != null && user.id.isNotEmpty) {
      gingacc.config.users.registerUser(user);
      gingacc.switchCurrentUser(user.id);
      return true;
    }
    return false;
  }

  Future<Map<String, String>?> fetchManifest() async {
    try {
      final uri = Uri.parse('$baseUrl/manifest');
      final res = await _client.get(uri);
      if (res.statusCode == 200) {
        return res.headers;
      }
    } catch (e) {
      _logger.warning('Failed to fetch TV3.0 manifest: $e');
    }
    return null;
  }

  void close() {
    _client.close();
  }
}
