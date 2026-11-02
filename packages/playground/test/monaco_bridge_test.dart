import 'package:playground/playground.dart';
import 'package:test/test.dart';

void main() {
  group('MonacoBridge', () {
    late MonacoBridge bridge;

    setUp(() {
      bridge = MonacoBridge();
    });

    tearDown(() {
      bridge.dispose();
    });

    test('validates document and emits diagnostics over stream', () async {
      final diagnosticsFuture = bridge.diagnosticsStream.first;

      bridge.openDocument(
        'inmemory://model/1',
        '<ncl id="test"><unknown/></ncl>',
      );

      final event = await diagnosticsFuture;
      expect(event['uri'], equals('inmemory://model/1'));
      final list = event['diagnostics'] as List<dynamic>;
      expect(list, isNotEmpty);
    });

    test('queries completions in memory', () {
      bridge.openDocument('inmemory://model/2', '<ncl id="t"><media ');

      final result = bridge.getCompletions('inmemory://model/2', 0, 19);
      expect(result, isNotNull);
      final items = (result!['items'] as List<dynamic>)
          .map((i) => i['label'])
          .toList();
      expect(items, contains('src'));
    });

    test('queries hover in memory', () {
      bridge.openDocument('inmemory://model/3', '<ncl id="root"/>');

      final hoverText = bridge.getHover('inmemory://model/3', 0, 2);
      expect(hoverText, isNotNull);
      expect(hoverText, contains('NCL Element: `<ncl>`'));
    });

    test('queries document symbols in memory', () {
      bridge.openDocument(
        'inmemory://model/4',
        '<ncl id="doc"><head><regionBase><region id="r1"/></regionBase></head></ncl>',
      );

      final symbols = bridge.getDocumentSymbols('inmemory://model/4');
      expect(symbols, isNotNull);
      expect(symbols!.length, equals(1));
      expect(symbols.first['name'], equals('doc'));
      expect(symbols.first['children'], isNotEmpty);
    });

    test('finds related media by line number', () {
      const sample = '''<ncl>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="test.mp4">
      <area id="a1" begin="1s"/>
    </media>
    <media id="m2" src="img.png"/>
    <link id="l1">
      <bind role="onBegin" component="m1" interface="a1"/>
      <bind role="start" component="m2"/>
    </link>
  </body>
</ncl>''';
      bridge.openDocument('inmemory://model/5', sample);

      final mediaAtPort = bridge.findRelatedMedia('inmemory://model/5', 3);
      expect(mediaAtPort, isNotNull);
      expect(mediaAtPort!.id, equals('m1'));

      final mediaIdAtArea = bridge.getRelatedMediaId('inmemory://model/5', 5);
      expect(mediaIdAtArea, equals('m1'));

      final mediaIdAtBind2 = bridge.getRelatedMediaId('inmemory://model/5', 10);
      expect(mediaIdAtBind2, equals('m2'));
    });

    test('MonacoBridge sets and queries breakpoints for Monaco document', () {
      const uri = 'inmemory://model/debug_doc.ncl';
      bridge.openDocument(uri, '<ncl><body/></ncl>');

      bridge.setBreakpoints(uri, [4, 7, 12]);
      final bps = bridge.getBreakpoints(uri);
      expect(bps, containsAll([4, 7, 12]));
    });

    test('MonacoBridge simulates time passing with tick during debugging session', () async {
      const sample = '''<ncl>
  <body>
    <port id="p1" component="video1"/>
    <media id="video1" src="movie.mp4">
      <area id="a1" begin="2s" end="4s"/>
    </media>
    <media id="banner" src="img.png"/>
    <link id="l1">
      <bind role="onBegin" component="video1" interface="a1"/>
      <bind role="start" component="banner"/>
    </link>
  </body>
</ncl>''';
      const uri = 'inmemory://model/video_monaco.ncl';
      bridge.openDocument(uri, sample);

      final events = <Map<String, dynamic>>[];
      final sub = bridge.dapEventsStream.listen(events.add);

      bridge.setBreakpoints(uri, [4, 7]);
      bridge.startDebugging(uri);

      expect(bridge.isDebugging, isTrue);
      expect(bridge.isPaused, isTrue);
      expect(bridge.currentDebugLine, equals(4));
      expect(bridge.virtualClock, equals(0));

      events.clear();
      bridge.tick(1000);
      expect(bridge.virtualClock, equals(1000));
      expect(bridge.isPaused, isFalse);
      expect(bridge.activeMediaIds, contains('video1'));

      bridge.tick(1000);
      expect(bridge.virtualClock, equals(2000));
      expect(bridge.isPaused, isTrue);
      expect(bridge.currentDebugLine, equals(7));
      expect(bridge.activeMediaIds, contains('banner'));

      final evalClock = bridge.evaluate('virtualClock');
      expect(evalClock?['result'], equals('2000ms'));

      final evalMedia = bridge.evaluate('activeMedia');
      expect(evalMedia?['result'], contains('banner'));

      final vars = bridge.getVariables();
      expect(vars.any((v) => v['name'] == 'virtualClock' && v['value'] == '2000ms'), isTrue);

      bridge.stopDebugging();
      expect(bridge.isDebugging, isFalse);

      await sub.cancel();
    });

    test('MonacoBridge step simulation advances clock and stops at timed breakpoints', () {
      const sample = '''<ncl>
  <body>
    <port id="p1" component="v1"/>
    <media id="v1" src="test.mp4">
      <area id="a1" begin="1s"/>
    </media>
    <media id="overlay" src="ad.png"/>
    <link id="l1">
      <bind role="onBegin" component="v1" interface="a1"/>
      <bind role="start" component="overlay"/>
    </link>
  </body>
</ncl>''';
      const uri = 'inmemory://model/step_test.ncl';
      bridge.openDocument(uri, sample);
      bridge.setBreakpoints(uri, [7]);
      bridge.startDebugging(uri);

      expect(bridge.isPaused, isFalse);
      expect(bridge.virtualClock, equals(0));

      bridge.step(500);
      expect(bridge.virtualClock, equals(500));
      expect(bridge.isPaused, isFalse);

      bridge.step(500);
      expect(bridge.virtualClock, equals(1000));
      expect(bridge.isPaused, isTrue);
      expect(bridge.currentDebugLine, equals(7));

      bridge.stopDebugging();
    });
  });
}
