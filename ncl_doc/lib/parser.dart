import 'package:xml/xml.dart';

import 'mimetype.dart';
import 'ncl_document.dart';
import 'schema.dart';

class NCLParser {
  final Schema schema = Schema();
  final Uri baseURI;

  NCLParser({Uri? baseURI}) : baseURI = baseURI ?? Uri.parse('.');

  (Head, Body) parseString(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final root = document.rootElement;

    Head head = [];
    Body body = Context(rawAttributes: const {'id': 'body'});

    for (var childNode in root.children.whereType<XmlElement>()) {
      if (childNode.name.local == 'head') {
        final headElement = _parseNode(childNode);
        if (headElement != null) {
          head = headElement.children;
        }
      } else if (childNode.name.local == 'body') {
        final bodyElement = _parseNode(childNode);
        if (bodyElement is Context) {
          body = bodyElement;
        }
      }
    }

    return (head, body);
  }

  int? _parseDurStr(String? durStr) {
    if (durStr == null) return null;
    if (durStr.endsWith('ms')) {
      return int.tryParse(durStr.replaceAll('ms', ''));
    } else if (durStr.endsWith('s')) {
      final s = double.tryParse(durStr.replaceAll('s', ''));
      return s != null ? (s * 1000).toInt() : null;
    }
    final val = double.tryParse(durStr);
    return val != null ? (val * 1000).toInt() : null;
  }

  Element? _parseNode(XmlElement node) {
    Map<String, String> attrs = {
      for (var attr in node.attributes) attr.name.local: attr.value,
    };
    final Element element;
    switch (node.name.local) {
      case 'media':
        element = _createMediaElement(attrs);
        break;
      case 'context':
      case 'body':
        element = Context(rawAttributes: attrs);
        break;
      case 'region':
        element = Region(rawAttributes: attrs);
        break;
      case 'descriptor':
        element = Descriptor(rawAttributes: attrs);
        break;
      case 'link':
        element = Link(rawAttributes: attrs);
        break;
      case 'connector':
      case 'causalConnector':
        element = Connector(rawAttributes: attrs);
        break;
      case 'port':
        element = Port(rawAttributes: attrs);
        break;
      case 'bind':
        element = Bind(rawAttributes: attrs);
        break;
      case 'property':
        element = Property(rawAttributes: attrs);
        break;
      case 'area':
        element = Area(rawAttributes: attrs);
        break;
      case 'switch':
        element = Switch(rawAttributes: attrs);
        break;
      case 'settings':
        element = Settings(rawAttributes: attrs);
        break;
      case 'head':
      case 'regionBase':
      case 'descriptorBase':
      case 'connectorBase':
        element = Element(rawAttributes: attrs);
        break;
      default:
        return null;
    }

    for (var childNode in node.children.whereType<XmlElement>()) {
      final childElement = _parseNode(childNode);
      if (childElement != null) {
        element.children.add(childElement);
        if (element is Composition && childElement is Node) {
          childElement.parent = element;
        }
      }
    }

    if (element is Node) {
      final explicitDurProp = element.children
          .whereType<Property>()
          .where((p) => p.name == 'explicitDur')
          .firstOrNull;
      if (explicitDurProp != null && explicitDurProp.value != null) {
        element.explicitDurMs = _parseDurStr(explicitDurProp.value!);
      }
      if (element is AVMedia) {
        final expectedDurProp = element.children
            .whereType<Property>()
            .where((p) => p.name == 'expectedDuration')
            .firstOrNull;
        if (expectedDurProp != null && expectedDurProp.value != null) {
          element.explicitDurMs = _parseDurStr(expectedDurProp.value!);
        }
      }
    }

    return element;
  }

  Media _createMediaElement(Map<String, String> rawAttributes) {
    final src = rawAttributes['src'] ?? '';
    final type = rawAttributes['type'] ?? '';
    if (src.isEmpty && type.isEmpty) {
      return Media(rawAttributes: rawAttributes);
    }
    if (type == 'application/x-ncl-settings' ||
        type == 'application/x-ginga-settings') {
      return Settings(rawAttributes: rawAttributes, mimeType: type);
    }
    final resolvedSrc = src.replaceAll('\\', '/');
    final uri = src.isNotEmpty ? baseURI.resolve(resolvedSrc).toString() : '';
    final mimeType =
        type.isNotEmpty ? type : getMimeTypeFromExtension(src);
    if (mimeType.startsWith('video/') || mimeType.startsWith('audio/')) {
      final avMedia = AVMedia(
        rawAttributes: rawAttributes,
        uri: uri,
        mimeType: mimeType,
      );
      final expectedDurMs =
          _parseDurStr(rawAttributes['expectedDuration']);
      if (expectedDurMs != null) {
        avMedia.explicitDurMs = expectedDurMs;
      }
      return avMedia;
    }
    return Media(
      rawAttributes: rawAttributes,
      uri: uri,
      mimeType: mimeType,
    );
  }

  List<String> validate(String xmlString) {
    final errors = <String>[];
    try {
      final document = XmlDocument.parse(xmlString);
      for (var node in document.descendants) {
        if (node is XmlElement) {
          errors.addAll(schema.validateElement(node));
        }
      }
    } catch (e) {
      errors.add('Invalid XML format: $e');
    }
    return errors;
  }
}
