import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gingacc/ccws.dart';
import 'package:gingacc/ssdp.dart';
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
      final uri =
          Uri.parse('http://localhost:${ccws.port}/dtv/current-service');
      final response = await http.get(uri);

      expect(response.statusCode, equals(200));
      final data = json5Decode(response.body);
      expect(data['serviceContextId'], equals('ctx-ginga-001'));
      expect(data['serviceName'], equals('DTV'));

      final tv3Uri =
          Uri.parse('http://localhost:${ccws.port}/tv3/current-service');
      final tv3Response = await http.get(tv3Uri);
      expect(tv3Response.statusCode, equals(200));
    });

    test('Verify remote-device registration and TV3WS forwarding',
        () async {
      final base = 'http://localhost:${ccws.port}';
      final regRes = await http.post(
        Uri.parse('$base/tv3/remote-device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceClass': 'ncl-360-vr',
          'supportedTypes': ['application/x-ncl360'],
        }),
      );
      expect(regRes.statusCode, equals(200));
      final regData = jsonDecode(regRes.body) as Map<String, dynamic>;
      final handle = regData['handle'] as String;
      expect(handle, startsWith('rd-ncl-360-vr-'));
      expect(regData['url'], startsWith('ws://localhost:45'));
      final wsPort = Uri.parse(regData['url'] as String).port;
      expect(wsPort, inInclusiveRange(45000, 45199));
      expect(ccws.gingacc.remoteDevices.containsKey(handle), isTrue);

      final listRes = await http.get(
        Uri.parse('$base/tv3/remote-device/devices/ncl-360-vr'),
      );
      expect(listRes.statusCode, equals(200));
      final listData = jsonDecode(listRes.body) as Map<String, dynamic>;
      expect((listData['devices'] as List).length, equals(1));

      final fwdRes = await http.post(
        Uri.parse('$base/tv3/forward'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nodeId': 'scene360',
          'label': 'spot1',
          'eventType': 'view',
          'transition': 'starts',
        }),
      );
      expect(fwdRes.statusCode, equals(200));
      expect(ccws.gingacc.forwardedMessages.length, equals(1));

      final delRes = await http.delete(
        Uri.parse('$base/tv3/remote-device/$handle'),
      );
      expect(delRes.statusCode, equals(204));
      expect(ccws.gingacc.remoteDevices.containsKey(handle), isFalse);
    });

    test('Verify /manifest endpoint and SSDP discovery', () async {
      final manifestUri = Uri.parse('http://127.0.0.1:${ccws.port}/manifest');
      final res = await http.get(manifestUri);
      expect(res.statusCode, equals(200));
      expect(res.headers['server-baseurl'], equals('127.0.0.1:${ccws.port}'));
      expect(
        res.headers['server-securebaseurl'],
        equals('https://127.0.0.1:${ccws.port}'),
      );
      expect(res.headers['server-pairingmethods'], equals('open'));
      expect(res.headers['device-brandname'], equals('GingaF'));
      expect(res.headers['device-model'], equals('TV3.0-Testbed'));
      expect(
        res.headers['device-friendlyname'],
        equals('GingaF TV 3.0 Receiver'),
      );

      final discovered = await SsdpClient.discover(port: ccws.ssdpPort!);
      expect(discovered, isNotEmpty);
      expect(
        discovered.first.location,
        equals('http://127.0.0.1:${ccws.port}/manifest'),
      );
      expect(
        discovered.first.baseUrl,
        equals('127.0.0.1:${ccws.port}'),
      );
    });

    test('Verify CCWS.start() emits SSDP NOTIFY ssdp:alive and stop() emits ssdp:byebye',
        () async {
      final listener = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      final testPort = listener.port;
      try {
        listener.joinMulticast(InternetAddress(ssdpMulticastAddress));
      } catch (_) {}

      final aliveCompleter = Completer<String>();
      final byebyeCompleter = Completer<String>();
      listener.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = listener.receive();
        if (dg == null) return;
        final text = utf8.decode(dg.data, allowMalformed: true);
        if (text.startsWith('NOTIFY') &&
            text.contains('NT: $ssdpSearchTarget')) {
          if (text.contains('NTS: ssdp:alive') && !aliveCompleter.isCompleted) {
            aliveCompleter.complete(text);
          } else if (text.contains('NTS: ssdp:byebye') &&
              !byebyeCompleter.isCompleted) {
            byebyeCompleter.complete(text);
          }
        }
      });

      final announceCcws = CCWS(ssdpPort: testPort);
      await announceCcws.start();

      final aliveMsg =
          await aliveCompleter.future.timeout(const Duration(seconds: 2));
      expect(aliveMsg, contains('NOTIFY * HTTP/1.1'));
      expect(aliveMsg, contains('NT: $ssdpSearchTarget'));
      expect(aliveMsg, contains('NTS: ssdp:alive'));
      expect(
        aliveMsg,
        contains('LOCATION: http://127.0.0.1:${announceCcws.port}/manifest'),
      );
      expect(aliveMsg, contains('CACHE-CONTROL: max-age=1800'));

      await announceCcws.stop();

      final byebyeMsg =
          await byebyeCompleter.future.timeout(const Duration(seconds: 2));
      expect(byebyeMsg, contains('NOTIFY * HTTP/1.1'));
      expect(byebyeMsg, contains('NT: $ssdpSearchTarget'));
      expect(byebyeMsg, contains('NTS: ssdp:byebye'));
      expect(byebyeMsg, isNot(contains('LOCATION:')));

      listener.close();
    });
  });
}
