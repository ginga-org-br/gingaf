import 'dart:convert';

import 'package:test/test.dart';
import 'package:ccws/ccws.dart';
import 'package:http/http.dart' as http;

void main() {
  group('CCWS Routes Unit Tests', () {
    late CCWS ccws;

    setUp(() async {
      ccws = CCWS();
      await ccws.start();
    });

    tearDown(() async {
      await ccws.stop();
    });

    test('Verify current-service HTTP Endpoint Response on dynamic port',
        () async {
      expect(ccws.isRunning, isTrue);
      try {
        final uri =
            Uri.parse('http://localhost:${ccws.port}/dtv/current-service');
        final response = await http.get(uri);

        expect(response.statusCode, equals(200));
        final data = jsonDecode(response.body);
        expect(data['serviceContextId'], equals('ctx-ginga-001'));
        expect(data['serviceName'], equals('DTV'));
      } catch (e) {
        fail(
            'CCWS server on port ${ccws.port} not reachable or error occurred: $e');
      }
    });
  });
}
