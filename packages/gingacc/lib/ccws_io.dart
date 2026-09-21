import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'router.dart';

const ccwsDefaultPort = 44642;

final _logger = Logger('ginga-ccws');

class CCWS {
  final int _port;
  HttpServer? _server;
  bool _running = false;
  int get port => _server?.port ?? _port;
  bool get isRunning => _running;

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Private-Network': 'true',
  };

  CCWS({int port = ccwsDefaultPort}) : _port = port;

  Handler get handler => Pipeline()
      .addMiddleware((innerHandler) {
        return (Request request) async {
          if (request.method == 'OPTIONS') {
            return Response.ok('', headers: _corsHeaders);
          }
          final response = await innerHandler(request);
          return response.change(headers: _corsHeaders);
        };
      })
      .addMiddleware(logRequests(logger: (message, isError) {
        if (isError) {
          _logger.severe(message);
        } else {
          _logger.info(message);
        }
      }))
      .addHandler(CCWSRouter.getHandler());

  Future<void> start() async {
    if (_running) return;
    int currentPort = _port;
    const maxAttempts = 10000;

    for (int i = 0; i < maxAttempts; i++) {
      try {
        _server =
            await io.serve(handler, InternetAddress.loopbackIPv4, currentPort);
        _logger.info(
            'Server running on http://${_server!.address.address}:${_server!.port}');
        _running = true;
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
      _logger.info(
          'Server running on dynamic port http://${_server!.address.address}:${_server!.port}');
      _running = true;
    } catch (e) {
      _logger.severe('Server failed to start on dynamic port: $e');
    }
  }

  Future<void> stop() async {
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
