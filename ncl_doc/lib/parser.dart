import 'package:xml/xml.dart';

import 'elements.dart';
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

    _resolveMediaProperties(head, body);

    return (head, body);
  }

  static int? parseDurStr(String? durStr) {
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
      case 'bindParam':
        element = BindParam(rawAttributes: attrs);
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
      case 'transition':
        element = Transition(rawAttributes: attrs);
        break;
      case 'rule':
        element = Rule(rawAttributes: attrs);
        break;
      case 'descriptorParam':
      case 'param':
        element = DescriptorParam(rawAttributes: attrs);
        break;
      case 'simpleCondition':
        element = SimpleCondition(rawAttributes: attrs);
        break;
      case 'compoundCondition':
        element = CompoundCondition(rawAttributes: attrs);
        break;
      case 'assessmentStatement':
        element = AssessmentStatement(rawAttributes: attrs);
        break;
      case 'attributeAssessment':
        element = AttributeAssessment(rawAttributes: attrs);
        break;
      case 'valueAssessment':
        element = ValueAssessment(rawAttributes: attrs);
        break;
      case 'head':
      case 'regionBase':
      case 'descriptorBase':
      case 'connectorBase':
      case 'ruleBase':
      case 'compositeRule':
      case 'transitionBase':
      case 'bindRule':
      case 'defaultComponent':
      case 'switchPort':
      case 'mapping':
      case 'importBase':
      case 'compoundAction':
      case 'simpleAction':
      case 'descriptorSwitch':
      case 'importedDocumentBase':
      case 'importNCL':
      case 'fontBase':
      case 'font':
        element = Element(rawAttributes: attrs);
        break;
      default:
        return null;
    }
    element.xmlTagName = node.name.local;

    for (var childNode in node.children.whereType<XmlElement>()) {
      final childElement = _parseNode(childNode);
      if (childElement != null) {
        element.children.add(childElement);
        if (childElement is Node) {
          if (element is Composition) {
            childElement.parent = element;
          }
        } else {
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
    final mimeType = type.isNotEmpty ? type : getMimeTypeFromExtension(src);
    if (mimeType.startsWith('video/') || mimeType.startsWith('audio/')) {
      final avMedia = AVMedia(
        rawAttributes: rawAttributes,
        uri: uri,
        mimeType: mimeType,
      );
      final expectedDurMs = _parseDurStr(rawAttributes['expectedDuration']);
      if (expectedDurMs != null) {
        avMedia.explicitDurMs = expectedDurMs;
      }
      return avMedia;
    }
    return Media(rawAttributes: rawAttributes, uri: uri, mimeType: mimeType);
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

  void doNclEditingCommand(NCLDocument doc, String command) {
    final parsed = _parseCommand(command);
    if (parsed == null) return;

    Element? parseXml(String xmlStr) {
      try {
        final root = XmlDocument.parse(xmlStr).rootElement;
        return _parseNode(root);
      } catch (e) {
        return null;
      }
    }

    Element? findElementInHead(bool Function(Element) predicate) {
      final head = doc.getHead();
      if (head == null) return null;
      Element? search(Element el) {
        if (predicate(el)) return el;
        for (var child in el.children) {
          final res = search(child);
          if (res != null) return res;
        }
        return null;
      }

      for (var el in head) {
        final res = search(el);
        if (res != null) return res;
      }
      return null;
    }

    bool removeElementFromHead(String id) {
      final head = doc.getHead();
      if (head == null) return false;
      bool searchAndRemove(Element parent, Element el) {
        if (el.id == id) {
          parent.children.remove(el);
          return true;
        }
        for (var child in List<Element>.from(el.children)) {
          if (searchAndRemove(el, child)) return true;
        }
        return false;
      }

      for (var el in List<Element>.from(head)) {
        if (el.id == id) {
          head.remove(el);
          return true;
        }
        for (var child in List<Element>.from(el.children)) {
          if (searchAndRemove(el, child)) return true;
        }
      }
      return false;
    }

    switch (parsed.name) {
      case 'addRegionBase':
        if (parsed.args.isEmpty) return;
        final el = parseXml(parsed.args[0]);
        if (el != null) {
          doc.getHead()?.add(el);
        }
        break;
      case 'removeRegionBase':
        if (parsed.args.isEmpty) return;
        removeElementFromHead(parsed.args[0]);
        break;
      case 'addRegion':
        if (parsed.args.length < 3) return;
        final regionBaseId = parsed.args[0];
        final regionId = parsed.args[1];
        final xmlRegion = parsed.args[2];
        final newRegion = parseXml(xmlRegion);
        if (newRegion == null) return;
        if (regionId != 'null' && regionId.isNotEmpty) {
          final parent = findElementInHead(
            (el) => el is Region && el.id == regionId,
          );
          if (parent != null) {
            parent.children.add(newRegion);
            newRegion.parent = parent;
          }
        } else {
          final parent = findElementInHead(
            (el) =>
                el.xmlTagName == 'regionBase' &&
                (regionBaseId.isEmpty || el.id == regionBaseId),
          );
          if (parent != null) {
            parent.children.add(newRegion);
            newRegion.parent = parent;
          }
        }
        break;
      case 'removeRegion':
        if (parsed.args.isEmpty) return;
        removeElementFromHead(parsed.args[0]);
        break;
      case 'addRuleBase':
        if (parsed.args.isEmpty) return;
        final el = parseXml(parsed.args[0]);
        if (el != null) {
          doc.getHead()?.add(el);
        }
        break;
      case 'removeRuleBase':
        if (parsed.args.isEmpty) return;
        removeElementFromHead(parsed.args[0]);
        break;
      case 'addRule':
        if (parsed.args.isEmpty) return;
        final newRule = parseXml(parsed.args[0]);
        if (newRule == null) return;
        final parent = findElementInHead((el) => el.xmlTagName == 'ruleBase');
        if (parent != null) {
          parent.children.add(newRule);
          newRule.parent = parent;
        }
        break;
      case 'removeRule':
        if (parsed.args.isEmpty) return;
        removeElementFromHead(parsed.args[0]);
        break;
      case 'addConnectorBase':
        if (parsed.args.isEmpty) return;
        final el = parseXml(parsed.args[0]);
        if (el != null) {
          doc.getHead()?.add(el);
        }
        break;
      case 'removeConnectorBase':
        if (parsed.args.isEmpty) return;
        removeElementFromHead(parsed.args[0]);
        break;
      case 'addConnector':
        if (parsed.args.isEmpty) return;
        final newConnector = parseXml(parsed.args[0]);
        if (newConnector == null) return;
        final parent = findElementInHead(
          (el) => el.xmlTagName == 'connectorBase',
        );
        if (parent != null) {
          parent.children.add(newConnector);
          newConnector.parent = parent;
        }
        break;
      case 'removeConnector':
        if (parsed.args.isEmpty) return;
        removeElementFromHead(parsed.args[0]);
        break;
      case 'addDescriptorBase':
        if (parsed.args.isEmpty) return;
        final el = parseXml(parsed.args[0]);
        if (el != null) {
          doc.getHead()?.add(el);
        }
        break;
      case 'removeDescriptorBase':
        if (parsed.args.isEmpty) return;
        removeElementFromHead(parsed.args[0]);
        break;
      case 'addDescriptor':
        if (parsed.args.isEmpty) return;
        final newDesc = parseXml(parsed.args[0]);
        if (newDesc == null) return;
        final parent = findElementInHead(
          (el) => el.xmlTagName == 'descriptorBase',
        );
        if (parent != null) {
          parent.children.add(newDesc);
          newDesc.parent = parent;
        }
        break;
      case 'removeDescriptor':
        if (parsed.args.isEmpty) return;
        removeElementFromHead(parsed.args[0]);
        break;
      case 'addDescriptorSwitch':
        if (parsed.args.isEmpty) return;
        final newDescSwitch = parseXml(parsed.args[0]);
        if (newDescSwitch == null) return;
        final parent = findElementInHead(
          (el) => el.xmlTagName == 'descriptorBase',
        );
        if (parent != null) {
          parent.children.add(newDescSwitch);
          newDescSwitch.parent = parent;
        }
        break;
      case 'removeDescriptorSwitch':
        if (parsed.args.isEmpty) return;
        removeElementFromHead(parsed.args[0]);
        break;
      case 'addTransitionBase':
        if (parsed.args.isEmpty) return;
        final el = parseXml(parsed.args[0]);
        if (el != null) {
          doc.getHead()?.add(el);
        }
        break;
      case 'removeTransitionBase':
        if (parsed.args.isEmpty) return;
        removeElementFromHead(parsed.args[0]);
        break;
      case 'addTransition':
        if (parsed.args.isEmpty) return;
        final newTrans = parseXml(parsed.args[0]);
        if (newTrans == null) return;
        final parent = findElementInHead(
          (el) => el.xmlTagName == 'transitionBase',
        );
        if (parent != null) {
          parent.children.add(newTrans);
          newTrans.parent = parent;
        }
        break;
      case 'removeTransition':
        if (parsed.args.isEmpty) return;
        removeElementFromHead(parsed.args[0]);
        break;
      case 'addImportBase':
        if (parsed.args.isEmpty) return;
        final newImport = parseXml(parsed.args[0]);
        if (newImport == null) return;
        final parent = findElementInHead(
          (el) => el.xmlTagName == 'importedDocumentBase',
        );
        if (parent != null) {
          parent.children.add(newImport);
          newImport.parent = parent;
        }
        break;
      case 'removeImportBase':
        if (parsed.args.isEmpty) return;
        final docURI = parsed.args[0];
        final parentImport = findElementInHead(
          (el) => el.xmlTagName == 'importedDocumentBase',
        );
        if (parentImport != null) {
          parentImport.children.removeWhere(
            (el) => el.rawAttributes['documentURI'] == docURI,
          );
        }
        break;
      case 'addImportedDocumentBase':
        if (parsed.args.isEmpty) return;
        final el = parseXml(parsed.args[0]);
        if (el != null) {
          doc.getHead()?.add(el);
        }
        break;
      case 'removeImportedDocumentBase':
        if (parsed.args.isEmpty) return;
        removeElementFromHead(parsed.args[0]);
        break;
      case 'addImportNCL':
        if (parsed.args.isEmpty) return;
        final newImportNCL = parseXml(parsed.args[0]);
        if (newImportNCL == null) return;
        final parentImportNCL = findElementInHead(
          (el) => el.xmlTagName == 'importedDocumentBase',
        );
        if (parentImportNCL != null) {
          parentImportNCL.children.add(newImportNCL);
          newImportNCL.parent = parentImportNCL;
        }
        break;
      case 'removeImportNCL':
        if (parsed.args.isEmpty) return;
        final docURINcl = parsed.args[0];
        final parentImportNcl = findElementInHead(
          (el) => el.xmlTagName == 'importedDocumentBase',
        );
        if (parentImportNcl != null) {
          parentImportNcl.children.removeWhere(
            (el) => el.rawAttributes['documentURI'] == docURINcl,
          );
        }
        break;
      case 'addNode':
        if (parsed.args.length < 2) return;
        final compositeId = parsed.args[0];
        final nodeArg = parsed.args[1];
        final parentComp = doc.getNodeById(compositeId);
        if (parentComp is Composition) {
          if (nodeArg.trim().startsWith('<')) {
            final newNode = parseXml(nodeArg);
            if (newNode is Node) {
              parentComp.children.add(newNode);
              newNode.parent = parentComp;
            }
          } else {
            final nodeId = nodeArg;
            final docURI = parsed.args.length > 2 ? parsed.args[2] : '';
            final newNode = Media(
              rawAttributes: {'id': nodeId, 'refer': docURI},
            );
            parentComp.children.add(newNode);
            newNode.parent = parentComp;
          }
        }
        break;
      case 'removeNode':
        if (parsed.args.length < 2) return;
        final compositeId = parsed.args[0];
        final nodeId = parsed.args[1];
        final parentComp = doc.getNodeById(compositeId);
        if (parentComp is Composition) {
          parentComp.children.removeWhere(
            (el) => el is Node && el.id == nodeId,
          );
        }
        break;
      case 'addInterface':
        if (parsed.args.length < 2) return;
        final nodeId = parsed.args[0];
        final xmlInterface = parsed.args[1];
        final targetNode = doc.getNodeById(nodeId);
        if (targetNode != null) {
          final newInterface = parseXml(xmlInterface);
          if (newInterface != null) {
            targetNode.children.add(newInterface);
            newInterface.parent = targetNode;
          }
        }
        break;
      case 'removeInterface':
        if (parsed.args.length < 2) return;
        final nodeId = parsed.args[0];
        final interfaceId = parsed.args[1];
        final targetNode = doc.getNodeById(nodeId);
        if (targetNode != null) {
          targetNode.children.removeWhere((el) => el.id == interfaceId);
        }
        break;
      case 'addLink':
        if (parsed.args.length < 2) return;
        final compositeId = parsed.args[0];
        final xmlLink = parsed.args[1];
        final parentComp = doc.getNodeById(compositeId);
        if (parentComp is Composition) {
          final newLink = parseXml(xmlLink);
          if (newLink is Link) {
            parentComp.children.add(newLink);
            newLink.parent = parentComp;
          }
        }
        break;
      case 'removeLink':
        if (parsed.args.length < 2) return;
        final compositeId = parsed.args[0];
        final linkId = parsed.args[1];
        final parentComp = doc.getNodeById(compositeId);
        if (parentComp is Composition) {
          parentComp.children.removeWhere(
            (el) => el is Link && el.id == linkId,
          );
        }
        break;
      case 'setPropertyValue':
        if (parsed.args.length < 3) return;
        final nodeId = parsed.args[0];
        final propertyId = parsed.args[1];
        final value = parsed.args[2];
        final targetNode = doc.getNodeById(nodeId);
        if (targetNode != null) {
          targetNode.setPropertyValue(propertyId, value);
        }
        break;
      case 'addFontBase':
        if (parsed.args.isEmpty) return;
        final el = parseXml(parsed.args[0]);
        if (el != null) {
          doc.getHead()?.add(el);
        }
        break;
      case 'removeFontBase':
        if (parsed.args.isEmpty) return;
        removeElementFromHead(parsed.args[0]);
        break;
      case 'addFont':
        if (parsed.args.isEmpty) return;
        final newFont = parseXml(parsed.args[0]);
        if (newFont != null) {
          final parent = findElementInHead((el) => el.xmlTagName == 'fontBase');
          if (parent != null) {
            parent.children.add(newFont);
            newFont.parent = parent;
          }
        }
        break;
      case 'removeFont':
        if (parsed.args.length < 3) return;
        final family = parsed.args[0];
        final style = parsed.args[1];
        final weight = parsed.args[2];
        final parent = findElementInHead((el) => el.xmlTagName == 'fontBase');
        if (parent != null) {
          parent.children.removeWhere(
            (el) =>
                el.rawAttributes['family'] == family &&
                el.rawAttributes['style'] == style &&
                el.rawAttributes['weight'] == weight,
          );
        }
        break;
    }
  }

  void _resolveMediaProperties(Head head, Body body) {
    Descriptor? findDescriptor(String id) {
      Descriptor? search(Element parent) {
        if (parent is Descriptor && parent.id == id) {
          return parent;
        }
        for (var child in parent.children) {
          final res = search(child);
          if (res != null) return res;
        }
        return null;
      }

      for (var el in head) {
        final res = search(el);
        if (res != null) return res;
      }
      return null;
    }

    Region? findRegion(String id) {
      Region? search(Element parent) {
        if (parent is Region && parent.id == id) {
          return parent;
        }
        for (var child in parent.children) {
          final res = search(child);
          if (res != null) return res;
        }
        return null;
      }

      for (var el in head) {
        final res = search(el);
        if (res != null) return res;
      }
      return null;
    }

    double parsePercent(String val) {
      final trimmed = val.trim();
      if (trimmed.endsWith('%')) {
        final num =
            double.tryParse(trimmed.substring(0, trimmed.length - 1)) ?? 0.0;
        return num / 100.0;
      }
      final num = double.tryParse(trimmed);
      return num ?? 0.0;
    }

    (double, double, double, double) resolveRegionRect(Region region) {
      final parentEl = region.parent;
      final leftStr = region.rawAttributes['left'] ?? '0%';
      final topStr = region.rawAttributes['top'] ?? '0%';
      final widthStr = region.rawAttributes['width'] ?? '100%';
      final heightStr = region.rawAttributes['height'] ?? '100%';

      final leftVal = parsePercent(leftStr);
      final topVal = parsePercent(topStr);
      final widthVal = parsePercent(widthStr);
      final heightVal = parsePercent(heightStr);

      if (parentEl is Region) {
        final parentRect = resolveRegionRect(parentEl);
        final leftAbs = parentRect.$1 + leftVal * parentRect.$3;
        final topAbs = parentRect.$2 + topVal * parentRect.$4;
        final widthAbs = widthVal * parentRect.$3;
        final heightAbs = heightVal * parentRect.$4;
        return (leftAbs, topAbs, widthAbs, heightAbs);
      } else {
        return (leftVal, topVal, widthVal, heightVal);
      }
    }

    int resolveRegionZIndex(Region region) {
      final zIndexStr =
          region.rawAttributes['zIndex'] ?? region.rawAttributes['zOrder'];
      if (zIndexStr != null) {
        return int.tryParse(zIndexStr) ?? 0;
      }
      final parentEl = region.parent;
      if (parentEl is Region) {
        return resolveRegionZIndex(parentEl);
      }
      return 0;
    }

    void resolveMedia(Element el) {
      if (el is Media) {
        final descriptorId = el.rawAttributes['descriptor'];
        if (descriptorId != null) {
          final desc = findDescriptor(descriptorId);
          if (desc != null) {
            // copy descriptor attributes to media if not already defined
            desc.rawAttributes.forEach((key, val) {
              if (key != 'id' && key != 'region') {
                if (!el.rawAttributes.containsKey(key)) {
                  el.rawAttributes[key] = val;
                }
              }
            });

            // resolve explicit duration
            final explicitDurVal =
                desc.rawAttributes['explicitDur'] ??
                el.rawAttributes['explicitDur'];
            if (explicitDurVal != null) {
              el.explicitDurMs = _parseDurStr(explicitDurVal);
            }

            final regionId = desc.rawAttributes['region'];
            if (regionId != null) {
              final reg = findRegion(regionId);
              if (reg != null) {
                // resolve region rect
                final rect = resolveRegionRect(reg);

                // set region layout properties on media rawAttributes
                el.rawAttributes['resolvedLeft'] =
                    '${(rect.$1 * 100).toStringAsFixed(2)}%';
                el.rawAttributes['resolvedTop'] =
                    '${(rect.$2 * 100).toStringAsFixed(2)}%';
                el.rawAttributes['resolvedWidth'] =
                    '${(rect.$3 * 100).toStringAsFixed(2)}%';
                el.rawAttributes['resolvedHeight'] =
                    '${(rect.$4 * 100).toStringAsFixed(2)}%';

                // resolve zIndex
                final zindex = resolveRegionZIndex(reg);
                el.rawAttributes['resolvedZIndex'] = zindex.toString();
              }
            }
          }
        }
      }
      for (var child in el.children) {
        resolveMedia(child);
      }
    }

    resolveMedia(body);
  }
}

class ParsedCommand {
  final String name;
  final List<String> args;
  ParsedCommand(this.name, this.args);
}

ParsedCommand? _parseCommand(String commandStr) {
  commandStr = commandStr.trim();
  final parenIndex = commandStr.indexOf('(');
  if (parenIndex == -1 || !commandStr.endsWith(')')) {
    return null;
  }
  final name = commandStr.substring(0, parenIndex).trim();
  final argsStr = commandStr.substring(parenIndex + 1, commandStr.length - 1);

  final args = <String>[];
  int i = 0;
  while (i < argsStr.length) {
    while (i < argsStr.length &&
        (argsStr[i] == ' ' ||
            argsStr[i] == '\t' ||
            argsStr[i] == '\r' ||
            argsStr[i] == '\n')) {
      i++;
    }
    if (i >= argsStr.length) break;

    if (argsStr[i] == '"' || argsStr[i] == "'") {
      final quoteChar = argsStr[i];
      i++;
      final buf = StringBuffer();
      while (i < argsStr.length && argsStr[i] != quoteChar) {
        if (argsStr[i] == '\\' && i + 1 < argsStr.length) {
          buf.write(argsStr[i + 1]);
          i += 2;
        } else {
          buf.write(argsStr[i]);
          i++;
        }
      }
      if (i < argsStr.length) i++;
      args.add(buf.toString());
    } else {
      final buf = StringBuffer();
      int bracketDepth = 0;
      bool inDoubleQuote = false;
      bool inSingleQuote = false;
      while (i < argsStr.length) {
        final char = argsStr[i];
        if (char == '"' && !inSingleQuote) {
          inDoubleQuote = !inDoubleQuote;
        } else if (char == "'" && !inDoubleQuote) {
          inSingleQuote = !inSingleQuote;
        } else if (char == '<' && !inDoubleQuote && !inSingleQuote) {
          bracketDepth++;
        } else if (char == '>' && !inDoubleQuote && !inSingleQuote) {
          bracketDepth--;
        }

        if (char == ',' &&
            !inDoubleQuote &&
            !inSingleQuote &&
            bracketDepth == 0) {
          break;
        }
        buf.write(char);
        i++;
      }
      args.add(buf.toString().trim());
    }

    if (i < argsStr.length && argsStr[i] == ',') {
      i++;
    }
  }
  return ParsedCommand(name, args);
}
