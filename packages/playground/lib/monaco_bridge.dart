import 'dart:async';
import 'package:ncldoc/ncl_document.dart';
import 'lsp_server.dart';
import 'dap_server.dart';
import 'json_rpc.dart';

class MonacoBridge {
  final LspServer server;
  final DapServer dap;
  final _diagnosticsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _dapEventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  MonacoBridge({LspServer? server, DapServer? dap})
      : server = server ?? LspServer(),
        dap = dap ?? DapServer() {
    this.server.onNotification = (notification) {
      if (notification.method == 'textDocument/publishDiagnostics') {
        final params = notification.params as Map<String, dynamic>;
        _diagnosticsController.add(params);
      }
    };
    this.dap.onEvent = (event) {
      _dapEventsController.add(event);
    };
  }

  Stream<Map<String, dynamic>> get diagnosticsStream =>
      _diagnosticsController.stream;

  Stream<Map<String, dynamic>> get dapEventsStream =>
      _dapEventsController.stream;

  void openDocument(String uri, String text) {
    server.handleNotification(
      JsonRpcNotification(
        method: 'textDocument/didOpen',
        params: {
          'textDocument': {
            'uri': uri,
            'languageId': 'ncl',
            'version': 1,
            'text': text,
          }
        },
      ),
    );
  }

  void updateDocument(String uri, String text, [int version = 2]) {
    server.handleNotification(
      JsonRpcNotification(
        method: 'textDocument/didChange',
        params: {
          'textDocument': {'uri': uri, 'version': version},
          'contentChanges': [
            {'text': text}
          ],
        },
      ),
    );
  }

  void closeDocument(String uri) {
    server.handleNotification(
      JsonRpcNotification(
        method: 'textDocument/didClose',
        params: {
          'textDocument': {'uri': uri}
        },
      ),
    );
  }

  List<Diagnostic> validate(String text) {
    return server.validateDocument(text);
  }

  Map<String, dynamic>? getCompletions(String uri, int line, int character) {
    final response = server.handleRequest(
      JsonRpcRequest(
        id: 1,
        method: 'textDocument/completion',
        params: {
          'textDocument': {'uri': uri},
          'position': {'line': line, 'character': character},
        },
      ),
    );
    return response?.result as Map<String, dynamic>?;
  }

  String? getHover(String uri, int line, int character) {
    final response = server.handleRequest(
      JsonRpcRequest(
        id: 2,
        method: 'textDocument/hover',
        params: {
          'textDocument': {'uri': uri},
          'position': {'line': line, 'character': character},
        },
      ),
    );
    final result = response?.result as Map<String, dynamic>?;
    final contents = result?['contents'] as Map<String, dynamic>?;
    return contents?['value'] as String?;
  }

  Map<String, dynamic>? getDefinition(String uri, int line, int character) {
    final response = server.handleRequest(
      JsonRpcRequest(
        id: 3,
        method: 'textDocument/definition',
        params: {
          'textDocument': {'uri': uri},
          'position': {'line': line, 'character': character},
        },
      ),
    );
    return response?.result as Map<String, dynamic>?;
  }

  List<Map<String, dynamic>>? getDocumentSymbols(String uri) {
    final response = server.handleRequest(
      JsonRpcRequest(
        id: 5,
        method: 'textDocument/documentSymbol',
        params: {
          'textDocument': {'uri': uri},
        },
      ),
    );
    final result = response?.result as List<dynamic>?;
    return result?.map((e) => e as Map<String, dynamic>).toList();
  }

  Media? findRelatedMedia(dynamic uriOrLine, [int? line]) {
    if (uriOrLine is int) {
      return dap.findRelatedMedia(uriOrLine);
    }
    if (uriOrLine is String && line != null) {
      final text = server.documents[uriOrLine];
      if (text == null || text.trim().isEmpty) return dap.findRelatedMedia(line);
      try {
        final doc = NclDocument.fromContent(text, docSrc: uriOrLine);
        return doc.findRelatedMedia(line);
      } catch (_) {
        return dap.findRelatedMedia(line);
      }
    }
    return null;
  }

  String? getRelatedMediaId(String uri, int line) {
    return findRelatedMedia(uri, line)?.id;
  }

  void setBreakpoints(String uri, List<int> lines) {
    dap.handleRequest({
      'seq': 1,
      'command': 'setBreakpoints',
      'arguments': {
        'source': {'path': uri},
        'breakpoints': lines.map((l) => {'line': l}).toList(),
      },
    });
  }

  List<int> getBreakpoints(String uri) => dap.getBreakpoints(uri);

  void startDebugging(String uri, [String? content]) {
    final docContent = content ?? server.documents[uri] ?? '';
    dap.nclContent = docContent;
    dap.handleRequest({
      'seq': 1,
      'command': 'launch',
      'arguments': {
        'program': uri,
        'content': docContent,
      },
    });
    dap.handleRequest({
      'seq': 2,
      'command': 'configurationDone',
    });
  }

  Set<Media> tick([int incrementMs = 100, int stepMs = 100]) {
    return dap.tick(incrementMs, stepMs);
  }

  void continueExecution({bool useTick = false, int incrementMs = 500}) {
    resume();
    dap.handleRequest({
      'seq': 3,
      'command': 'continue',
      'arguments': {'useTick': useTick, 'incrementMs': incrementMs},
    });
  }

  void step([int incrementMs = 100]) {
    if (dap.document != null) {
      dap.tick(incrementMs);
    } else {
      dap.handleRequest({'seq': 4, 'command': 'next'});
    }
  }

  void pause() {
    dap.handleRequest({'seq': 5, 'command': 'pause'});
  }

  void resume() {
    dap.resume();
  }

  void stopDebugging() {
    dap.handleRequest({'seq': 6, 'command': 'disconnect'});
  }

  bool get hasPlayer => dap.hasPlayer;
  set hasPlayer(bool val) => dap.hasPlayer = val;

  void notifyStopped(int line, [String reason = 'breakpoint']) {
    dap.notifyStopped(line, reason);
  }

  List<Media> findRelatedMediaList(int line) => dap.findRelatedMediaList(line);

  int get currentDebugLine => dap.currentLine;
  bool get isDebugging => dap.isRunning;
  bool get isPaused => dap.isPaused;
  int get virtualClock => dap.virtualClock;
  List<String> get activeMediaIds => dap.activeMediaIds;

  Map<String, dynamic>? evaluate(String expression) {
    final resp = dap.handleRequest({
      'seq': 7,
      'command': 'evaluate',
      'arguments': {'expression': expression},
    });
    return resp['body'] as Map<String, dynamic>?;
  }

  List<Map<String, dynamic>> getVariables([int variablesReference = 1000]) {
    final resp = dap.handleRequest({
      'seq': 8,
      'command': 'variables',
      'arguments': {'variablesReference': variablesReference},
    });
    final vars = resp['body']?['variables'] as List<dynamic>? ?? [];
    return vars.map((v) => v as Map<String, dynamic>).toList();
  }

  void dispose() {
    _diagnosticsController.close();
    _dapEventsController.close();
  }
}
