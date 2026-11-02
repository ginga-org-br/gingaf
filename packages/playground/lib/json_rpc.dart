import 'dart:convert';
import 'dart:typed_data';

class JsonRpcMessage {
  final String jsonrpc;

  const JsonRpcMessage({this.jsonrpc = '2.0'});
}

class JsonRpcRequest extends JsonRpcMessage {
  final dynamic id;
  final String method;
  final dynamic params;

  JsonRpcRequest({
    required this.id,
    required this.method,
    this.params,
    super.jsonrpc = '2.0',
  });

  Map<String, dynamic> toJson() => {
        'jsonrpc': jsonrpc,
        'id': id,
        'method': method,
        if (params != null) 'params': params,
      };

  factory JsonRpcRequest.fromJson(Map<String, dynamic> json) => JsonRpcRequest(
        id: json['id'],
        method: json['method'] as String,
        params: json['params'],
        jsonrpc: json['jsonrpc'] as String? ?? '2.0',
      );
}

class JsonRpcNotification extends JsonRpcMessage {
  final String method;
  final dynamic params;

  JsonRpcNotification({
    required this.method,
    this.params,
    super.jsonrpc = '2.0',
  });

  Map<String, dynamic> toJson() => {
        'jsonrpc': jsonrpc,
        'method': method,
        if (params != null) 'params': params,
      };

  factory JsonRpcNotification.fromJson(Map<String, dynamic> json) =>
      JsonRpcNotification(
        method: json['method'] as String,
        params: json['params'],
        jsonrpc: json['jsonrpc'] as String? ?? '2.0',
      );
}

class JsonRpcResponse extends JsonRpcMessage {
  final dynamic id;
  final dynamic result;
  final JsonRpcError? error;

  JsonRpcResponse({
    required this.id,
    this.result,
    this.error,
    super.jsonrpc = '2.0',
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'jsonrpc': jsonrpc,
      'id': id,
    };
    if (error != null) {
      map['error'] = error!.toJson();
    } else {
      map['result'] = result;
    }
    return map;
  }

  factory JsonRpcResponse.fromJson(Map<String, dynamic> json) =>
      JsonRpcResponse(
        id: json['id'],
        result: json['result'],
        error: json['error'] != null
            ? JsonRpcError.fromJson(json['error'] as Map<String, dynamic>)
            : null,
        jsonrpc: json['jsonrpc'] as String? ?? '2.0',
      );
}

class JsonRpcError {
  final int code;
  final String message;
  final dynamic data;

  const JsonRpcError({
    required this.code,
    required this.message,
    this.data,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      };

  factory JsonRpcError.fromJson(Map<String, dynamic> json) => JsonRpcError(
        code: json['code'] as int,
        message: json['message'] as String,
        data: json['data'],
      );
}

class MessageFramer {
  final List<int> _buffer = [];

  List<String> appendBytes(List<int> bytes) {
    _buffer.addAll(bytes);
    final messages = <String>[];

    while (true) {
      final headerEnd = _findHeaderEnd(_buffer);
      if (headerEnd == -1) break;

      final headerStr = utf8.decode(_buffer.sublist(0, headerEnd));
      final contentLength = _parseContentLength(headerStr);
      if (contentLength == null) {
        _buffer.removeRange(0, headerEnd + 4);
        continue;
      }

      final bodyStart = headerEnd + 4;
      final bodyEnd = bodyStart + contentLength;
      if (_buffer.length < bodyEnd) break;

      final bodyBytes = _buffer.sublist(bodyStart, bodyEnd);
      messages.add(utf8.decode(bodyBytes));
      _buffer.removeRange(0, bodyEnd);
    }

    return messages;
  }

  static Uint8List frameMessage(String content) {
    final bytes = utf8.encode(content);
    final header = 'Content-Length: ${bytes.length}\r\n\r\n';
    final headerBytes = utf8.encode(header);
    final builder = BytesBuilder();
    builder.add(headerBytes);
    builder.add(bytes);
    return builder.toBytes();
  }

  int _findHeaderEnd(List<int> buf) {
    for (int i = 0; i <= buf.length - 4; i++) {
      if (buf[i] == 13 &&
          buf[i + 1] == 10 &&
          buf[i + 2] == 13 &&
          buf[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  int? _parseContentLength(String header) {
    for (final line in header.split('\r\n')) {
      final parts = line.split(':');
      if (parts.length >= 2 && parts[0].trim().toLowerCase() == 'content-length') {
        return int.tryParse(parts[1].trim());
      }
    }
    return null;
  }
}
