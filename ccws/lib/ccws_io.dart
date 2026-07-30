import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'router.dart';

const CCWS_PORT = 44642;

final _logger = Logger('ginga-ccws');

class CCWS {
  HttpServer? _server;
  bool _running = false;
  int get port => _server?.port ?? 0;
  bool get isRunning => _running;
  String injectCcwsFetch(String content) => content;

  Handler get handler =>
      Pipeline().addMiddleware(logRequests(logger: (message, isError) {
        if (isError) {
          _logger.severe(message);
        } else {
          _logger.info(message);
        }
      })).addHandler(CCWSRouter.getHandler());

  Future<void> start() async {
    int currentPort = CCWS_PORT;
    const maxRetry = 100;

    for (int i = 0; i < maxRetry; i++) {
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
          continue;
        }
        rethrow;
      }
    }
    _logger.severe('Server failed to start after $maxRetry port attempts');
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
