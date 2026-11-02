import 'package:xml/xml.dart';

class NclDslTranspiler {
  static const String defaultXmlns = 'http://www.ncl.org.br/NCL3.0/EDTVProfile';

  static String xmlToDsl(String xmlText) {
    if (xmlText.trim().isEmpty) return '';
    final doc = XmlDocument.parse(xmlText);
    final root = doc.rootElement;
    final buffer = StringBuffer();
    _formatElementDsl(root, buffer, 0);
    return '${buffer.toString().trimRight()}\n';
  }

  static String dslToXml(String dslText) {
    if (dslText.trim().isEmpty) return '';
    final trimmed = dslText.trim();

    final idMatch = RegExp(r'^ncl\s+([a-zA-Z0-9_-]+)\s*\{', multiLine: true).firstMatch(trimmed);
    final rootId = idMatch != null ? idMatch.group(1)! : 'main';

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="ISO-8859-1"?>');
    buffer.writeln('<ncl id="$rootId" xmlns="$defaultXmlns">');

    final lines = dslText.split('\n');
    String? currentBlock;
    String? currentSubBlock;

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('//') || line.startsWith('#')) continue;

      if (line.startsWith('head {')) {
        currentBlock = 'head';
        buffer.writeln('  <head>');
        continue;
      } else if (line.startsWith('body') && line.contains('{')) {
        currentBlock = 'body';
        final bodyIdMatch = RegExp(r'body\s+([a-zA-Z0-9_-]+)').firstMatch(line);
        if (bodyIdMatch != null) {
          buffer.writeln('  <body id="${bodyIdMatch.group(1)}">');
        } else {
          buffer.writeln('  <body>');
        }
        continue;
      } else if (line == '}') {
        if (currentSubBlock != null) {
          buffer.writeln('    </$currentSubBlock>');
          currentSubBlock = null;
        } else if (currentBlock != null) {
          buffer.writeln('  </$currentBlock>');
          currentBlock = null;
        }
        continue;
      }

