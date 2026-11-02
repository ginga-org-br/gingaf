import 'package:ncldoc/schema.dart';
import 'package:xml/xml.dart';
import 'json_rpc.dart';

class Position {
  final int line;
  final int character;

  const Position({required this.line, required this.character});

  Map<String, dynamic> toJson() => {'line': line, 'character': character};

  factory Position.fromJson(Map<String, dynamic> json) => Position(
        line: json['line'] as int,
        character: json['character'] as int,
      );
}

class Range {
  final Position start;
  final Position end;

  const Range({required this.start, required this.end});

  Map<String, dynamic> toJson() =>
      {'start': start.toJson(), 'end': end.toJson()};

  factory Range.fromJson(Map<String, dynamic> json) => Range(
        start: Position.fromJson(json['start'] as Map<String, dynamic>),
        end: Position.fromJson(json['end'] as Map<String, dynamic>),
      );
}

class Diagnostic {
  final Range range;
  final int severity;
  final String message;
  final String source;

  const Diagnostic({
    required this.range,
    required this.severity,
    required this.message,
    this.source = 'ginga-ncl',
  });

  Map<String, dynamic> toJson() => {
        'range': range.toJson(),
        'severity': severity,
        'message': message,
        'source': source,
      };
}

class CompletionItem {
  final String label;
  final int kind;
  final String? detail;
  final String? documentation;
  final String? insertText;
  final int? insertTextFormat;

  const CompletionItem({
    required this.label,
    this.kind = 1,
    this.detail,
    this.documentation,
    this.insertText,
    this.insertTextFormat,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'kind': kind,
        if (detail != null) 'detail': detail,
        if (documentation != null) 'documentation': documentation,
        if (insertText != null) 'insertText': insertText,
        if (insertTextFormat != null) 'insertTextFormat': insertTextFormat,
      };
}

class DocumentSymbol {
  final String name;
  final String? detail;
  final int kind;
  final Range range;
  final Range selectionRange;
  final List<DocumentSymbol> children;

