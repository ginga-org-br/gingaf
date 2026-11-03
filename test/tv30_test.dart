import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ginga.dart';

void main() {
  group('TV 3.0 Remote Control and Key Mapping Tests', () {
    test('maps directional arrow keys', () {
      expect(mapTv30KeyToNclKey('ArrowUp'), 'UP');
      expect(mapTv30KeyToNclKey('Up'), 'UP');
      expect(mapTv30KeyToNclKey('ArrowDown'), 'DOWN');
      expect(mapTv30KeyToNclKey('Down'), 'DOWN');
      expect(mapTv30KeyToNclKey('ArrowLeft'), 'LEFT');
      expect(mapTv30KeyToNclKey('Left'), 'LEFT');
      expect(mapTv30KeyToNclKey('ArrowRight'), 'RIGHT');
      expect(mapTv30KeyToNclKey('Right'), 'RIGHT');
    });

    test('maps select and enter keys', () {
      expect(mapTv30KeyToNclKey('Enter'), 'ENTER');
      expect(mapTv30KeyToNclKey('enter'), 'ENTER');
      expect(mapTv30KeyToNclKey('Select'), 'ENTER');
      expect(mapTv30KeyToNclKey('OK'), 'ENTER');
      expect(mapTv30KeyToNclKey('ok'), 'ENTER');
    });

    test('maps standard Ginga color keys', () {
      expect(mapTv30KeyToNclKey('F1'), 'RED');
      expect(mapTv30KeyToNclKey('Red'), 'RED');
      expect(mapTv30KeyToNclKey('red'), 'RED');
      expect(mapTv30KeyToNclKey('r'), 'RED');
      expect(mapTv30KeyToNclKey('ColorF0Red'), 'RED');

      expect(mapTv30KeyToNclKey('F2'), 'GREEN');
      expect(mapTv30KeyToNclKey('Green'), 'GREEN');
      expect(mapTv30KeyToNclKey('green'), 'GREEN');
      expect(mapTv30KeyToNclKey('g'), 'GREEN');
      expect(mapTv30KeyToNclKey('ColorF1Green'), 'GREEN');

      expect(mapTv30KeyToNclKey('F3'), 'YELLOW');
      expect(mapTv30KeyToNclKey('Yellow'), 'YELLOW');
      expect(mapTv30KeyToNclKey('yellow'), 'YELLOW');
      expect(mapTv30KeyToNclKey('y'), 'YELLOW');
      expect(mapTv30KeyToNclKey('ColorF2Yellow'), 'YELLOW');

      expect(mapTv30KeyToNclKey('F4'), 'BLUE');
      expect(mapTv30KeyToNclKey('Blue'), 'BLUE');
      expect(mapTv30KeyToNclKey('blue'), 'BLUE');
      expect(mapTv30KeyToNclKey('b'), 'BLUE');
      expect(mapTv30KeyToNclKey('ColorF3Blue'), 'BLUE');
    });

    test('maps numeric digits', () {
      for (var i = 0; i <= 9; i++) {
        expect(mapTv30KeyToNclKey('$i'), '$i');
      }
    });

    test('maps info, exit and escape keys', () {
      expect(mapTv30KeyToNclKey('F5'), 'INFO');
      expect(mapTv30KeyToNclKey('Info'), 'INFO');
      expect(mapTv30KeyToNclKey('info'), 'INFO');
      expect(mapTv30KeyToNclKey('Escape'), 'ESCAPE');
      expect(mapTv30KeyToNclKey('Back'), 'ESCAPE');
      expect(mapTv30KeyToNclKey('Exit'), 'ESCAPE');
    });

    test('returns null for unhandled keys', () {
      expect(mapTv30KeyToNclKey('Shift'), isNull);
      expect(mapTv30KeyToNclKey('Alt'), isNull);
      expect(mapTv30KeyToNclKey('Control'), isNull);
      expect(mapTv30KeyToNclKey('Tab'), isNull);
    });
  });

  group('TV 3.0 Mode and Streams on non-web platforms', () {
    test('isTv30Mode defaults to false', () {
      expect(isTv30Mode(), isFalse);
    });

    test('event streams are available', () {
      expect(tv30KeyStream, isNotNull);
      expect(tv30TimeStream, isNotNull);
      expect(tv30StreamEventStream, isNotNull);
    });
  });
}
