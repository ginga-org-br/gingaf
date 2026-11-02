import 'dart:convert';
import 'package:playground/playground.dart';
import 'package:test/test.dart';

void main() {
  group('JSON-RPC and Framing', () {
    test('frames and unframes single message correctly', () {
      final framer = MessageFramer();
      final body = jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize'});
      final framed = MessageFramer.frameMessage(body);

      final extracted = framer.appendBytes(framed);
      expect(extracted.length, equals(1));
      expect(extracted.first, equals(body));
    });

    test('handles fragmented bytes across multiple chunks', () {
      final framer = MessageFramer();
      final body = jsonEncode({'jsonrpc': '2.0', 'id': 42, 'result': 'ok'});
      final framed = MessageFramer.frameMessage(body);

      final chunk1 = framed.sublist(0, 10);
      final chunk2 = framed.sublist(10);

      expect(framer.appendBytes(chunk1), isEmpty);
      final result = framer.appendBytes(chunk2);
      expect(result.length, equals(1));
      expect(result.first, equals(body));
    });

    test('serializes and deserializes JsonRpcRequest', () {
      final req = JsonRpcRequest(id: 10, method: 'test', params: {'a': 1});
      final json = req.toJson();
      final parsed = JsonRpcRequest.fromJson(json);

      expect(parsed.id, equals(10));
      expect(parsed.method, equals('test'));
      expect(parsed.params['a'], equals(1));
    });

    test('serializes and deserializes JsonRpcResponse with error', () {
      final resp = JsonRpcResponse(
        id: 5,
        error: const JsonRpcError(code: -32600, message: 'Invalid Request'),
      );
      final json = resp.toJson();
      final parsed = JsonRpcResponse.fromJson(json);

      expect(parsed.id, equals(5));
      expect(parsed.error?.code, equals(-32600));
      expect(parsed.error?.message, equals('Invalid Request'));
    });
  });
}
