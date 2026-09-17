import 'package:gingacc/ccws.dart';
import 'package:http/http.dart' as http;
import 'package:json5/json5.dart';
import 'package:test/test.dart';

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

    test('Verify default port is ccwsDefaultPort', () {
      final defaultCcws = CCWS();
      expect(defaultCcws.port, equals(ccwsDefaultPort));
    });

    test('Verify custom port can be configured', () {
      final customCcws = CCWS(port: 8080);
      expect(customCcws.port, equals(8080));
    });

    test('Verify current-service HTTP Endpoint Response on dynamic port',
        () async {
      expect(ccws.isRunning, isTrue);
      try {
        final uri =
            Uri.parse('http://localhost:${ccws.port}/dtv/current-service');
        final response = await http.get(uri);

        expect(response.statusCode, equals(200));
        final data = json5Decode(response.body);
        expect(data['serviceContextId'], equals('ctx-ginga-001'));
        expect(data['serviceName'], equals('DTV'));
      } catch (e) {
        fail(
            'CCWS server on port ${ccws.port} not reachable or error occurred: $e');
      }
    });
  });
}
