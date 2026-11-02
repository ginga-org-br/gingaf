import 'package:playground/playground.dart';
import 'package:test/test.dart';

void main() {
  group('DapServer', () {
    late DapServer dap;

    setUp(() {
      dap = DapServer();
    });

    test('initializes and reports DAP capabilities', () {
      final resp = dap.handleRequest({
        'seq': 1,
        'command': 'initialize',
        'arguments': {'clientID': 'vscode'},
      });

      expect(resp['success'], isTrue);
      expect(resp['body']['supportsConfigurationDoneRequest'], isTrue);
    });

    test('handles launch and sets breakpoints', () {
      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': '/app/main.ncl'},
      });

      expect(dap.isRunning, isTrue);
      expect(dap.currentSource, equals('/app/main.ncl'));

      final bpResp = dap.handleRequest({
        'seq': 2,
        'command': 'setBreakpoints',
        'arguments': {
          'source': {'path': '/app/main.ncl'},
          'breakpoints': [
            {'line': 5},
            {'line': 10},
          ],
        },
      });

      expect(bpResp['success'], isTrue);
      final bps = bpResp['body']['breakpoints'] as List<dynamic>;
      expect(bps.length, equals(2));
      expect(bps.first['verified'], isTrue);
    });

    test('supports stepping and stack trace', () {
      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': '/app/main.ncl'},
      });

      final stepResp = dap.handleRequest({
        'seq': 2,
        'command': 'next',
      });
      expect(stepResp['success'], isTrue);
      expect(dap.currentLine, equals(2));

      final traceResp = dap.handleRequest({
        'seq': 3,
        'command': 'stackTrace',
      });
      expect(traceResp['success'], isTrue);
      final frames = traceResp['body']['stackFrames'] as List<dynamic>;
      expect(frames.first['line'], equals(2));
    });

    test('inspects active scopes and variables', () {
      final scopesResp = dap.handleRequest({'seq': 1, 'command': 'scopes'});
      expect(scopesResp['success'], isTrue);
      final scopes = scopesResp['body']['scopes'] as List<dynamic>;
      expect(scopes.length, equals(1));
      expect(scopes.first['name'], equals('Active NCL Context'));

      final varsResp = dap.handleRequest({
        'seq': 2,
        'command': 'variables',
        'arguments': {'variablesReference': 1000},
      });
      expect(varsResp['success'], isTrue);
      final vars = (varsResp['body']['variables'] as List<dynamic>)
          .map((v) => v['name'])
          .toList();
      expect(vars, contains('activeContext'));
      expect(vars, contains('state'));
    });

    test('plays until stopping at first breakpoint on configurationDone', () {
      final events = <Map<String, dynamic>>[];
      dap.onEvent = (e) => events.add(e);

      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': '/app/sample.ncl'},
      });

      dap.handleRequest({
        'seq': 2,
        'command': 'setBreakpoints',
        'arguments': {
          'source': {'path': '/app/sample.ncl'},
          'breakpoints': [
            {'line': 8},
            {'line': 15},
          ],
        },
      });

      dap.handleRequest({
        'seq': 3,
        'command': 'configurationDone',
      });

      expect(dap.currentLine, equals(8));
      final stopped = events.firstWhere((e) => e['event'] == 'stopped');
      expect(stopped['body']['reason'], equals('breakpoint'));
    });

    test('continues execution until stopping at subsequent breakpoints in NCL XML', () {
      final events = <Map<String, dynamic>>[];
      dap.onEvent = (e) => events.add(e);

      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': '/app/sample.ncl'},
      });

      dap.handleRequest({
        'seq': 2,
        'command': 'setBreakpoints',
        'arguments': {
          'source': {'path': '/app/sample.ncl'},
          'breakpoints': [
            {'line': 10},
            {'line': 25},
          ],
        },
      });

      dap.handleRequest({'seq': 3, 'command': 'configurationDone'});
      expect(dap.currentLine, equals(10));

      events.clear();
      dap.handleRequest({'seq': 4, 'command': 'continue'});

      expect(dap.currentLine, equals(25));
      expect(events.any((e) => e['event'] == 'stopped' && e['body']['reason'] == 'breakpoint'), isTrue);

      events.clear();
      dap.handleRequest({'seq': 5, 'command': 'continue'});
      expect(events.any((e) => e['event'] == 'terminated'), isTrue);
    });

    test('notifies stopped with reason breakpoint when stepping lands on a breakpoint', () {
      final events = <Map<String, dynamic>>[];
      dap.onEvent = (e) => events.add(e);

      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': '/app/sample.ncl'},
      });

      dap.handleRequest({
        'seq': 2,
        'command': 'setBreakpoints',
        'arguments': {
          'source': {'path': '/app/sample.ncl'},
          'breakpoints': [{'line': 2}],
        },
      });

      events.clear();
      dap.handleRequest({'seq': 3, 'command': 'next'});
      expect(dap.currentLine, equals(2));
      expect(events.last['event'], equals('stopped'));
      expect(events.last['body']['reason'], equals('breakpoint'));
    });

    test('DAP handles video.ncl playback across multiple breakpoints', () {
      final events = <Map<String, dynamic>>[];
      dap.onEvent = (e) => events.add(e);

      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': '/examples/video.ncl'},
      });

      dap.handleRequest({
        'seq': 2,
        'command': 'setBreakpoints',
        'arguments': {
          'source': {'path': '/examples/video.ncl'},
          'breakpoints': [
            {'line': 4},
            {'line': 7},
            {'line': 16},
          ],
        },
      });

      dap.handleRequest({'seq': 3, 'command': 'configurationDone'});
      expect(dap.currentLine, equals(4));

      dap.handleRequest({'seq': 4, 'command': 'continue'});
      expect(dap.currentLine, equals(7));

      dap.handleRequest({'seq': 5, 'command': 'continue'});
      expect(dap.currentLine, equals(16));

      events.clear();
      dap.handleRequest({'seq': 6, 'command': 'continue'});
      expect(events.any((e) => e['event'] == 'terminated'), isTrue);
    });

    test('DAP pause triggers stopped event with pause reason', () {
      final events = <Map<String, dynamic>>[];
      dap.onEvent = (e) => events.add(e);

      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': '/examples/video.ncl'},
      });

      final resp = dap.handleRequest({'seq': 2, 'command': 'pause'});
      expect(resp['success'], isTrue);
      expect(events.any((e) => e['event'] == 'stopped' && e['body']['reason'] == 'pause'), isTrue);
    });

    test('DAP disconnect terminates running session', () {
      final events = <Map<String, dynamic>>[];
      dap.onEvent = (e) => events.add(e);

      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': '/examples/video.ncl'},
      });
      expect(dap.isRunning, isTrue);

      final discResp = dap.handleRequest({'seq': 2, 'command': 'disconnect'});
      expect(discResp['success'], isTrue);
      expect(dap.isRunning, isFalse);
      expect(events.any((e) => e['event'] == 'terminated'), isTrue);
    });

    test('DAP executes Primeiro Joao presentation sequence with breakpoints and stepping', () {
      final events = <Map<String, dynamic>>[];
      dap.onEvent = (e) => events.add(e);

      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': '/examples/primeiro_joao.ncl'},
      });

      dap.handleRequest({
        'seq': 2,
        'command': 'setBreakpoints',
        'arguments': {
          'source': {'path': '/examples/primeiro_joao.ncl'},
          'breakpoints': [
            {'line': 20},
            {'line': 21},
            {'line': 25},
            {'line': 28},
          ],
        },
      });

      dap.handleRequest({'seq': 3, 'command': 'configurationDone'});
      expect(dap.currentLine, equals(20));

      dap.handleRequest({'seq': 4, 'command': 'next'});
      expect(dap.currentLine, equals(21));

      dap.handleRequest({'seq': 5, 'command': 'continue'});
      expect(dap.currentLine, equals(25));

      dap.handleRequest({'seq': 6, 'command': 'continue'});
      expect(dap.currentLine, equals(28));

      events.clear();
      dap.handleRequest({'seq': 7, 'command': 'continue'});
      expect(events.any((e) => e['event'] == 'terminated'), isTrue);
    });

    test('DAP handles Primeiro Joao area segment stepping, stack trace, and expression evaluation', () {
      final dap = DapServer();
      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': '/examples/primeiro_joao.ncl'},
      });

      dap.handleRequest({
        'seq': 2,
        'command': 'setBreakpoints',
        'arguments': {
          'source': {'path': '/examples/primeiro_joao.ncl'},
          'breakpoints': [{'line': 21}, {'line': 25}],
        },
      });

      dap.handleRequest({'seq': 3, 'command': 'configurationDone'});
      expect(dap.currentLine, equals(21));

      final evalContext = dap.handleRequest({
        'seq': 4,
        'command': 'evaluate',
        'arguments': {'expression': 'activeContext'},
      });
      expect(evalContext['body']['result'], equals('body'));

      final evalAnim = dap.handleRequest({
        'seq': 5,
        'command': 'evaluate',
        'arguments': {'expression': 'animation'},
      });
      expect(evalAnim['body']['result'], contains('animGar.mp4'));

      final evalState = dap.handleRequest({
        'seq': 6,
        'command': 'evaluate',
        'arguments': {'expression': 'state'},
      });
      expect(evalState['body']['result'], equals('PAUSED'));

      dap.handleRequest({'seq': 7, 'command': 'stepIn'});
      expect(dap.currentLine, equals(22));

      dap.handleRequest({'seq': 8, 'command': 'next'});
      expect(dap.currentLine, equals(23));

      final traceResp = dap.handleRequest({'seq': 9, 'command': 'stackTrace'});
      expect(traceResp['success'], isTrue);
      final frames = traceResp['body']['stackFrames'] as List<dynamic>;
      expect(frames.first['line'], equals(23));

      dap.handleRequest({'seq': 10, 'command': 'stepOut'});
      expect(dap.currentLine, equals(25));
    });

    test('DAP handles Primeiro Joao dynamic breakpoint modification, synchronization links, and restart', () {
      final dap = DapServer();
      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': '/examples/primeiro_joao.ncl'},
      });

      dap.handleRequest({
        'seq': 2,
        'command': 'setBreakpoints',
        'arguments': {
          'source': {'path': '/examples/primeiro_joao.ncl'},
          'breakpoints': [{'line': 28}],
        },
      });

      dap.handleRequest({'seq': 3, 'command': 'configurationDone'});
      expect(dap.currentLine, equals(28));

      dap.handleRequest({
        'seq': 4,
        'command': 'setBreakpoints',
        'arguments': {
          'source': {'path': '/examples/primeiro_joao.ncl'},
          'breakpoints': [{'line': 28}, {'line': 34}, {'line': 38}, {'line': 42}],
        },
      });

      dap.handleRequest({'seq': 5, 'command': 'continue'});
      expect(dap.currentLine, equals(34));

      dap.handleRequest({'seq': 6, 'command': 'continue'});
      expect(dap.currentLine, equals(38));

      dap.handleRequest({'seq': 7, 'command': 'continue'});
      expect(dap.currentLine, equals(42));

      dap.handleRequest({'seq': 8, 'command': 'restart'});
      expect(dap.currentLine, equals(28));
    });

    test('DAP handles exception breakpoints and pause during Primeiro Joao playback', () {
      final dap = DapServer();
      final events = <Map<String, dynamic>>[];
      dap.onEvent = (e) => events.add(e);

      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': '/examples/primeiro_joao.ncl'},
      });

      final excResp = dap.handleRequest({
        'seq': 2,
        'command': 'setExceptionBreakpoints',
        'arguments': {'filters': []},
      });
      expect(excResp['success'], isTrue);

      final pauseResp = dap.handleRequest({'seq': 3, 'command': 'pause'});
      expect(pauseResp['success'], isTrue);
      expect(events.any((e) => e['event'] == 'stopped' && e['body']['reason'] == 'pause'), isTrue);
    });

    test('finds related media by line number and configures document breakpoints', () {
      const nclContent = '''<ncl>
  <body>
    <port id="p1" component="video1"/>
    <media id="video1" src="movie.mp4"/>
    <media id="banner" src="img.png"/>
    <link id="l1">
      <bind role="onEnd" component="video1"/>
      <bind role="start" component="banner"/>
    </link>
  </body>
</ncl>''';

      final dap = DapServer(nclContent: nclContent);
      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': '/fake/test.ncl'},
      });

      final mediaAtPort = dap.findRelatedMedia(3);
      expect(mediaAtPort, isNotNull);
      expect(mediaAtPort!.id, equals('video1'));

      final mediaAtBanner = dap.findRelatedMedia(5);
      expect(mediaAtBanner, isNotNull);
      expect(mediaAtBanner!.id, equals('banner'));

      final mediaAtBind2 = dap.findRelatedMedia(8);
      expect(mediaAtBind2, isNotNull);
      expect(mediaAtBind2!.id, equals('banner'));

      final bpResp = dap.handleRequest({
        'seq': 2,
        'command': 'setBreakpoints',
        'arguments': {
          'source': {'path': '/fake/test.ncl'},
          'breakpoints': [
            {'line': 8},
          ],
        },
      });
      expect(bpResp['success'], isTrue);
      expect(dap.document, isNotNull);
      expect(dap.document!.breakpointLines, contains(8));
      expect(dap.document!.breakpointMediaIds, contains('banner'));
    });

    test('DAP debugging simulates time passing with tick across media lifecycle breakpoints', () {
      final events = <Map<String, dynamic>>[];
      final dap = DapServer();
      dap.onEvent = (e) => events.add(e);

      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': 'examples/video.ncl'},
      });

      dap.handleRequest({
        'seq': 2,
        'command': 'setBreakpoints',
        'arguments': {
          'source': {'path': 'examples/video.ncl'},
          'breakpoints': [
            {'line': 4},
            {'line': 7},
            {'line': 11},
          ],
        },
      });

      dap.handleRequest({'seq': 3, 'command': 'configurationDone'});

      expect(dap.isPaused, isTrue);
      expect(dap.currentLine, equals(4));
      expect(dap.virtualClock, equals(0));
      expect(events.any((e) => e['event'] == 'stopped' && e['body']['line'] == 4), isTrue);

      events.clear();
      dap.tick(1000);
      expect(dap.virtualClock, equals(1000));
      expect(dap.isPaused, isFalse);
      expect(dap.activeMediaIds, contains('video'));

      dap.tick(1000);
      expect(dap.virtualClock, equals(2000));
      expect(dap.isPaused, isTrue);
      expect(dap.currentLine, equals(7));
      expect(events.any((e) => e['event'] == 'stopped' && e['body']['line'] == 7), isTrue);

      final varsResp = dap.handleRequest({
        'seq': 4,
        'command': 'variables',
        'arguments': {'variablesReference': 1000},
      });
      final vars = varsResp['body']['variables'] as List<dynamic>;
      final clockVar = vars.firstWhere((v) => v['name'] == 'virtualClock');
      expect(clockVar['value'], equals('2000ms'));
      final stateVar = vars.firstWhere((v) => v['name'] == 'state');
      expect(stateVar['value'], equals('PAUSED'));

      events.clear();
      dap.tick(2000);
      expect(dap.virtualClock, equals(4000));
      expect(dap.isPaused, isTrue);
      expect(dap.currentLine, equals(11));
      expect(events.any((e) => e['event'] == 'stopped' && e['body']['line'] == 11 && e['body']['action'] == 'start'), isTrue);

      events.clear();
      dap.tick(2000);
      expect(dap.virtualClock, equals(6000));
      expect(dap.activeMediaIds.contains('red_bg'), isFalse);

      dap.handleRequest({'seq': 10, 'command': 'disconnect'});
      expect(events.any((e) => e['event'] == 'terminated'), isTrue);
    });

    test('DAP handles tick command over JSON-RPC request and updates virtualClock and activeMedia', () {
      final dap = DapServer();
      dap.handleRequest({
        'seq': 1,
        'command': 'launch',
        'arguments': {'program': 'examples/video.ncl'},
      });
      dap.handleRequest({
        'seq': 2,
        'command': 'setBreakpoints',
        'arguments': {
          'source': {'path': 'examples/video.ncl'},
          'breakpoints': [{'line': 7}],
        },
      });
      dap.handleRequest({'seq': 3, 'command': 'configurationDone'});

      final tickResp1 = dap.handleRequest({
        'seq': 4,
        'command': 'tick',
        'arguments': {'incrementMs': 1500},
      });
      expect(tickResp1['success'], isTrue);
      expect(tickResp1['body']['virtualClock'], equals(1500));
      expect(tickResp1['body']['isPaused'], isFalse);

      final tickResp2 = dap.handleRequest({
        'seq': 5,
        'command': 'tick',
        'arguments': {'incrementMs': 500},
      });
      expect(tickResp2['success'], isTrue);
      expect(tickResp2['body']['virtualClock'], equals(2000));
      expect(tickResp2['body']['isPaused'], isTrue);
      expect(tickResp2['body']['currentLine'], equals(7));
      expect(dap.currentLine, equals(7));

      final evalClock = dap.handleRequest({
        'seq': 6,
        'command': 'evaluate',
        'arguments': {'expression': 'virtualClock'},
      });
      expect(evalClock['body']['result'], equals('2000ms'));

      final evalMedia = dap.handleRequest({
        'seq': 7,
        'command': 'evaluate',
        'arguments': {'expression': 'activeMedia'},
      });
      expect(evalMedia['body']['result'], contains('green_bg'));
    });
  });
}