      if (currentBlock == 'head') {
        if (line.endsWith('{')) {
          final tag = line.split(RegExp(r'\s+')).first;
          currentSubBlock = tag;
          buffer.writeln('    <$tag>');
        } else {
          _convertDslStatementToXml(line, buffer, 3);
        }
      } else if (currentBlock == 'body') {
        if (line.startsWith('link') && line.endsWith('{')) {
          currentSubBlock = 'link';
          final linkIdMatch = RegExp(r'link\s+([a-zA-Z0-9_-]+)').firstMatch(line);
          final idAttr = linkIdMatch != null ? ' id="${linkIdMatch.group(1)}"' : '';
          buffer.writeln('    <link$idAttr>');
        } else if (line.startsWith('context') && line.endsWith('{')) {
          currentSubBlock = 'context';
          final ctxIdMatch = RegExp(r'context\s+([a-zA-Z0-9_-]+)').firstMatch(line);
          final idAttr = ctxIdMatch != null ? ' id="${ctxIdMatch.group(1)}"' : '';
          buffer.writeln('    <context$idAttr>');
        } else {
          _convertDslStatementToXml(line, buffer, currentSubBlock != null ? 3 : 2);
        }
      }
    }

    buffer.writeln('</ncl>');
    return buffer.toString();
  }

  static void _convertDslStatementToXml(String line, StringBuffer buffer, int indentLevel) {
    final prefix = '  ' * indentLevel;

    final portArrowMatch = RegExp(r'^port\s+([a-zA-Z0-9_-]+)\s*->\s*([a-zA-Z0-9_-]+)(?:::([a-zA-Z0-9_-]+))?').firstMatch(line);
    if (portArrowMatch != null) {
      final portId = portArrowMatch.group(1)!;
      final comp = portArrowMatch.group(2)!;
      final iface = portArrowMatch.group(3);
      final ifaceAttr = iface != null ? ' interface="$iface"' : '';
      buffer.writeln('$prefix<port id="$portId" component="$comp"$ifaceAttr/>');
      return;
    }

    final bindArrowMatch = RegExp(r'^bind\s+([a-zA-Z0-9_-]+)\s*->\s*([a-zA-Z0-9_-]+)(?:::([a-zA-Z0-9_-]+))?').firstMatch(line);
    if (bindArrowMatch != null) {
      final role = bindArrowMatch.group(1)!;
      final comp = bindArrowMatch.group(2)!;
      final iface = bindArrowMatch.group(3);
      final ifaceAttr = iface != null ? ' interface="$iface"' : '';
      buffer.writeln('$prefix<bind role="$role" component="$comp"$ifaceAttr/>');
      return;
    }

    final blockDeclMatch = RegExp(r'^([a-zA-Z0-9_-]+)(?:\s+([a-zA-Z0-9_-]+))?\s*\{([^}]*)\}').firstMatch(line);
    if (blockDeclMatch != null) {
      final tag = blockDeclMatch.group(1)!;
      final id = blockDeclMatch.group(2);
      final attrsStr = blockDeclMatch.group(3)!;

      final attrMap = _parseDslAttributes(attrsStr);
      if (id != null) {
        attrMap['id'] = id;
      }

      final attrString = attrMap.entries.map((e) => '${e.key}="${e.value}"').join(' ');
      final space = attrString.isNotEmpty ? ' $attrString' : '';
      buffer.writeln('$prefix<$tag$space/>');
      return;
    }

    final propMatch = RegExp(r'^([a-zA-Z0-9_-]+)\s*:\s*(.+)$').firstMatch(line);
    if (propMatch != null) {
      final key = propMatch.group(1)!;
      var val = propMatch.group(2)!.trim();
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.substring(1, val.length - 1);
      }
      buffer.writeln('$prefix<$key value="$val"/>');
    }
  }

  static Map<String, String> _parseDslAttributes(String attrsStr) {
    final result = <String, String>{};
    final pairs = attrsStr.split(',');
    for (final pair in pairs) {
      final kv = pair.split(':');
      if (kv.length == 2) {
        final k = kv[0].trim();
        var v = kv[1].trim();
        if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
          v = v.substring(1, v.length - 1);
        }
        if (k.isNotEmpty && v.isNotEmpty) {
          result[k] = v;
        }
      }
    }
    return result;
  }

  static void _formatElementDsl(XmlElement element, StringBuffer buffer, int indentLevel) {
    final indent = '  ' * indentLevel;
    final tag = element.name.local;

    if (tag == 'ncl') {
      final id = element.getAttribute('id') ?? 'main';
      buffer.writeln('${indent}ncl $id {');
      for (final child in element.children.whereType<XmlElement>()) {
        _formatElementDsl(child, buffer, indentLevel + 1);
      }
      buffer.writeln('$indent}');
      return;
    }

    if (tag == 'head' || tag == 'body') {
      final id = element.getAttribute('id');
      final idStr = id != null ? ' $id' : '';
      buffer.writeln('$indent$tag$idStr {');
      for (final child in element.children.whereType<XmlElement>()) {
        _formatElementDsl(child, buffer, indentLevel + 1);
      }
      buffer.writeln('$indent}');
      return;
    }

    if (tag == 'regionBase' || tag == 'descriptorBase' || tag == 'connectorBase') {
      buffer.writeln('$indent$tag {');
      for (final child in element.children.whereType<XmlElement>()) {
        _formatElementDsl(child, buffer, indentLevel + 1);
      }
      buffer.writeln('$indent}');
      return;
    }

    if (tag == 'port') {
      final id = element.getAttribute('id') ?? 'p';
      final comp = element.getAttribute('component') ?? '';
      final iface = element.getAttribute('interface');
      final ifaceStr = iface != null ? '::$iface' : '';
      buffer.writeln('$indent$tag $id -> $comp$ifaceStr');
      return;
    }

    if (tag == 'bind') {
      final role = element.getAttribute('role') ?? 'onBegin';
      final comp = element.getAttribute('component') ?? '';
      final iface = element.getAttribute('interface');
      final ifaceStr = iface != null ? '::$iface' : '';
      buffer.writeln('$indent$tag $role -> $comp$ifaceStr');
      return;
    }

    if (element.children.whereType<XmlElement>().isNotEmpty) {
      final id = element.getAttribute('id');
      final idStr = id != null ? ' $id' : '';
      final otherAttrs = element.attributes
          .where((a) => a.name.local != 'id')
          .map((a) => '${a.name.local}: "${a.value}"')
          .join(', ');
      final attrStr = otherAttrs.isNotEmpty ? ' { $otherAttrs }' : ' {';
      buffer.writeln('$indent$tag$idStr$attrStr');
      for (final child in element.children.whereType<XmlElement>()) {
        _formatElementDsl(child, buffer, indentLevel + 1);
      }
      buffer.writeln('$indent}');
      return;
    }

    final id = element.getAttribute('id');
    final idStr = id != null ? ' $id' : '';
    final otherAttrs = element.attributes
        .where((a) => a.name.local != 'id')
        .map((a) => '${a.name.local}: "${a.value}"')
        .join(', ');
    buffer.writeln('$indent$tag$idStr { $otherAttrs }');
  }
}
