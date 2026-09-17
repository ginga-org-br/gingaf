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
  String injectCcwsFetch(String content) => content;

  CCWS({int port = ccwsDefaultPort}) : _port = port;

  Handler get handler =>
      Pipeline().addMiddleware(logRequests(logger: (message, isError) {
        if (isError) {
          _logger.severe(message);
        } else {
          _logger.info(message);
        }
      })).addHandler(CCWSRouter.getHandler());

  Future<void> start() async {
    try {
      _server =
          await io.serve(handler, InternetAddress.loopbackIPv4, _port);
      _logger.info(
          'Server running on http://${_server!.address.address}:${_server!.port}');
      _running = true;
      return;
    } catch (e) {
      if (e is SocketException) {
        try {
          _server = await io.serve(handler, InternetAddress.loopbackIPv4, 0);
          _logger.info(
              'Server running on dynamic port http://${_server!.address.address}:${_server!.port}');
          _running = true;
          return;
        } catch (e2) {
          _logger.severe('Server failed to start on dynamic port: $e2');
        }
      }
      _logger.severe('Server failed to start on port $_port: $e');
    }
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _running = false;
    _logger.info('Server stopped');
  }
}
