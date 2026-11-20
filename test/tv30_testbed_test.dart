import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/web_utils_stub.dart'
    if (dart.library.js_interop) 'package:gingaf/web_utils_web.dart';
import 'package:gingaf/web_utils_stub.dart'
    if (dart.library.js_interop) 'package:gingaf/web_utils_web_tv30_testbed.dart'
    as tv30_testbed;

void main() {
  group(
    'TV 3.0 Remote Control and Key Mapping Tests',
    skip: !kIsWeb,
    () {
      test('maps directional arrow keys', () {
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('ArrowUp'), 'UP');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Up'), 'UP');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('ArrowDown'), 'DOWN');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Down'), 'DOWN');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('ArrowLeft'), 'LEFT');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Left'), 'LEFT');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('ArrowRight'), 'RIGHT');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Right'), 'RIGHT');
      });

      test('maps select and enter keys', () {
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Enter'), 'ENTER');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('enter'), 'ENTER');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Select'), 'ENTER');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('OK'), 'ENTER');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('ok'), 'ENTER');
      });

      test('maps standard Ginga color keys', () {
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('F1'), 'RED');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Red'), 'RED');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('red'), 'RED');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('r'), 'RED');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('ColorF0Red'), 'RED');

        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('F2'), 'GREEN');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Green'), 'GREEN');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('green'), 'GREEN');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('g'), 'GREEN');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('ColorF1Green'), 'GREEN');

        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('F3'), 'YELLOW');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Yellow'), 'YELLOW');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('yellow'), 'YELLOW');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('y'), 'YELLOW');
        expect(
            tv30_testbed.mapTv30TestbedKeyToNclKey('ColorF2Yellow'), 'YELLOW');

        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('F4'), 'BLUE');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Blue'), 'BLUE');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('blue'), 'BLUE');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('b'), 'BLUE');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('ColorF3Blue'), 'BLUE');
      });

      test('maps numeric digits', () {
        for (var i = 0; i <= 9; i++) {
          expect(tv30_testbed.mapTv30TestbedKeyToNclKey('$i'), '$i');
        }
      });

      test('maps info, exit and escape keys', () {
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('F5'), 'INFO');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Info'), 'INFO');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('info'), 'INFO');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Escape'), 'ESCAPE');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Back'), 'ESCAPE');
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Exit'), 'ESCAPE');
      });

      test('returns null for unhandled keys', () {
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Shift'), isNull);
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Alt'), isNull);
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Control'), isNull);
        expect(tv30_testbed.mapTv30TestbedKeyToNclKey('Tab'), isNull);
      });
    },
  );

  group(
    'TV 3.0 Mode and Testbed Attachment on non-web platforms',
    skip: kIsWeb,
    () {
      test('isTv30Testbed defaults to false', () {
        expect(isTv30Testbed(), isFalse);
      });

      test('attachTv30Testbed returns null when not in TV 3.0 mode', () async {
        final detach = await attachTv30Testbed(onKey: (_) {});
        expect(detach, isNull);
      });
    },
  );
}
