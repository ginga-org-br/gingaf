library;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';

import 'elements.dart';
import 'event.dart';
import 'parser.dart';
import 'ncl_scheduler.dart';

export 'elements.dart';
export 'event.dart';
export 'lua.dart';
export 'parser.dart';
export 'ncl_scheduler.dart';

final _logger = Logger('ncl_doc');

class NCLDocument {
  late final Head? _head;
  late final Context _body;
  late final Settings _settings;
  final Uri baseURI;

  late final NCLScheduler scheduler = NCLScheduler(this);
  final Map<String, String> systemVariables = {'system.language': 'por'};

  factory NCLDocument.fromBodyElements(List<Element> elements) {
    final body = Context(rawAttributes: const {'id': 'body'});
    body.children.addAll(elements);
    for (var el in elements) {
      if (el is Node) {
        el.parent = body;
      }
    }
    return NCLDocument._(body: body);
  }

  factory NCLDocument.fromXML(String xml, {Uri? baseURI}) {
    final (head, body) = NCLParser(baseURI: baseURI).parseString(xml);
    return NCLDocument._(head: head, body: body, baseURI: baseURI);
  }

  factory NCLDocument.fromURI(Uri uri) {
    final path = uri.isScheme('file') ? uri.toFilePath() : uri.path;
    final file = File(path);
    final xml = file.readAsStringSync();
    return NCLDocument.fromXML(xml, baseURI: uri);
  }

  NCLDocument._({Head? head, required Body body, Uri? baseURI})
    : baseURI = baseURI ?? Uri.parse('.') {
    _head = head;
    _body = body;
    _gatherSettings();
  }

  void _gatherSettings() {
    final settingsList = _body.children.whereType<Settings>();
    if (settingsList.isNotEmpty) {
      _settings = settingsList.first;
    } else {
      _settings = Settings(rawAttributes: const {'id': '__settings__'});
      _body.children.add(_settings);
      _settings.parent = _body;
    }
  }

  Head? get head => _head;
  Context get body => _body;
  State getBodyState() => _body.getMainState();

  Settings getSettings() => _settings;

  void doNclEditingCommand(String command) {
    NCLParser(baseURI: baseURI).doNclEditingCommand(this, command);
  }

  Node? getNodeById(String id) {
    if (_body.id == id) return _body;

    Node? search(Composition comp) {
      for (var node in comp.getNodes()) {
        if (node.id == id) return node;
        if (node is Composition) {
          final res = search(node);
          if (res != null) return res;
        }
      }
      return null;
    }

    return search(_body);
  }

  Element? getElementById(String id) {
    Element? search(Element element) {
      if (element.id == id) return element;
      for (var child in element.children) {
        final res = search(child);
        if (res != null) return res;
      }
      return null;
    }

    for (var el in headChildren) {
      final res = search(el);
      if (res != null) return res;
    }
    return search(_body);
  }

  List<Element> get headChildren => _head ?? const [];

  bool evaluateRule(String ruleId) {
    final ruleBase = headChildren
        .where((el) => el.xmlTagName == 'ruleBase')
        .firstOrNull;
    if (ruleBase == null) return false;

    Element? findRule(Element parent, String id) {
      if ((parent.xmlTagName == 'rule' ||
              parent.xmlTagName == 'compositeRule') &&
          parent.rawAttributes['id'] == id) {
        return parent;
      }
      for (var child in parent.children) {
        final res = findRule(child, id);
        if (res != null) return res;
      }
      return null;
    }

    final ruleEl = findRule(ruleBase, ruleId);
    if (ruleEl == null) return false;

    return _evaluateRuleElement(ruleEl);
  }

