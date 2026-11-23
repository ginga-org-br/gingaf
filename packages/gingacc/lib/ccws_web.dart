import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:json5/json5.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:web/web.dart' as web;

import 'gingacc.dart';

const ccwsDefaultPort = 44642;

final _logger = Logger('ginga-ccws');

class CCWS {
  final int _port;
  final GingaCC gingacc;
  bool _running = false;
  final Map<String, StreamSubscription<Map<String, dynamic>>> _wsSubs = {};
  int get port => _port;
  int? get ssdpPort => null;
  SsdpServer? get ssdpServer => null;
  bool get isRunning => _running;

  CCWS({
    int port = ccwsDefaultPort,
    int ssdpPort = ssdpDefaultPort,
    bool enableSsdp = false,
    GingaCC? gingacc,
  })  : _port = port,
        gingacc = gingacc ?? GingaCC();

  Handler get handler =>
      Pipeline().addMiddleware(logRequests(logger: (message, isError) {
        if (isError) {
          _logger.severe(message);
        } else {
          _logger.info(message);
        }
      })).addHandler(CCWSRouter.getHandler(gingacc: gingacc));

  String injectCcwsFetch(String content) {
    final fetchMock = r'''
<script>
(function() {
  const originalFetch = window.fetch;
  const OriginalWebSocket = window.WebSocket;
  window.ccwsCallbacks = {};
  window.ccwsSockets = {};
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
      } else if (data && data.type === 'CCWS_WS_MESSAGE') {
        const sock = window.ccwsSockets[data.wsUrl];
        if (sock && typeof sock.onmessage === 'function') {
          sock.onmessage({ data: typeof data.payload === 'string' ? data.payload : JSON.stringify(data.payload) });
        }
      } else if (data && data.type === 'CCWS_WS_CLOSED') {
        const sock = window.ccwsSockets[data.wsUrl];
        if (sock) {
          sock.readyState = 3;
          if (typeof sock.onclose === 'function') sock.onclose({});
          delete window.ccwsSockets[data.wsUrl];
        }
      }
    } catch(e) {}
  });

  window.fetch = async function(resource, config) {
    const urlStr = typeof resource === 'string' ? resource : (resource && resource.url ? resource.url : '');
    if (urlStr.match(/(?:localhost|127\.0\.0\.1):[0-9]+\/(?:dtv|tv3)\//) || urlStr.startsWith('/tv3/') || urlStr.startsWith('/dtv/')) {
      const resolvedUrl = urlStr.startsWith('/') ? ('http://localhost:44642' + urlStr) : urlStr;
      return new Promise((resolve, reject) => {
        const id = ++ccwsId;
        window.ccwsCallbacks[id] = resolve;
        if (config && config.signal) {
          config.signal.addEventListener('abort', () => {
            delete window.ccwsCallbacks[id];
            reject(new DOMException('Aborted', 'AbortError'));
          });
        }
        window.parent.postMessage(JSON.stringify({
          type: 'CCWS_REQUEST',
          id: id,
          url: resolvedUrl,
          method: (config && config.method) ? config.method : 'GET',
          body: (config && config.body) ? String(config.body) : ''
        }), '*');
      });
    }
    return originalFetch.apply(this, arguments);
  };

  window.WebSocket = function(url, protocols) {
    if (typeof url === 'string' && url.match(/^ws:\/\/(?:localhost|127\.0\.0\.1):45[0-1][0-9]{2}/)) {
      const sock = {
        url: url,
        readyState: 0,
        onopen: null,
        onmessage: null,
        onclose: null,
        onerror: null,
        send: function(payload) {
          window.parent.postMessage(JSON.stringify({
            type: 'CCWS_WS_SEND',
            wsUrl: url,
            payload: typeof payload === 'string' ? payload : JSON.stringify(payload)
          }), '*');
        },
        close: function() {
          this.readyState = 3;
          window.parent.postMessage(JSON.stringify({
            type: 'CCWS_WS_CLOSE',
            wsUrl: url
          }), '*');
          delete window.ccwsSockets[url];
          if (typeof this.onclose === 'function') this.onclose({});
        }
      };
      window.ccwsSockets[url] = sock;
      window.parent.postMessage(JSON.stringify({
        type: 'CCWS_WS_OPEN',
        wsUrl: url
      }), '*');
      setTimeout(function() {
        sock.readyState = 1;
        if (typeof sock.onopen === 'function') sock.onopen({});
      }, 0);
      return sock;
    }
    return protocols !== undefined ? new OriginalWebSocket(url, protocols) : new OriginalWebSocket(url);
  };
  window.WebSocket.CONNECTING = 0;
  window.WebSocket.OPEN = 1;
  window.WebSocket.CLOSING = 2;
  window.WebSocket.CLOSED = 3;
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

  Future<void> start({int? ssdpPort, bool? enableSsdp}) async {
    if (_running) return;
    _running = true;
    _logger.info('Starting Web CCWS');

    web.window.addEventListener(
      'message',
      (web.MessageEvent event) {
        _handleMessage(event);
      }.toJS,
    );
  }

  RemoteDeviceChannel? _findChannelByWsUrl(String wsUrl) {
    for (final ch in gingacc.allRemoteDeviceChannels) {
      if (ch.wsUrl == wsUrl) return ch;
    }
    return null;
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

      if (mapData == null) return;
      final type = mapData['type'];
      final source = event.source as web.Window?;

      if (type == 'CCWS_REQUEST') {
        final url = mapData['url'] as String;
        final method = (mapData['method'] as String?) ?? 'GET';
        final reqBody = mapData['body']?.toString() ?? '';

        final request = Request(
          method,
          Uri.parse(url),
          body: reqBody.isNotEmpty ? reqBody : null,
        );
        final response = await handler(request);
        final body = await response.readAsString();

        source?.postMessage(
          jsonEncode({
            'type': 'CCWS_RESPONSE',
            'id': mapData['id'],
            'status': response.statusCode,
            'body': body,
          }).toJS,
          '*'.toJS,
        );
      } else if (type == 'CCWS_WS_OPEN') {
        final wsUrl = mapData['wsUrl']?.toString() ?? '';
        final channel = _findChannelByWsUrl(wsUrl);
        if (channel != null && source != null) {
          await _wsSubs[wsUrl]?.cancel();
          _wsSubs[wsUrl] = channel.onHostMessage.listen((msg) {
            source.postMessage(
              jsonEncode({
                'type': 'CCWS_WS_MESSAGE',
                'wsUrl': wsUrl,
                'payload': msg,
              }).toJS,
              '*'.toJS,
            );
          });
          channel.onClose.listen((_) {
            source.postMessage(
              jsonEncode({
                'type': 'CCWS_WS_CLOSED',
                'wsUrl': wsUrl,
              }).toJS,
              '*'.toJS,
            );
          });
        }
      } else if (type == 'CCWS_WS_SEND') {
        final wsUrl = mapData['wsUrl']?.toString() ?? '';
        final channel = _findChannelByWsUrl(wsUrl);
        final payload = mapData['payload'];
        if (channel != null && payload != null) {
          final decoded = payload is String ? jsonDecode(payload) : payload;
          if (decoded is Map) {
            channel.sendToHost(Map<String, dynamic>.from(decoded));
          }
        }
      } else if (type == 'CCWS_WS_CLOSE') {
        final wsUrl = mapData['wsUrl']?.toString() ?? '';
        await _wsSubs.remove(wsUrl)?.cancel();
        final channel = _findChannelByWsUrl(wsUrl);
        if (channel != null) {
          gingacc.unregisterRemoteDevice(channel.deviceId);
        }
      }
    } catch (e, st) {
      _logger.severe('Error processing CCWS message from iframe: $e\n$st');
    }
  }

  Future<void> stop() async {
    _running = false;
    for (final sub in _wsSubs.values) {
      await sub.cancel();
    }
    _wsSubs.clear();
  }
}
