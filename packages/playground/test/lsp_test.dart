import 'package:playground/playground.dart';
import 'package:test/test.dart';

void main() {
  group('LspServer', () {
    late LspServer server;

    setUp(() {
      server = LspServer();
    });

    test('initializes and reports capabilities', () {
      final req = JsonRpcRequest(id: 1, method: 'initialize', params: {});
      final resp = server.handleRequest(req);

      expect(resp?.result, isNotNull);
      final caps = resp!.result['capabilities'] as Map<String, dynamic>;
      expect(caps['textDocumentSync'], equals(1));
      expect(caps['hoverProvider'], isTrue);
      expect(caps['definitionProvider'], isTrue);
    });

    test('validates valid NCL document without errors', () {
      const validNcl = '''<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="main">
  <head>
    <regionBase>
      <region id="rg1" width="100%" height="100%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="ds1" region="rg1"/>
    </descriptorBase>
  </head>
  <body id="body">
    <port id="p1" component="m1"/>
    <media id="m1" src="video.mp4" descriptor="ds1"/>
  </body>
</ncl>''';

      final diagnostics = server.validateDocument(validNcl);
      expect(diagnostics, isEmpty);
    });

    test('detects XML syntax errors', () {
      const invalidXml = '<ncl id="main"><head></ncl>';
      final diagnostics = server.validateDocument(invalidXml);

      expect(diagnostics, isNotEmpty);
      expect(diagnostics.first.severity, equals(1));
      expect(diagnostics.first.message, contains('XML syntax error'));
    });

    test('detects unknown NCL elements and missing attributes', () {
      const invalidNcl = '''<ncl id="main">
  <head>
    <invalidTag/>
  </head>
  <body>
    <media/>
  </body>
</ncl>''';

      final diagnostics = server.validateDocument(invalidNcl);
      expect(diagnostics.any((d) => d.message.contains('Unknown NCL element')), isTrue);
      expect(diagnostics.any((d) => d.message.contains("Missing required attribute 'id'")), isTrue);
      expect(diagnostics.any((d) => d.message.contains("Missing required attribute 'src'")), isTrue);
    });

    test('handles document synchronization and publishes diagnostics', () {
      List<dynamic>? published;
      server.onNotification = (notif) {
        if (notif.method == 'textDocument/publishDiagnostics') {
          published = notif.params['diagnostics'] as List<dynamic>;
        }
      };

      server.handleNotification(
        JsonRpcNotification(
          method: 'textDocument/didOpen',
          params: {
            'textDocument': {
              'uri': 'file:///test.ncl',
              'text': '<ncl id="test"><head/></ncl>',
            }
          },
        ),
      );

      expect(server.documents.containsKey('file:///test.ncl'), isTrue);
      expect(published, isNotNull);
    });

    test('provides tag and attribute completions', () {
      server.handleNotification(
        JsonRpcNotification(
          method: 'textDocument/didOpen',
          params: {
            'textDocument': {
              'uri': 'file:///test.ncl',
              'text': '<ncl id="test"><media ',
            }
          },
        ),
      );

      final resp = server.handleRequest(
        JsonRpcRequest(
          id: 2,
          method: 'textDocument/completion',
          params: {
            'textDocument': {'uri': 'file:///test.ncl'},
            'position': {'line': 0, 'character': 22},
          },
        ),
      );

      expect(resp?.result, isNotNull);
      final items = (resp!.result['items'] as List<dynamic>)
          .map((i) => i['label'] as String)
          .toList();
      expect(items, contains('src'));
      expect(items, contains('descriptor'));
    });

    test('provides hover documentation for elements', () {
      server.handleNotification(
        JsonRpcNotification(
          method: 'textDocument/didOpen',
          params: {
            'textDocument': {
              'uri': 'file:///test.ncl',
              'text': '<media id="m1" src="a.mp4"/>',
            }
          },
        ),
      );

      final resp = server.handleRequest(
        JsonRpcRequest(
          id: 3,
          method: 'textDocument/hover',
          params: {
            'textDocument': {'uri': 'file:///test.ncl'},
            'position': {'line': 0, 'character': 3},
          },
        ),
      );

      expect(resp?.result, isNotNull);
      final contents = resp!.result['contents']['value'] as String;
      expect(contents, contains('NCL Element: `<media>`'));
    });

    test('navigates to element definition by ID', () {
      server.handleNotification(
        JsonRpcNotification(
          method: 'textDocument/didOpen',
          params: {
            'textDocument': {
              'uri': 'file:///test.ncl',
              'text': '<descriptor id="ds1"/>\n<media id="m1" descriptor="ds1"/>',
            }
          },
        ),
      );

      final resp = server.handleRequest(
        JsonRpcRequest(
          id: 4,
          method: 'textDocument/definition',
          params: {
            'textDocument': {'uri': 'file:///test.ncl'},
            'position': {'line': 1, 'character': 28},
          },
        ),
      );

      expect(resp?.result, isNotNull);
      final range = resp!.result['range'] as Map<String, dynamic>;
      expect(range['start']['line'], equals(0));
    });

    test('extracts hierarchical document symbols for NCL document structure', () {
      const nclContent = '''<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="app">
  <head>
    <regionBase>
      <region id="rgScreen" width="100%" height="100%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="descMain" region="rgScreen"/>
    </descriptorBase>
  </head>
  <body id="mainBody">
    <port id="pStart" component="media1"/>
    <media id="media1" src="video.mp4" descriptor="descMain"/>
    <link id="l1" xconnector="onBeginStart">
      <bind component="media1" role="onBegin"/>
    </link>
  </body>
</ncl>''';

      server.handleNotification(
        JsonRpcNotification(
          method: 'textDocument/didOpen',
          params: {
            'textDocument': {
              'uri': 'file:///symbols.ncl',
              'text': nclContent,
            }
          },
        ),
      );

      final resp = server.handleRequest(
        JsonRpcRequest(
          id: 5,
          method: 'textDocument/documentSymbol',
          params: {
            'textDocument': {'uri': 'file:///symbols.ncl'},
          },
        ),
      );

      expect(resp?.result, isNotNull);
      final symbols = resp!.result as List<dynamic>;
      expect(symbols.length, equals(1));

      final root = symbols.first as Map<String, dynamic>;
      expect(root['name'], equals('app'));
      expect(root['detail'], equals('<ncl>'));
      expect(root['kind'], equals(2));

      final children = root['children'] as List<dynamic>;
      expect(children.length, equals(2));

      final head = children[0] as Map<String, dynamic>;
      expect(head['name'], equals('head'));
      expect(head['kind'], equals(3));

      final headChildren = head['children'] as List<dynamic>;
      expect(headChildren.length, equals(2));

      final regionBase = headChildren[0] as Map<String, dynamic>;
      expect(regionBase['name'], equals('regionBase'));
      expect(regionBase['kind'], equals(11));

      final rgScreen = (regionBase['children'] as List<dynamic>)[0] as Map<String, dynamic>;
      expect(rgScreen['name'], equals('rgScreen'));
      expect(rgScreen['detail'], equals('<region>'));
      expect(rgScreen['kind'], equals(8));

      final descBase = headChildren[1] as Map<String, dynamic>;
      expect(descBase['name'], equals('descriptorBase'));
      final descMain = (descBase['children'] as List<dynamic>)[0] as Map<String, dynamic>;
      expect(descMain['name'], equals('descMain'));
      expect(descMain['detail'], equals('<descriptor>'));
      expect(descMain['kind'], equals(7));

      final body = children[1] as Map<String, dynamic>;
      expect(body['name'], equals('mainBody'));
      expect(body['kind'], equals(5));

      final bodyChildren = body['children'] as List<dynamic>;
      expect(bodyChildren.length, equals(3));

      final port = bodyChildren[0] as Map<String, dynamic>;
      expect(port['name'], equals('pStart'));
      expect(port['kind'], equals(24));

      final media = bodyChildren[1] as Map<String, dynamic>;
      expect(media['name'], equals('media1'));
      expect(media['detail'], equals('<media>'));
      expect(media['kind'], equals(13));

      final link = bodyChildren[2] as Map<String, dynamic>;
      expect(link['name'], equals('l1'));
      expect(link['kind'], equals(12));
      final bind = (link['children'] as List<dynamic>)[0] as Map<String, dynamic>;
      expect(bind['name'], equals('bind'));
      expect(bind['kind'], equals(6));
    });

    test('returns empty symbol list for non-existent or invalid document', () {
      final resp = server.handleRequest(
        JsonRpcRequest(
          id: 6,
          method: 'textDocument/documentSymbol',
          params: {
            'textDocument': {'uri': 'file:///nonexistent.ncl'},
          },
        ),
      );
      expect(resp?.result, isNotNull);
      expect(resp!.result as List<dynamic>, isEmpty);
    });

    test('validates complex NCL application (video.ncl) with zero diagnostics errors', () {
      const videoNcl = '''<ncl>
  <body>
    <port id="init" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4">
      <area id="a1" begin="2s" end="4s"/>
    </media>
    <media id="green_bg">
      <property name="background" value="green"/>
      <property name="bounds" value="0%,80%,20%,20%"/>
    </media>
    <media id="red_bg">
      <property name="background" value="red"/>
      <property name="bounds" value="80%,80%,20%,20%"/>
      <property name="explicitDur" value="2s"/>
    </media>
    <link id="l1">
      <bind role="onBegin" component="video" interface="a1"/>
      <bind role="start" component="green_bg"/>
    </link>
    <link id="l2">
      <bind role="onEnd" component="video" interface="a1"/>
      <bind role="stop" component="green_bg"/>
      <bind role="start" component="red_bg"/>
    </link>
  </body>
</ncl>''';

      final diagnostics = server.validateDocument(videoNcl);
      expect(diagnostics.length, equals(2));
      expect(diagnostics.every((d) => d.message.contains("Missing required attribute 'src' on '<media>'")), isTrue);

      final fullNcl = videoNcl
          .replaceAll('<media id="green_bg">', '<media id="green_bg" src="">')
          .replaceAll('<media id="red_bg">', '<media id="red_bg" src="">');
      expect(server.validateDocument(fullNcl), isEmpty);

      final symbols = server.getDocumentSymbols(videoNcl);
      expect(symbols.length, equals(1));
      expect(symbols.first.children.length, equals(1));
      final bodyChildren = symbols.first.children.first.children;
      expect(bodyChildren.any((s) => s.name == 'video'), isTrue);
      expect(bodyChildren.any((s) => s.name == 'green_bg'), isTrue);
      expect(bodyChildren.any((s) => s.name == 'red_bg'), isTrue);
      expect(bodyChildren.any((s) => s.name == 'l1'), isTrue);
      expect(bodyChildren.any((s) => s.name == 'l2'), isTrue);
    });

    test('provides tag completions for head and body', () {
      server.handleNotification(
        JsonRpcNotification(
          method: 'textDocument/didOpen',
          params: {
            'textDocument': {
              'uri': 'file:///context_completion.ncl',
              'text': '<ncl><head><</head><body><</body></ncl>',
            }
          },
        ),
      );

      final headResp = server.handleRequest(
        JsonRpcRequest(
          id: 10,
          method: 'textDocument/completion',
          params: {
            'textDocument': {'uri': 'file:///context_completion.ncl'},
            'position': {'line': 0, 'character': 12},
          },
        ),
      );
      expect(headResp?.result, isNotNull);
      final headItems = (headResp!.result['items'] as List<dynamic>).map((i) => i['label'] as String).toList();
      expect(headItems, contains('regionBase'));
      expect(headItems, contains('descriptorBase'));

      final bodyResp = server.handleRequest(
        JsonRpcRequest(
          id: 11,
          method: 'textDocument/completion',
          params: {
            'textDocument': {'uri': 'file:///context_completion.ncl'},
            'position': {'line': 0, 'character': 26},
          },
        ),
      );
      expect(bodyResp?.result, isNotNull);
      final bodyItems = (bodyResp!.result['items'] as List<dynamic>).map((i) => i['label'] as String).toList();
      expect(bodyItems, contains('port'));
      expect(bodyItems, contains('media'));
      expect(bodyItems, contains('link'));
    });

    test('provides attribute completions for region and descriptor', () {
      server.handleNotification(
        JsonRpcNotification(
          method: 'textDocument/didOpen',
          params: {
            'textDocument': {
              'uri': 'file:///attr_completion.ncl',
              'text': '<ncl><head><regionBase><region </regionBase><descriptorBase><descriptor </descriptorBase></head></ncl>',
            }
          },
        ),
      );

      final regionResp = server.handleRequest(
        JsonRpcRequest(
          id: 12,
          method: 'textDocument/completion',
          params: {
            'textDocument': {'uri': 'file:///attr_completion.ncl'},
            'position': {'line': 0, 'character': 31},
          },
        ),
      );
      expect(regionResp?.result, isNotNull);
      final regionItems = (regionResp!.result['items'] as List<dynamic>).map((i) => i['label'] as String).toList();
      expect(regionItems, contains('id'));
      expect(regionItems, contains('width'));
      expect(regionItems, contains('height'));

      final descResp = server.handleRequest(
        JsonRpcRequest(
          id: 13,
          method: 'textDocument/completion',
          params: {
            'textDocument': {'uri': 'file:///attr_completion.ncl'},
            'position': {'line': 0, 'character': 72},
          },
        ),
      );
      expect(descResp?.result, isNotNull);
      final descItems = (descResp!.result['items'] as List<dynamic>).map((i) => i['label'] as String).toList();
      expect(descItems, contains('id'));
      expect(descItems, contains('region'));
    });

    test('provides hover documentation for multiple elements', () {
      server.handleNotification(
        JsonRpcNotification(
          method: 'textDocument/didOpen',
          params: {
            'textDocument': {
              'uri': 'file:///hover_test.ncl',
              'text': '<ncl><head><regionBase><region id="r1"/></regionBase></head><body><link id="l1"/></body></ncl>',
            }
          },
        ),
      );

      final regionHover = server.handleRequest(
        JsonRpcRequest(
          id: 14,
          method: 'textDocument/hover',
          params: {
            'textDocument': {'uri': 'file:///hover_test.ncl'},
            'position': {'line': 0, 'character': 25},
          },
        ),
      );
      expect(regionHover?.result, isNotNull);
      final regionContent = regionHover!.result['contents']['value'] as String;
      expect(regionContent, contains('NCL Element: `<region>`'));

      final linkHover = server.handleRequest(
        JsonRpcRequest(
          id: 15,
          method: 'textDocument/hover',
          params: {
            'textDocument': {'uri': 'file:///hover_test.ncl'},
            'position': {'line': 0, 'character': 69},
          },
        ),
      );
      expect(linkHover?.result, isNotNull);
      final linkContent = linkHover!.result['contents']['value'] as String;
      expect(linkContent, contains('NCL Element: `<link>`'));
    });

    test('definition provider returns null when identifier has no target', () {
      server.handleNotification(
        JsonRpcNotification(
          method: 'textDocument/didOpen',
          params: {
            'textDocument': {
              'uri': 'file:///def_missing.ncl',
              'text': '<media id="m1" descriptor="missing_desc"/>',
            }
          },
        ),
      );

      final resp = server.handleRequest(
        JsonRpcRequest(
          id: 16,
          method: 'textDocument/definition',
          params: {
            'textDocument': {'uri': 'file:///def_missing.ncl'},
            'position': {'line': 0, 'character': 30},
          },
        ),
      );
      expect(resp?.result, isNull);
    });

    test('handles document synchronization updates and close', () {
      server.handleNotification(
        JsonRpcNotification(
          method: 'textDocument/didOpen',
          params: {
            'textDocument': {
              'uri': 'file:///lifecycle.ncl',
              'text': '<ncl id="v1"/>',
            }
          },
        ),
      );
      expect(server.documents['file:///lifecycle.ncl'], equals('<ncl id="v1"/>'));

      server.handleNotification(
        JsonRpcNotification(
          method: 'textDocument/didChange',
          params: {
            'textDocument': {'uri': 'file:///lifecycle.ncl'},
            'contentChanges': [
              {'text': '<ncl id="v2"/>'}
            ],
          },
        ),
      );
      expect(server.documents['file:///lifecycle.ncl'], equals('<ncl id="v2"/>'));

      server.handleNotification(
        JsonRpcNotification(
          method: 'textDocument/didClose',
          params: {
            'textDocument': {'uri': 'file:///lifecycle.ncl'},
          },
        ),
      );
      expect(server.documents.containsKey('file:///lifecycle.ncl'), isFalse);
    });

    test('handles shutdown and unknown requests', () {
      final shutdownResp = server.handleRequest(
        JsonRpcRequest(id: 98, method: 'shutdown', params: {}),
      );
      expect(shutdownResp?.result, isNull);

      final unknownResp = server.handleRequest(
        JsonRpcRequest(id: 99, method: 'unknown/method', params: {}),
      );
      expect(unknownResp?.error, isNotNull);
      expect(unknownResp!.error!.code, equals(-32601));
    });

    test('validates Primeiro Joao NCL document structure without schema errors', () {
      const joaoNcl = '''<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="primeiro_joao">
  <head>
    <regionBase>
      <region id="screenReg" width="100%" height="100%" zIndex="2">
        <region id="frameReg" left="5%" top="6.7%" width="18.5%" height="18.5%" zIndex="3"/>
      </region>
    </regionBase>
    <descriptorBase>
      <descriptor id="screenDesc" region="screenReg"/>
      <descriptor id="photoDesc" region="frameReg" explicitDur="5s"/>
      <descriptor id="audioDesc"/>
      <descriptor id="dribleDesc" region="frameReg"/>
    </descriptorBase>
    <connectorBase>
      <importBase documentURI="causalConnBase.ncl" alias="conEx"/>
    </connectorBase>
  </head>
  <body>
    <port id="entry" component="animation"/>
    <media id="animation" src="media/animGar.mp4" descriptor="screenDesc">
      <area id="segDrible" begin="12s"/>
      <area id="segPhoto" begin="41s"/>
    </media>
    <media id="choro" src="media/choro.mp4" descriptor="audioDesc"/>
    <media id="drible" src="media/drible.mp4" descriptor="dribleDesc"/>
    <media id="photo" src="media/photo.png" descriptor="photoDesc"/>
    <link id="lMusic" xconnector="conEx#onBeginStart_delay">
      <bind role="onBegin" component="animation"/>
      <bind role="start" component="choro">
        <bindParam name="delay" value="5s"/>
      </bind>
    </link>
    <link id="lDrible" xconnector="conEx#onBeginStart">
      <bind role="onBegin" component="animation" interface="segDrible"/>
      <bind role="start" component="drible"/>
    </link>
    <link id="lPhoto" xconnector="conEx#onBeginStart">
      <bind role="onBegin" component="animation" interface="segPhoto"/>
      <bind role="start" component="photo"/>
    </link>
    <link id="lEnd" xconnector="conEx#onEndStop">
      <bind role="onEnd" component="animation"/>
      <bind role="stop" component="choro"/>
    </link>
  </body>
</ncl>''';

      final diagnostics = server.validateDocument(joaoNcl);
      expect(diagnostics, isEmpty);

      final symbols = server.getDocumentSymbols(joaoNcl);
      expect(symbols.length, equals(1));
      final root = symbols.first;
      expect(root.name, equals('primeiro_joao'));

      final head = root.children.firstWhere((c) => c.name == 'head');
      final body = root.children.firstWhere((c) => c.name == 'body');
      expect(head.children.any((c) => c.name == 'regionBase'), isTrue);
      expect(head.children.any((c) => c.name == 'descriptorBase'), isTrue);
      expect(head.children.any((c) => c.name == 'connectorBase'), isTrue);

      final regionBase = head.children.firstWhere((c) => c.name == 'regionBase');
      final screenReg = regionBase.children.firstWhere((c) => c.name == 'screenReg');
      expect(screenReg.children.any((c) => c.name == 'frameReg'), isTrue);

      final descBase = head.children.firstWhere((c) => c.name == 'descriptorBase');
      expect(descBase.children.any((c) => c.name == 'screenDesc'), isTrue);
      expect(descBase.children.any((c) => c.name == 'photoDesc'), isTrue);
      expect(descBase.children.any((c) => c.name == 'audioDesc'), isTrue);
      expect(descBase.children.any((c) => c.name == 'dribleDesc'), isTrue);

      expect(body.children.any((c) => c.name == 'entry'), isTrue);
      final anim = body.children.firstWhere((c) => c.name == 'animation');
      expect(anim.children.any((c) => c.name == 'segDrible'), isTrue);
      expect(anim.children.any((c) => c.name == 'segPhoto'), isTrue);
      expect(body.children.any((c) => c.name == 'choro'), isTrue);
      expect(body.children.any((c) => c.name == 'drible'), isTrue);
      expect(body.children.any((c) => c.name == 'photo'), isTrue);
      expect(body.children.any((c) => c.name == 'lMusic'), isTrue);
      expect(body.children.any((c) => c.name == 'lDrible'), isTrue);
      expect(body.children.any((c) => c.name == 'lPhoto'), isTrue);
      expect(body.children.any((c) => c.name == 'lEnd'), isTrue);
    });

    test('navigates to definitions across Primeiro Joao elements', () {
      const joaoNcl = '''<ncl id="primeiro_joao">
  <head>
    <regionBase>
      <region id="screenReg"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="screenDesc" region="screenReg"/>
    </descriptorBase>
  </head>
  <body>
    <port id="entry" component="animation"/>
    <media id="animation" src="media/animGar.mp4" descriptor="screenDesc"/>
  </body>
</ncl>''';

      server.handleNotification(
        JsonRpcNotification(
          method: 'textDocument/didOpen',
          params: {
            'textDocument': {
              'uri': 'file:///joao_def.ncl',
              'text': joaoNcl,
            }
          },
        ),
      );

      final portDef = server.handleRequest(
        JsonRpcRequest(
          id: 50,
          method: 'textDocument/definition',
          params: {
            'textDocument': {'uri': 'file:///joao_def.ncl'},
            'position': {'line': 10, 'character': 33},
          },
        ),
      );
      expect(portDef?.result, isNotNull);
      expect(portDef!.result['range']['start']['line'], equals(11));

      final descDef = server.handleRequest(
        JsonRpcRequest(
          id: 51,
          method: 'textDocument/definition',
          params: {
            'textDocument': {'uri': 'file:///joao_def.ncl'},
            'position': {'line': 6, 'character': 42},
          },
        ),
      );
      expect(descDef?.result, isNotNull);
      expect(descDef!.result['range']['start']['line'], equals(3));
    });
  });
}
