import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const defaultCurrentService = {
  "serviceContextId": "ctx-ginga-001",
  "serviceName": "DTV",
  "transportStreamId": 10042,
  "originalNetworkId": 1,
  "serviceId": 101
};

class CCWSRouter {
  static Handler getHandler([Map<String, dynamic>? currentService]) {
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

    return router.call;
  }
}
