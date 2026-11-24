import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'gingacc.dart';

const ccwsDefaultPort = 44642;

final _logger = Logger('ginga-ccws');

class CCWS {
  final int _port;
  final int _defaultSsdpPort;
  final bool _defaultEnableSsdp;
  final GingaCC gingacc;
  HttpServer? _server;
  SsdpServer? _ssdpServer;
  final Map<String, HttpServer> _remoteWsServers = {};
  bool _running = false;
  int get port => _server?.port ?? _port;
  int? get ssdpPort => _ssdpServer?.boundPort;
  SsdpServer? get ssdpServer => _ssdpServer;
  bool get isRunning => _running;

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Private-Network': 'true',
  };

  CCWS({
    int port = ccwsDefaultPort,
    int ssdpPort = ssdpDefaultPort,
    bool enableSsdp = true,
    GingaCC? gingacc,
  })  : _port = port,
        _defaultSsdpPort = ssdpPort,
        _defaultEnableSsdp = enableSsdp,
        gingacc = gingacc ?? GingaCC();

  Future<void> _openRemoteDeviceWsServer(Map<String, dynamic> device) async {
    if (!_running) return;
    final handle = device['handle']?.toString();
    final wsPort = device['wsPort'] as int?;
    if (handle == null || wsPort == null) return;
    final channel = gingacc.getRemoteDeviceChannel(handle);
    if (channel == null) return;

    HttpServer? wsServer;
    for (int offset = 0; offset < 200; offset++) {
      final candidatePort = 45000 + ((wsPort - 45000 + offset) % 200);
      try {
        wsServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          candidatePort,
        );
        wsServer.idleTimeout = null;
        device['wsPort'] = wsServer.port;
        device['url'] = 'ws://localhost:${wsServer.port}';
        break;
      } on SocketException {
        continue;
      }
    }
    if (wsServer == null) return;

    _remoteWsServers[handle] = wsServer;
    channel.onClose.listen((_) {
      unawaited(_closeRemoteDeviceWsServer(handle));
    });
    unawaited(
      wsServer.forEach((HttpRequest req) async {
        if (!WebSocketTransformer.isUpgradeRequest(req)) {
          req.response.statusCode = HttpStatus.upgradeRequired;
          await req.response.close();
          return;
        }
        final ws = await WebSocketTransformer.upgrade(req);
        final hostSub = channel.onHostMessage.listen((msg) {
          if (ws.readyState == WebSocket.open) {
            ws.add(jsonEncode(msg));
          }
        });
        ws.listen(
          (dynamic raw) {
            try {
              final decoded = raw is String ? jsonDecode(raw) : raw;
              if (decoded is Map) {
                channel.sendToHost(Map<String, dynamic>.from(decoded));
              }
            } catch (_) {}
          },
          onDone: () async {
            await hostSub.cancel();
            if (!channel.isClosed) {
              gingacc.unregisterRemoteDevice(handle);
            }
          },
          onError: (_) async {
            await hostSub.cancel();
          },
        );
      }),
    );
  }

  Future<void> _closeRemoteDeviceWsServer(String handle) async {
    final wsServer = _remoteWsServers.remove(handle);
    if (wsServer != null) {
      await wsServer.close(force: true);
    }
  }

  Handler get handler => Pipeline().addMiddleware((innerHandler) {
        return (Request request) async {
          if (request.method == 'OPTIONS') {
            return Response.ok('', headers: _corsHeaders);
          }
          final response = await innerHandler(request);
          return response.change(headers: _corsHeaders);
        };
      }).addMiddleware(logRequests(logger: (message, isError) {
        if (isError) {
          _logger.severe(message);
        } else {
          _logger.info(message);
        }
      })).addHandler(
        CCWSRouter.getHandler(
          gingacc: gingacc,
          onRemoteDeviceRegistered: _openRemoteDeviceWsServer,
          onRemoteDeviceUnregistered: _closeRemoteDeviceWsServer,
        ),
      );

  Future<void> _startSsdp({int? ssdpPort, bool? enableSsdp}) async {
    final shouldStart = enableSsdp ?? _defaultEnableSsdp;
    if (!shouldStart) return;
    final targetPort = ssdpPort ?? _defaultSsdpPort;
    _ssdpServer = SsdpServer(
      locationUrl: 'http://127.0.0.1:$port/manifest',
      port: targetPort,
    );
    await _ssdpServer!.start();
  }

  Future<void> start({int? ssdpPort, bool? enableSsdp}) async {
    if (_running) return;
    int currentPort = _port;
    const maxAttempts = 10000;

    for (int i = 0; i < maxAttempts; i++) {
      try {
        _server =
            await io.serve(handler, InternetAddress.loopbackIPv4, currentPort);
        _server!.idleTimeout = null;
        _logger.info(
            'Server running on http://${_server!.address.address}:${_server!.port}');
        _running = true;
        await _startSsdp(ssdpPort: ssdpPort, enableSsdp: enableSsdp);
        return;
      } catch (e) {
        if (e is SocketException) {
          currentPort++;
          if (currentPort > 65535) {
            break;
          }
          continue;
        }
        _logger.severe('Server failed to start on port $currentPort: $e');
        rethrow;
      }
    }

    try {
      _server = await io.serve(handler, InternetAddress.loopbackIPv4, 0);
      _server!.idleTimeout = null;
      _logger.info(
          'Server running on dynamic port http://${_server!.address.address}:${_server!.port}');
      _running = true;
      await _startSsdp(ssdpPort: ssdpPort, enableSsdp: enableSsdp);
    } catch (e) {
      _logger.severe('Server failed to start on dynamic port: $e');
    }
  }

  String injectCcwsFetch(String content) {
    if (port == ccwsDefaultPort) return content;
    return content.replaceAll(
      'http://localhost:$ccwsDefaultPort',
      'http://localhost:$port',
    );
  }

  Future<void> stop() async {
    if (_ssdpServer != null) {
      final ssdp = _ssdpServer!;
      _ssdpServer = null;
      await ssdp.stop();
    }
    final wsServers = List<HttpServer>.from(_remoteWsServers.values);
    _remoteWsServers.clear();
    for (final wsServer in wsServers) {
      await wsServer.close(force: true);
    }
    if (!_running) return;
    try {
      await _server?.close(force: true);
      _server = null;
      _running = false;
      _logger.info('Server stopped');
    } catch (e) {
      _logger.severe('Error stopping server: $e');
    }
  }
}
