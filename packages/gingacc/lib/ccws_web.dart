import 'dart:convert';
import 'dart:js_interop';

import 'package:json5/json5.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:web/web.dart' as web;

import 'router.dart';

const ccwsDefaultPort = 44642;

final _logger = Logger('ginga-ccws');

class CCWS {
  final int _port;
  bool _running = false;
  int get port => _port;
  bool get isRunning => _running;

  CCWS({int port = ccwsDefaultPort}) : _port = port;

  Handler get handler =>
      Pipeline().addMiddleware(logRequests(logger: (message, isError) {
        if (isError) {
          _logger.severe(message);
        } else {
          _logger.info(message);
        }
      })).addHandler(CCWSRouter.getHandler());

  String injectCcwsFetch(String content) {
    final fetchMock = '''
<script>
(function() {
  const originalFetch = window.fetch;
  window.ccwsCallbacks = {};
  let ccwsId = 0;
  
  window.addEventListener('message', function(event) {
    try {
      const data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
      if (data && data.type === 'CCWS_RESPONSE') {
        const resolve = window.ccwsCallbacks[data.id];
        if (resolve) {
          resolve(new Response(data.body, {status: data.status, headers: {'Content-Type': 'application/json'}}));
          delete window.ccwsCallbacks[data.id];
        }
      }
    } catch(e) {}
  });

  window.fetch = async function(resource, config) {
    if (typeof resource === 'string' && resource.match(/localhost:[0-9]+\\/dtv\\/current-service/)) {
      console.log('Intercepted CCWS fetch: ' + resource);
      return new Promise((resolve, reject) => {
        const id = ++ccwsId;
        window.ccwsCallbacks[id] = resolve;
        
        if (config && config.signal) {
          config.signal.addEventListener('abort', () => {
            delete window.ccwsCallbacks[id];
            reject(new DOMException('Aborted', 'AbortError'));
          });
        }
        
        window.parent.postMessage(JSON.stringify({type: 'CCWS_REQUEST', id: id, url: resource, method: (config && config.method) ? config.method : 'GET'}), '*');
      });
    }
    return originalFetch.apply(this, arguments);
  };
})();
</script>
''';

    if (content.toLowerCase().contains('<head>')) {
      return content.replaceFirst(
          RegExp(r'<head>', caseSensitive: false), '<head>\n$fetchMock');
    } else if (content.toLowerCase().contains('<html>')) {
      return content.replaceFirst(RegExp(r'<html>', caseSensitive: false),
          '<html>\n<head>\n$fetchMock\n</head>');
    } else {
      return '$fetchMock\n$content';
    }
  }

  Future<void> start() async {
    _running = true;
    _logger.info('Starting Web CCWS');

    web.window.addEventListener(
      'message',
      (web.MessageEvent event) {
        _handleMessage(event);
      }.toJS,
    );
  }

  Future<void> _handleMessage(web.MessageEvent event) async {
    final rawData = event.data?.dartify();
    try {
      Map<String, dynamic>? mapData;

      if (rawData is String && rawData.trim().startsWith('{')) {
        try {
          final decoded = json5Decode(rawData);
          if (decoded is Map) {
            mapData = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      } else if (rawData is Map) {
        mapData = Map<String, dynamic>.from(rawData);
      }

      if (mapData != null && mapData['type'] == 'CCWS_REQUEST') {
        _logger.info(
            'CCWS Dart received request from iframe: ${mapData["url"]}');
        final url = mapData['url'] as String;
        final method = (mapData['method'] as String?) ?? 'GET';

        final request = Request(method, Uri.parse(url));
        final response = await handler(request);
        final body = await response.readAsString();

        final source = event.source as web.Window?;
        source?.postMessage(
          jsonEncode({
            'type': 'CCWS_RESPONSE',
            'id': mapData['id'],
            'status': response.statusCode,
            'body': body,
          }).toJS,
          '*'.toJS,
        );
      }
    } catch (e, st) {
      _logger.severe('Error processing CCWS_REQUEST from iframe: $e\n$st');
    }
  }

  Future<void> stop() async {
    _running = false;
  }
}
