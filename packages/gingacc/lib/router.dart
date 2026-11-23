import 'dart:convert';

import 'package:get_it/get_it.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'gingacc.dart';

const defaultCurrentService = {
  "serviceContextId": "ctx-ginga-001",
  "serviceName": "DTV",
  "transportStreamId": 10042,
  "originalNetworkId": 1,
  "serviceId": 101
};

class CCWSRouter {
  static Handler getHandler({
    Map<String, dynamic>? currentService,
    GingaCC? gingacc,
    Future<void> Function(Map<String, dynamic> device)?
        onRemoteDeviceRegistered,
    Future<void> Function(String handle)? onRemoteDeviceUnregistered,
  }) {
    final router = Router();
    final service = currentService ?? defaultCurrentService;
    final cc = gingacc ?? GingaCC();

    const jsonHeaders = {
      'content-type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Private-Network': 'true',
    };

    Response serviceHandler(Request request) {
      return Response.ok(
        jsonEncode(service),
        headers: jsonHeaders,
      );
    }

    router.get('/manifest', (Request request) {
      final hostPort = request.headers['host'] ?? '127.0.0.1:${cc.ccws.port}';
      return Response.ok(
        '',
        headers: {
          'Server-BaseURL': hostPort,
          'Server-SecureBaseURL': 'https://$hostPort',
          'Server-PairingMethods': 'open',
          'Device-BrandName': 'GingaF',
          'Device-Model': 'TV3.0-Testbed',
          'Device-FriendlyName': 'GingaF TV 3.0 Receiver',
          'Access-Control-Expose-Headers':
              'Server-BaseURL, Server-SecureBaseURL, Server-PairingMethods, Device-BrandName, Device-Model, Device-FriendlyName',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Private-Network': 'true',
        },
      );
    });

    router.get('/<prefix|dtv|tv3>/current-service', serviceHandler);
    router.get('/<prefix|dtv|tv3>/current-service/', serviceHandler);

    router.post('/tv3/remote-device', (Request request) async {
      final raw = await request.readAsString();
      final body = raw.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : <String, dynamic>{};
      final deviceClass = body['deviceClass']?.toString() ?? '';
      final supportedTypes = (body['supportedTypes'] is List)
          ? (body['supportedTypes'] as List).map((e) => e.toString()).toList()
          : <String>[];
      final screenSize = body['screenSize']?.toString() ?? '1280, 720';
      final screenGraphicSize =
          body['screenGraphicSize']?.toString() ?? screenSize;
      if (deviceClass.isEmpty || supportedTypes.isEmpty) {
        return Response(
          404,
          body: jsonEncode({
            'error': 105,
            'description': 'Missing deviceClass or supportedTypes',
          }),
          headers: jsonHeaders,
        );
      }
      final device = cc.registerRemoteDevice(
        deviceClass: deviceClass,
        supportedTypes: supportedTypes,
        screenSize: screenSize,
        screenGraphicSize: screenGraphicSize,
      );
      if (onRemoteDeviceRegistered != null) {
        await onRemoteDeviceRegistered(device);
      }
      return Response.ok(
        jsonEncode({
          'handle': device['handle'],
          'url': device['url'],
        }),
        headers: jsonHeaders,
      );
    });

    router.delete('/tv3/remote-device/<handle>',
        (Request request, String handle) async {
      final removed = cc.unregisterRemoteDevice(handle);
      if (!removed) {
        return Response(
          404,
          body: jsonEncode({
            'error': 101,
            'description': 'handle $handle does not exist',
          }),
          headers: jsonHeaders,
        );
      }
      if (onRemoteDeviceUnregistered != null) {
        await onRemoteDeviceUnregistered(handle);
      }
      return Response(204, headers: jsonHeaders);
    });

    router.get('/tv3/remote-device/device/<handle>',
        (Request request, String handle) {
      final device = cc.remoteDevices[handle];
      if (device == null) {
        return Response(
          404,
          body: jsonEncode({
            'error': 101,
            'description': 'handle $handle does not exist',
          }),
          headers: jsonHeaders,
        );
      }
      return Response.ok(
        jsonEncode({'url': device['url']}),
        headers: jsonHeaders,
      );
    });

    router.delete('/tv3/remote-device/device/<handle>',
        (Request request, String handle) async {
      final removed = cc.unregisterRemoteDevice(handle);
      if (!removed) {
        return Response(
          404,
          body: jsonEncode({
            'error': 101,
            'description': 'handle $handle does not exist',
          }),
          headers: jsonHeaders,
        );
      }
      if (onRemoteDeviceUnregistered != null) {
        await onRemoteDeviceUnregistered(handle);
      }
      return Response(204, headers: jsonHeaders);
    });

    router.get('/tv3/remote-device/devices/<classId>',
        (Request request, String classId) {
      final matching = cc.getRemoteDevicesByClass(classId);
      if (matching.isEmpty) {
        return Response.ok(jsonEncode({}), headers: jsonHeaders);
      }
      return Response.ok(
        jsonEncode({'devices': matching}),
        headers: jsonHeaders,
      );
    });

    router.post('/tv3/forward', (Request request) async {
      final raw = await request.readAsString();
      final payload = raw.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : <String, dynamic>{};
      cc.recordForwardedMessage(payload);
      return Response.ok(
        jsonEncode({
          'status': 'forwarded',
          'receivedCount': cc.forwardedMessages.length,
        }),
        headers: jsonHeaders,
      );
    });

    router.get('/tv3/gingacc', (Request request) {
      return Response.ok(
        jsonEncode(cc.toSnapshotJson()),
        headers: jsonHeaders,
      );
    });

    router.put('/tv3/gingacc', (Request request) async {
      final raw = await request.readAsString();
      if (raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          cc.restoreFromSnapshotJson(Map<String, dynamic>.from(decoded));
        }
      }
      return Response.ok(
        jsonEncode(cc.toSnapshotJson()),
        headers: jsonHeaders,
      );
    });

    router.get('/tv3/gingacc/app-context', (Request request) {
      final snap = cc.getAppContextSnapshot();
      if (snap == null) {
        return Response(404, body: jsonEncode({}), headers: jsonHeaders);
      }
      return Response.ok(jsonEncode(snap), headers: jsonHeaders);
    });

    router.get('/tv3/gingacc/app-context/<appId>',
        (Request request, String appId) {
      final snap = cc.getAppContextSnapshot(appId);
      if (snap == null) {
        return Response(404, body: jsonEncode({}), headers: jsonHeaders);
      }
      return Response.ok(jsonEncode(snap), headers: jsonHeaders);
    });

    router.put('/tv3/gingacc/app-context/<appId>',
        (Request request, String appId) async {
      final raw = await request.readAsString();
      final decoded = raw.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : <String, dynamic>{};
      cc.saveAppContextSnapshot(appId, decoded);
      return Response.ok(jsonEncode(decoded), headers: jsonHeaders);
    });

    try {
      for (final plugin in GetIt.instance.getAll<CcwsRoutePlugin>()) {
        router.add(
          plugin.httpMethod,
          plugin.route,
          (Request request) => plugin.handleRequest(request),
        );
      }
    } catch (_) {}

    return router.call;
  }
}
