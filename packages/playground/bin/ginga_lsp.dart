import 'dart:convert';
import 'dart:io';
import 'package:playground/playground.dart';

void main(List<String> args) {
  final mode = args.contains('--mode=dap') ? 'dap' : 'lsp';

  if (mode == 'dap') {
    _runDap();
  } else {
    _runLsp();
  }
}

void _runLsp() {
  final server = LspServer();
  final framer = MessageFramer();

  server.onNotification = (notification) {
    final payload = jsonEncode(notification.toJson());
    final framed = MessageFramer.frameMessage(payload);
    stdout.add(framed);
  };

  stdin.listen((bytes) {
    final messages = framer.appendBytes(bytes);
    for (final msg in messages) {
      try {
        final decoded = jsonDecode(msg) as Map<String, dynamic>;
        if (decoded.containsKey('method')) {
          if (decoded.containsKey('id')) {
            final request = JsonRpcRequest.fromJson(decoded);
            final response = server.handleRequest(request);
            if (response != null) {
              final payload = jsonEncode(response.toJson());
              final framed = MessageFramer.frameMessage(payload);
              stdout.add(framed);
            }
          } else {
            final notification = JsonRpcNotification.fromJson(decoded);
            server.handleNotification(notification);
          }
        }
      } catch (e) {
        stderr.writeln('LSP parse error: $e');
      }
    }
  });
}

void _runDap() {
  final server = DapServer();
  final framer = MessageFramer();

  server.onEvent = (event) {
    final payload = jsonEncode(event);
    final framed = MessageFramer.frameMessage(payload);
    stdout.add(framed);
  };

  stdin.listen((bytes) {
    final messages = framer.appendBytes(bytes);
    for (final msg in messages) {
      try {
        final decoded = jsonDecode(msg) as Map<String, dynamic>;
        if (decoded.containsKey('command')) {
          final response = server.handleRequest(decoded);
          final payload = jsonEncode(response);
          final framed = MessageFramer.frameMessage(payload);
          stdout.add(framed);
        }
      } catch (e) {
        stderr.writeln('DAP parse error: $e');
      }
    }
  });
}
