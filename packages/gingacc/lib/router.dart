import 'dart:convert';

import 'package:get_it/get_it.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'gingacc_plugins.dart';

const defaultCurrentService = {
  "serviceContextId": "ctx-ginga-001",
  "serviceName": "DTV",
  "transportStreamId": 10042,
  "originalNetworkId": 1,
  "serviceId": 101
};

class CCWSRouter {
  static Handler getHandler([
    Map<String, dynamic>? currentService,
  ]) {
    final router = Router();
    final service = currentService ?? defaultCurrentService;

    Response serviceHandler(Request request) {
      return Response.ok(
        jsonEncode(service),
        headers: {
          'content-type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Private-Network': 'true',
        },
      );
    }

    router.get('/dtv/current-service', serviceHandler);
    router.get('/dtv/current-service/', serviceHandler);

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