  bool _evaluateRuleElement(Element ruleEl) {
    if (ruleEl.xmlTagName == 'rule') {
      final varName = ruleEl.rawAttributes['var'] ?? '';
      final value = ruleEl.rawAttributes['value'] ?? '';
      final comparator = ruleEl.rawAttributes['comparator'] ?? 'eq';
      final systemVal = systemVariables[varName] ?? '';

      switch (comparator) {
        case 'eq':
          return systemVal == value;
        case 'ne':
          return systemVal != value;
        case 'gt':
          final n1 = double.tryParse(systemVal);
          final n2 = double.tryParse(value);
          if (n1 != null && n2 != null) return n1 > n2;
          return systemVal.compareTo(value) > 0;
        case 'lt':
          final n1 = double.tryParse(systemVal);
          final n2 = double.tryParse(value);
          if (n1 != null && n2 != null) return n1 < n2;
          return systemVal.compareTo(value) < 0;
        case 'gte':
          final n1 = double.tryParse(systemVal);
          final n2 = double.tryParse(value);
          if (n1 != null && n2 != null) return n1 >= n2;
          return systemVal.compareTo(value) >= 0;
        case 'lte':
          final n1 = double.tryParse(systemVal);
          final n2 = double.tryParse(value);
          if (n1 != null && n2 != null) return n1 <= n2;
          return systemVal.compareTo(value) <= 0;
      }
      return false;
    } else if (ruleEl.xmlTagName == 'compositeRule') {
      final operator = ruleEl.rawAttributes['operator'] ?? 'and';
      final results = ruleEl.children
          .where(
            (c) => c.xmlTagName == 'rule' || c.xmlTagName == 'compositeRule',
          )
          .map((c) => _evaluateRuleElement(c));
      if (results.isEmpty) return false;
      if (operator == 'and') {
        return results.every((r) => r);
      } else {
        return results.any((r) => r);
      }
    }
    return false;
  }

  Node? resolveSwitch(Switch switchNode) {
    final bindRules = switchNode.children.where(
      (c) => c.xmlTagName == 'bindRule',
    );
    for (var bindRule in bindRules) {
      final ruleId = bindRule.rawAttributes['rule'];
      final constituentId = bindRule.rawAttributes['constituent'];
      if (ruleId != null && constituentId != null) {
        if (evaluateRule(ruleId)) {
          final res = getNodeById(constituentId);
          if (res != null) return res;
        }
      }
    }
    final defaultComp = switchNode.children
        .where((c) => c.xmlTagName == 'defaultComponent')
        .firstOrNull;
    if (defaultComp != null) {
      final compId = defaultComp.rawAttributes['component'];
      if (compId != null) {
        return getNodeById(compId);
      }
    }
    return null;
  }

  List<Media> getActiveMedia() {
    final active = <Media>[];
    void search(Composition comp) {
      for (var node in comp.getNodes()) {
        if (node is Media && node.getMainState() == State.OCCURRING) {
          active.add(node);
        } else if (node is Composition) {
          search(node);
        }
      }
    }

    search(_body);
    return active;
  }

  Element? getConnectorById(String id) {
    final connBase = headChildren
        .where((el) => el.xmlTagName == 'connectorBase')
        .firstOrNull;
    if (connBase != null) {
      for (var child in connBase.children) {
        if (child.rawAttributes['id'] == id) {
          return child;
        }
      }
    }
    return null;
  }

  String? getPropertyValue(Node node, String propertyName) {
    var currentNode = node;
    final referId = currentNode.rawAttributes['refer'];
    if (referId != null) {
      final refNode = getNodeById(referId);
      if (refNode != null) {
        currentNode = refNode;
      }
    }
    final prop = currentNode.children
        .whereType<Property>()
        .where((p) => p.name == propertyName)
        .firstOrNull;
    return prop?.value;
  }

  int get virtualClock => scheduler.virtualClock;
  set virtualClock(int val) => scheduler.virtualClock = val;
  bool get isPlaying => scheduler.isPlaying;
  set isPlaying(bool val) => scheduler.isPlaying = val;
  List<Action> get uiQueue => scheduler.uiQueue;

  void start() => scheduler.start();
  void stop() => scheduler.stop();
  Set<Media> tick([int incrementMs = 0]) => scheduler.tick(incrementMs);
  void tickIndefinitely({int ticksPerSecond = 10, void Function()? onStop}) =>
      scheduler.tickIndefinitely(ticksPerSecond: ticksPerSecond, onStop: onStop);
  void triggerSelection(String componentId, String keyCode) =>
      scheduler.triggerSelection(componentId, keyCode);
}
