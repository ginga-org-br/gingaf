import 'package:shelf/shelf.dart';

abstract class CcwsRoutePlugin {
  String get route;
  String get httpMethod;
  Future<Response> handleRequest(Request request);
}