  const DocumentSymbol({
    required this.name,
    this.detail,
    required this.kind,
    required this.range,
    required this.selectionRange,
    this.children = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (detail != null) 'detail': detail,
        'kind': kind,
        'range': range.toJson(),
        'selectionRange': selectionRange.toJson(),
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };

  factory DocumentSymbol.fromJson(Map<String, dynamic> json) => DocumentSymbol(
        name: json['name'] as String,
        detail: json['detail'] as String?,
        kind: json['kind'] as int,
        range: Range.fromJson(json['range'] as Map<String, dynamic>),
        selectionRange:
            Range.fromJson(json['selectionRange'] as Map<String, dynamic>),
        children: (json['children'] as List<dynamic>?)
                ?.map((c) => DocumentSymbol.fromJson(c as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class LspServer {
  final Map<String, String> _documents = {};
  void Function(JsonRpcNotification notification)? onNotification;

  Map<String, String> get documents => Map.unmodifiable(_documents);

  JsonRpcResponse? handleRequest(JsonRpcRequest request) {
    switch (request.method) {
      case 'initialize':
        return _handleInitialize(request);
      case 'shutdown':
        return JsonRpcResponse(id: request.id, result: null);
      case 'textDocument/completion':
        return _handleCompletion(request);
      case 'textDocument/hover':
        return _handleHover(request);
      case 'textDocument/definition':
        return _handleDefinition(request);
      case 'textDocument/documentSymbol':
        return _handleDocumentSymbol(request);
      default:
        return JsonRpcResponse(
          id: request.id,
          error: JsonRpcError(
            code: -32601,
            message: 'Method not found: ${request.method}',
          ),
        );
    }
  }

  void handleNotification(JsonRpcNotification notification) {
    switch (notification.method) {
      case 'textDocument/didOpen':
        final params = notification.params as Map<String, dynamic>?;
        final textDocument = params?['textDocument'] as Map<String, dynamic>?;
        if (textDocument != null) {
          final uri = textDocument['uri'] as String;
          final text = textDocument['text'] as String;
          _documents[uri] = text;
          _validateAndPublish(uri, text);
        }
        break;
      case 'textDocument/didChange':
        final params = notification.params as Map<String, dynamic>?;
        final textDocument = params?['textDocument'] as Map<String, dynamic>?;
        final contentChanges =
            params?['contentChanges'] as List<dynamic>?;
        if (textDocument != null &&
            contentChanges != null &&
            contentChanges.isNotEmpty) {
          final uri = textDocument['uri'] as String;
          final lastChange = contentChanges.last as Map<String, dynamic>;
          final text = lastChange['text'] as String;
          _documents[uri] = text;
          _validateAndPublish(uri, text);
        }
        break;
      case 'textDocument/didClose':
        final params = notification.params as Map<String, dynamic>?;
        final textDocument = params?['textDocument'] as Map<String, dynamic>?;
        if (textDocument != null) {
          final uri = textDocument['uri'] as String;
          _documents.remove(uri);
        }
        break;
    }
  }

  JsonRpcResponse _handleInitialize(JsonRpcRequest request) {
    return JsonRpcResponse(
      id: request.id,
      result: {
        'capabilities': {
          'textDocumentSync': 1,
          'completionProvider': {
            'resolveProvider': false,
            'triggerCharacters': ['<', ' ', '"', ':'],
          },
          'hoverProvider': true,
          'definitionProvider': true,
          'documentSymbolProvider': true,
        },
        'serverInfo': {
          'name': 'ginga-lsp',
          'version': '0.1.0',
        },
      },
    );
  }

  void _validateAndPublish(String uri, String text) {
    final diagnostics = validateDocument(text);
    final notification = JsonRpcNotification(
      method: 'textDocument/publishDiagnostics',
      params: {
        'uri': uri,
        'diagnostics': diagnostics.map((d) => d.toJson()).toList(),
      },
    );
    onNotification?.call(notification);
  }

  List<Diagnostic> validateDocument(String text) {
    final diagnostics = <Diagnostic>[];
    if (text.trim().isEmpty) return diagnostics;

    XmlDocument parsed;
    try {
      parsed = XmlDocument.parse(text);
    } catch (e) {
      final msg = e.toString();
      final lineMatch = RegExp(r'line (\d+)').firstMatch(msg);
      final colMatch = RegExp(r'column (\d+)').firstMatch(msg);
      final line = lineMatch != null ? int.parse(lineMatch.group(1)!) - 1 : 0;
      final col = colMatch != null ? int.parse(colMatch.group(1)!) - 1 : 0;

      diagnostics.add(
        Diagnostic(
          range: Range(
            start: Position(line: line < 0 ? 0 : line, character: col < 0 ? 0 : col),
            end: Position(line: line < 0 ? 0 : line, character: (col < 0 ? 0 : col) + 10),
          ),
          severity: 1,
          message: 'XML syntax error: $msg',
        ),
      );
      return diagnostics;
    }

    _validateElement(parsed.rootElement, null, text, diagnostics);
    return diagnostics;
  }

  void _validateElement(
    XmlElement element,
    String? parentTag,
    String fullText,
    List<Diagnostic> diagnostics,
  ) {
    final tagName = element.name.local;
    final elementSyntax = _findElementSyntax(tagName);

    if (elementSyntax == null) {
      if (tagName != 'xml') {
        diagnostics.add(
          Diagnostic(
            range: _findRangeForTag(element, fullText),
            severity: 2,
            message: "Unknown NCL element '<$tagName>'",
          ),
        );
      }
    } else {
      if (parentTag != null &&
          elementSyntax.possibleParents.isNotEmpty &&
          !elementSyntax.possibleParents.contains(parentTag)) {
        diagnostics.add(
          Diagnostic(
            range: _findRangeForTag(element, fullText),
            severity: 2,
            message:
                "Element '<$tagName>' cannot be a child of '<$parentTag>'. Allowed parents: ${elementSyntax.possibleParents.join(', ')}",
          ),
        );
      }

      for (final attr in element.attributes) {
        final attrName = attr.name.local;
        if (!elementSyntax.attributes.containsKey(attrName)) {
          diagnostics.add(
            Diagnostic(
              range: _findRangeForTag(element, fullText),
              severity: 2,
              message: "Unknown attribute '$attrName' on '<$tagName>'",
            ),
          );
        }
      }

      for (final entry in elementSyntax.attributes.entries) {
        final attrName = entry.key;
        final rule = entry.value;
        if (rule == attrRequired ||
            rule == attrRequiredNonemptyName ||
            rule == attrId) {
          if (element.getAttribute(attrName) == null) {
            diagnostics.add(
              Diagnostic(
                range: _findRangeForTag(element, fullText),
                severity: 1,
                message: "Missing required attribute '$attrName' on '<$tagName>'",
              ),
            );
          }
        }
      }
    }

    for (final child in element.children.whereType<XmlElement>()) {
      _validateElement(child, tagName, fullText, diagnostics);
    }
  }

  ElementSyntax? _findElementSyntax(String tagName) {
    switch (tagName) {
      case 'ncl':
        return const ElementSyntax(possibleParents: [], attributes: {
          'id': attrOptId,
          'title': attrOptional,
          'xmlns': attrOptional,
        });
      case 'head':
        return const ElementSyntax(possibleParents: ['ncl']);
      case 'body':
        return const ElementSyntax(possibleParents: ['ncl'], attributes: {'id': attrOptId});
      case 'regionBase':
        return const ElementSyntax(possibleParents: ['head'], attributes: {
          'id': attrOptId,
          'device': attrOptional,
          'region': attrOptional,
        });
      case 'region':
        return const ElementSyntax(possibleParents: ['regionBase', 'region'], attributes: {
          'id': attrId,
          'title': attrOptional,
          'left': attrOptional,
          'right': attrOptional,
          'top': attrOptional,
          'bottom': attrOptional,
          'height': attrOptional,
          'width': attrOptional,
          'zIndex': attrOptional,
        });
      case 'descriptorBase':
        return const ElementSyntax(possibleParents: ['head'], attributes: {'id': attrOptId});
      case 'descriptor':
        return const ElementSyntax(possibleParents: ['descriptorBase'], attributes: {
          'id': attrId,
          'region': attrOptIdref,
          'player': attrOptional,
          'explicitDur': attrOptional,
        });
      case 'connectorBase':
        return const ElementSyntax(possibleParents: ['head'], attributes: {'id': attrOptId});
      case 'importBase':
        return const ElementSyntax(
          possibleParents: ['connectorBase', 'descriptorBase', 'regionBase', 'ruleBase', 'transitionBase'],
          attributes: {
            'documentURI': attrRequired,
            'alias': attrRequired,
            'id': attrOptId,
          },
        );
      case 'causalConnector':
        return const ElementSyntax(possibleParents: ['connectorBase'], attributes: {
          'id': attrId,
          'title': attrOptional,
        });
      case 'media':
        return const ElementSyntax(possibleParents: ['body', 'context'], attributes: {
          'id': attrId,
          'src': attrRequired,
          'type': attrOptional,
          'descriptor': attrOptIdref,
          'refer': attrOptIdref,
          'instance': attrOptional,
        });
      case 'context':
        return const ElementSyntax(possibleParents: ['body', 'context'], attributes: {
          'id': attrId,
          'refer': attrOptIdref,
        });
      case 'port':
        return const ElementSyntax(possibleParents: ['body', 'context'], attributes: {
          'id': attrId,
          'component': attrIdref,
          'interface': attrOptIdref,
        });
      case 'property':
        return const ElementSyntax(possibleParents: ['media', 'context'], attributes: {
          'name': attrRequiredNonemptyName,
          'value': attrOptional,
        });
      case 'area':
        return const ElementSyntax(possibleParents: ['media'], attributes: {
          'id': attrId,
          'begin': attrOptional,
          'end': attrOptional,
        });
      case 'link':
        return const ElementSyntax(possibleParents: ['body', 'context'], attributes: {
          'id': attrOptId,
          'xconnector': attrIdref,
        });
      case 'bind':
        return const ElementSyntax(possibleParents: ['link'], attributes: {
          'role': attrRequired,
          'component': attrIdref,
          'interface': attrOptIdref,
        });
      case 'bindParam':
        return const ElementSyntax(possibleParents: ['bind', 'link'], attributes: {
          'name': attrRequiredNonemptyName,
          'value': attrRequired,
        });
      default:
        return null;
    }
  }

  Range _findRangeForTag(XmlElement element, String fullText) {
    final lines = fullText.split('\n');
    final tagToSearch = '<${element.name.local}';
    for (int i = 0; i < lines.length; i++) {
      final idx = lines[i].indexOf(tagToSearch);
      if (idx != -1) {
        return Range(
          start: Position(line: i, character: idx),
          end: Position(line: i, character: idx + tagToSearch.length),
        );
      }
    }
    return const Range(
      start: Position(line: 0, character: 0),
      end: Position(line: 0, character: 5),
    );
  }

  JsonRpcResponse _handleCompletion(JsonRpcRequest request) {
    final params = request.params as Map<String, dynamic>?;
    final textDocument = params?['textDocument'] as Map<String, dynamic>?;
    final positionMap = params?['position'] as Map<String, dynamic>?;

    final uri = textDocument?['uri'] as String?;
    final line = positionMap?['line'] as int? ?? 0;
    final character = positionMap?['character'] as int? ?? 0;

    final items = <CompletionItem>[];
    final text = uri != null ? _documents[uri] ?? '' : '';

    final lines = text.split('\n');
    final currentLine = line < lines.length ? lines[line] : '';
    final prefix = character <= currentLine.length
        ? currentLine.substring(0, character)
        : currentLine;

    if (prefix.trimRight().endsWith('<') || prefix.trimRight().endsWith('</')) {
      final tags = [
        'ncl',
        'head',
        'body',
        'regionBase',
        'region',
        'descriptorBase',
        'descriptor',
        'connectorBase',
        'causalConnector',
        'media',
        'context',
        'port',
        'property',
        'area',
        'link',
        'bind',
      ];
      for (final t in tags) {
        items.add(
          CompletionItem(
            label: t,
            kind: 7,
            detail: 'NCL Element',
            insertText: t,
          ),
        );
      }
    } else {
      final tagMatch = RegExp(r'<([a-zA-Z0-9]+)\s+[^>]*$').firstMatch(prefix);
      if (tagMatch != null) {
        final tagName = tagMatch.group(1)!;
        final syntax = _findElementSyntax(tagName);
        if (syntax != null) {
          for (final attr in syntax.attributes.keys) {
            items.add(
              CompletionItem(
                label: attr,
                kind: 10,
                detail: 'NCL Attribute',
                insertText: '$attr="\$1"',
                insertTextFormat: 2,
              ),
            );
          }
        }
      } else {
        items.addAll([
          const CompletionItem(
            label: 'ncl-doc',
            kind: 15,
            detail: 'NCL Document Template',
            insertText:
                '<?xml version="1.0" encoding="ISO-8859-1"?>\n<ncl id="main" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">\n  <head>\n    <regionBase>\n      <region id="rg_main" width="100%" height="100%"/>\n    </regionBase>\n    <descriptorBase>\n      <descriptor id="ds_main" region="rg_main"/>\n    </descriptorBase>\n  </head>\n  <body id="body">\n    <port id="p_entry" component="m_main"/>\n    <media id="m_main" src="main.mp4" descriptor="ds_main"/>\n  </body>\n</ncl>',
          ),
          const CompletionItem(
            label: 'media',
            kind: 7,
            detail: 'NCL Media Element',
            insertText: '<media id="\$1" src="\$2" descriptor="\$3"/>',
            insertTextFormat: 2,
          ),
          const CompletionItem(
            label: 'link',
            kind: 7,
            detail: 'NCL Link Element',
            insertText:
                '<link xconnector="\$1">\n  <bind role="onBegin" component="\$2"/>\n  <bind role="start" component="\$3"/>\n</link>',
            insertTextFormat: 2,
          ),
        ]);
      }
    }

    return JsonRpcResponse(
      id: request.id,
      result: {'isIncomplete': false, 'items': items.map((i) => i.toJson()).toList()},
    );
  }

  JsonRpcResponse _handleHover(JsonRpcRequest request) {
    final params = request.params as Map<String, dynamic>?;
    final textDocument = params?['textDocument'] as Map<String, dynamic>?;
    final positionMap = params?['position'] as Map<String, dynamic>?;

    final uri = textDocument?['uri'] as String?;
    final line = positionMap?['line'] as int? ?? 0;
    final character = positionMap?['character'] as int? ?? 0;

    final text = uri != null ? _documents[uri] ?? '' : '';
    final lines = text.split('\n');
    final currentLine = line < lines.length ? lines[line] : '';

    final word = _extractWordAt(currentLine, character);
    if (word.isEmpty) {
      return JsonRpcResponse(id: request.id, result: null);
    }

    final syntax = _findElementSyntax(word);
    if (syntax != null) {
      final allowedParents = syntax.possibleParents.isEmpty
          ? 'Root Element'
          : syntax.possibleParents.join(', ');
      final attrs = syntax.attributes.keys.join(', ');
      final docs =
          '**NCL Element: `<$word>`**\n\n- **Allowed Parents**: $allowedParents\n- **Attributes**: $attrs\n';
      return JsonRpcResponse(
        id: request.id,
        result: {
          'contents': {'kind': 'markdown', 'value': docs},
        },
      );
    }

    return JsonRpcResponse(
      id: request.id,
      result: {
        'contents': {'kind': 'markdown', 'value': '**$word** (NCL Token)'},
      },
    );
  }

  JsonRpcResponse _handleDefinition(JsonRpcRequest request) {
    final params = request.params as Map<String, dynamic>?;
    final textDocument = params?['textDocument'] as Map<String, dynamic>?;
    final positionMap = params?['position'] as Map<String, dynamic>?;

    final uri = textDocument?['uri'] as String?;
    final line = positionMap?['line'] as int? ?? 0;
    final character = positionMap?['character'] as int? ?? 0;

    final text = uri != null ? _documents[uri] ?? '' : '';
    final lines = text.split('\n');
    final currentLine = line < lines.length ? lines[line] : '';

    final targetId = _extractWordAt(currentLine, character);
    if (targetId.isEmpty) {
      return JsonRpcResponse(id: request.id, result: null);
    }

    for (int i = 0; i < lines.length; i++) {
      final l = lines[i];
      final idPattern = RegExp('id=["\']${RegExp.escape(targetId)}["\']');
      final match = idPattern.firstMatch(l);
      if (match != null) {
        return JsonRpcResponse(
          id: request.id,
          result: {
            'uri': uri,
            'range': Range(
              start: Position(line: i, character: match.start),
              end: Position(line: i, character: match.end),
            ).toJson(),
          },
        );
      }
    }

    return JsonRpcResponse(id: request.id, result: null);
  }

  String _extractWordAt(String line, int character) {
    if (line.isEmpty || character < 0 || character > line.length) return '';
    int start = character;
    while (start > 0 && RegExp(r'[a-zA-Z0-9_-]').hasMatch(line[start - 1])) {
      start--;
    }
    int end = character;
    while (end < line.length && RegExp(r'[a-zA-Z0-9_-]').hasMatch(line[end])) {
      end++;
    }
    return line.substring(start, end);
  }

  JsonRpcResponse _handleDocumentSymbol(JsonRpcRequest request) {
    final params = request.params as Map<String, dynamic>?;
    final textDocument = params?['textDocument'] as Map<String, dynamic>?;
    final uri = textDocument?['uri'] as String?;

    if (uri == null || !_documents.containsKey(uri)) {
      return JsonRpcResponse(id: request.id, result: <dynamic>[]);
    }

    final text = _documents[uri]!;
    final symbols = getDocumentSymbols(text);
    return JsonRpcResponse(
      id: request.id,
      result: symbols.map((s) => s.toJson()).toList(),
    );
  }

  List<DocumentSymbol> getDocumentSymbols(String text) {
    if (text.trim().isEmpty) return <DocumentSymbol>[];

    XmlDocument parsed;
    try {
      parsed = XmlDocument.parse(text);
    } catch (_) {
      return <DocumentSymbol>[];
    }

    final lines = text.split('\n');
    int currentSearchLine = 0;

    DocumentSymbol? buildElementSymbol(XmlElement element) {
      final tagName = element.name.local;
      final id = element.getAttribute('id');
      final tagPrefix = '<$tagName';

      int startLine = -1;
      int startCol = -1;

      for (int i = currentSearchLine; i < lines.length; i++) {
        final line = lines[i];
        int idx = line.indexOf(tagPrefix);
        while (idx != -1) {
          final nextCharIndex = idx + tagPrefix.length;
          final isDelim = nextCharIndex >= line.length ||
              line[nextCharIndex] == ' ' ||
              line[nextCharIndex] == '\t' ||
              line[nextCharIndex] == '>' ||
              line[nextCharIndex] == '/';
          if (isDelim) {
            if (id != null && !line.contains(id)) {
              final idMatch = RegExp(r'id=["\x27]([^"\x27]+)["\x27]')
                  .firstMatch(line.substring(idx));
              if (idMatch != null && idMatch.group(1) != id) {
                idx = line.indexOf(tagPrefix, idx + 1);
                continue;
              }
            }
            startLine = i;
            startCol = idx;
            break;
          }
          idx = line.indexOf(tagPrefix, idx + 1);
        }
        if (startLine != -1) break;
      }

      if (startLine == -1) {
        startLine =
            currentSearchLine < lines.length ? currentSearchLine : lines.length - 1;
        startCol = 0;
      }

      currentSearchLine = startLine;

      final children = <DocumentSymbol>[];
      for (final child in element.children.whereType<XmlElement>()) {
        final childSymbol = buildElementSymbol(child);
        if (childSymbol != null) {
          children.add(childSymbol);
        }
      }

      int endLine = startLine;
      int endCol = lines[startLine].length;

      if (children.isNotEmpty) {
        endLine = children.last.range.end.line;
        endCol = children.last.range.end.character;
        final closeTag = '</$tagName>';
        for (int i = endLine; i < lines.length; i++) {
          final idx = lines[i].indexOf(closeTag);
          if (idx != -1) {
            endLine = i;
            endCol = idx + closeTag.length;
            break;
          }
        }
      } else {
        final closeTag = '</$tagName>';
        for (int i = startLine; i < lines.length; i++) {
          final line = lines[i];
          final closeIdx = line.indexOf(closeTag);
          final selfCloseIdx = line.indexOf('/>');
          if (closeIdx != -1) {
            endLine = i;
            endCol = closeIdx + closeTag.length;
            break;
          } else if (selfCloseIdx != -1) {
            endLine = i;
            endCol = selfCloseIdx + 2;
            break;
          } else if (line.contains('>')) {
            endLine = i;
            endCol = line.indexOf('>') + 1;
            break;
          }
        }
      }

      currentSearchLine = endLine;

      final name = id != null && id.isNotEmpty ? id : tagName;
      final detail = id != null && id.isNotEmpty
          ? '<$tagName>'
          : (element.getAttribute('refer') != null
              ? 'refer: ${element.getAttribute("refer")}'
              : (element.getAttribute('name') != null
                  ? 'name: ${element.getAttribute("name")}'
                  : null));

      return DocumentSymbol(
        name: name,
        detail: detail,
        kind: _symbolKindForTag(tagName),
        range: Range(
          start: Position(line: startLine, character: startCol),
          end: Position(line: endLine, character: endCol),
        ),
        selectionRange: Range(
          start: Position(line: startLine, character: startCol),
          end: Position(line: startLine, character: startCol + tagPrefix.length),
        ),
        children: children,
      );
    }

    final rootSymbol = buildElementSymbol(parsed.rootElement);
    return rootSymbol != null ? [rootSymbol] : <DocumentSymbol>[];
  }

  int _symbolKindForTag(String tagName) {
    switch (tagName) {
      case 'ncl':
        return 2;
      case 'head':
        return 3;
      case 'ruleBase':
      case 'connectorBase':
      case 'transitionBase':
        return 4;
      case 'body':
        return 5;
      case 'bind':
      case 'bindRule':
      case 'bindParam':
        return 6;
      case 'descriptor':
      case 'property':
      case 'area':
        return 7;
      case 'region':
        return 8;
      case 'descriptorBase':
      case 'regionBase':
        return 11;
      case 'link':
        return 12;
      case 'media':
      case 'context':
        return 13;
      case 'param':
      case 'attribute':
        return 14;
      case 'port':
      case 'causalConnector':
      case 'simpleCondition':
      case 'compoundCondition':
      case 'simpleAction':
      case 'compoundAction':
        return 24;
      default:
        return 19;
    }
  }
}

