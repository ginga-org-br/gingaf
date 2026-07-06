library;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';

import 'elements.dart';
import 'event.dart';
import 'parser.dart';

export 'elements.dart';
export 'event.dart';
export 'lua.dart';
export 'parser.dart';

final _logger = Logger('ncl_doc');

class NCLDocument {
  late final Head? _head;
  late final Context _body;
  late final Settings _settings;
  final Uri baseURI;

  int virtualClock = 0;
  bool isPlaying = false;
  final Map<String, String> systemVariables = {'system.language': 'por'};
  final List<Action> _actionStack = [];
  final List<({Action action, int executeTime})> _delayedActions = [];
  final List<Action> uiQueue = [];
  final List<Node> _timedNodes = [];

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
  }

  Head? getHead() => _head;
  Context getBody() => _body;
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

  void _init() {
    _gatherSettings();
    _gatherTimedNodes();
    _stackMainEvtAction(_body, ActionType.START);
    _stackPorts(_body);
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

  void _gatherTimedNodes() {
    void gather(Composition comp) {
      for (var node in comp.getNodes()) {
        bool isTimed = node.explicitDurMs != null;
        if (!isTimed) {
          for (var area in node.getAreas()) {
            if (area.begin != null || area.end != null) {
              isTimed = true;
              break;
            }
          }
        }
        if (!isTimed && node is AVMedia) {
          isTimed = true;
        }
        if (isTimed) {
          _timedNodes.add(node);
        }
        if (node is Composition) {
          gather(node);
        }
      }
    }

    gather(_body);
  }

  void _stackPorts(Context comp) {
    for (var port in comp.getPorts()) {
      if (port.component != null) {
        final node = getNodeById(port.component!);
        if (node != null) {
          _stackMainEvtAction(node, ActionType.START);
          if (node is Context) {
            _stackPorts(node);
          }
        }
      }
    }
  }

  Set<Media> tick([int incrementMs = 0]) {
    if (uiQueue.isNotEmpty) {
      _actionStack.addAll(uiQueue);
      uiQueue.clear();
    }
    _updateTimedNodesClock(incrementMs);
    _processDelayedActions();
    final changedNodes = _executeActionStack();
    _checkIsPlaying();

    return changedNodes.whereType<Media>().toSet();
  }

  void _updateTimedNodesClock(int incrementMs) {
    final targetTime = virtualClock + incrementMs;
    if (targetTime < virtualClock) return;

    int delta = targetTime - virtualClock;
    if (delta > 0) {
      for (var node in _timedNodes) {
        if (node.getMainState() == State.OCCURRING) {
          int t1 = node.time;
          int t2 = t1 + delta;
          node.time = t2;

          for (var area in node.getAreas()) {
            final beginMs = _parseTimeMs(area.begin);
            final endMs = _parseTimeMs(area.end);

            if (beginMs != null) {
              if (t1 < beginMs && t2 >= beginMs) {
                _stackAction(
                  node.getAreaEvent(area.id ?? ''),
                  ActionType.START,
                );
              }
            }
            if (endMs != null) {
              if (t1 < endMs && t2 >= endMs) {
                _stackAction(node.getAreaEvent(area.id ?? ''), ActionType.STOP);
              }
            }
          }

          final limit = node.explicitDurMs;
          if (limit != null && t2 >= limit) {
            _logger.info(
              '[Clock: ${(targetTime / 1000).toStringAsFixed(3)}s] Node "${node.id}" reached duration limit (${limit}ms)',
            );
            _stackMainEvtAction(node, ActionType.STOP);
          }
        }
      }
      virtualClock = targetTime;
    }
  }

  Set<Node> _executeActionStack() {
    final changedNodes = <Node>{};
    while (_actionStack.isNotEmpty) {
      final actionItem = _actionStack.removeAt(0);
      if (actionItem.action == ActionType.SET) {
        if (actionItem.value.isNotEmpty &&
            actionItem.event.propertyName != null) {
          actionItem.event.targetNode.setPropertyValue(
            actionItem.event.propertyName!,
            actionItem.value,
          );
          final referId = actionItem.event.targetNode.rawAttributes['refer'];
          if (referId != null) {
            final refNode = getNodeById(referId);
            if (refNode != null) {
              refNode.setPropertyValue(
                actionItem.event.propertyName!,
                actionItem.value,
              );
              changedNodes.add(refNode);
            }
          }
        }
        final prevState = actionItem.event.state;
        actionItem.event.state = State.SLEEPING;
        if (prevState != State.SLEEPING) {
          _triggerLinks(
            actionItem.event.targetNode.id,
            State.SLEEPING,
            actionItem.event.propertyName,
          );
        }
        changedNodes.add(actionItem.event.targetNode);
        continue;
      }
      final prevState = actionItem.event.state;
      actionItem.event.doAction(actionItem.action);
      final newState = actionItem.event.state;
      if (newState != prevState) {
        final nodeId = actionItem.event.targetNode.id;
        final interfaceId = actionItem.event.interfaceId;
        _logger.info(
          '[Clock: ${(virtualClock / 1000).toStringAsFixed(3)}s] Node "$nodeId"${interfaceId != null ? ' (area $interfaceId)' : ''} changed state: ${Event.getEventStateAsString(prevState)} -> ${Event.getEventStateAsString(newState)}',
        );

        _triggerLinks(nodeId, newState, interfaceId);
        changedNodes.add(actionItem.event.targetNode);

        if (actionItem.event.isMain) {
          if (newState == State.OCCURRING) {
            actionItem.event.targetNode.time = 0;
            if (actionItem.event.targetNode is Context) {
              if ((actionItem.event.targetNode as Context).activeNodes == 0) {
                _stackPorts(actionItem.event.targetNode as Context);
              }
            }
          } else if (newState == State.SLEEPING) {
            for (var area in actionItem.event.targetNode.getAreas()) {
              final areaEvt = actionItem.event.targetNode.getAreaEvent(
                area.id ?? '',
              );
              if (areaEvt.state != State.SLEEPING) {
                _stackAction(areaEvt, ActionType.STOP);
              }
            }
          }

          final parent = actionItem.event.targetNode.parent;
          if (parent is Composition) {
            if (newState == State.OCCURRING) {
              if (parent.getMainState() == State.SLEEPING) {
                _stackMainEvtAction(parent, ActionType.START);
              }
              parent.activeNodes++;
            } else if (newState == State.SLEEPING) {
              if (parent.activeNodes > 0) parent.activeNodes--;
              if (parent.activeNodes == 0) {
                _stackMainEvtAction(parent, ActionType.STOP);
              }
            }
          }
        }
      }
    }
    return changedNodes;
  }

  void _checkIsPlaying() {
    if (_actionStack.isEmpty &&
        _delayedActions.isEmpty &&
        _body.getMainState() == State.SLEEPING) {
      isPlaying = false;
    }
  }

  bool _evaluateCondition(Element cond, Link link) {
    if (cond.xmlTagName == 'simpleCondition') {
      return true;
    }
    if (cond.xmlTagName == 'assessmentStatement') {
      return _evaluateAssessment(cond, link);
    }
    if (cond.xmlTagName == 'compoundCondition') {
      final operator = cond.rawAttributes['operator'] ?? 'and';
      final results = cond.children
          .map((c) => _evaluateCondition(c, link))
          .toList();
      if (results.isEmpty) return true;
      if (operator == 'or') {
        return results.any((r) => r);
      } else {
        return results.every((r) => r);
      }
    }
    return true;
  }

  bool _evaluateAssessment(Element assessment, Link link) {
    final attrAssess = assessment.children
        .where((c) => c.xmlTagName == 'attributeAssessment')
        .firstOrNull;
    final valueAssess = assessment.children
        .where((c) => c.xmlTagName == 'valueAssessment')
        .firstOrNull;
    if (attrAssess == null || valueAssess == null) return true;

    final role = attrAssess.rawAttributes['role'];
    final comparator = assessment.rawAttributes['comparator'] ?? 'eq';
    final targetValue = valueAssess.rawAttributes['value'] ?? '';

    final bind = link.children
        .whereType<Bind>()
        .where((b) => b.role == role)
        .firstOrNull;
    if (bind == null || bind.component == null) return false;

    final targetNode = getNodeById(bind.component!);
    if (targetNode == null) return false;

    String currentValue = '';
    final isProperty =
        attrAssess.rawAttributes['attributeType'] == 'nodeProperty';
    if (isProperty && bind.interface != null) {
      currentValue = getPropertyValue(targetNode, bind.interface!) ?? '';
    } else {
      currentValue = Event.getEventStateAsString(
        targetNode.getMainState(),
      ).toLowerCase();
    }

    if (comparator == 'eq') {
      return currentValue.toLowerCase() == targetValue.toLowerCase();
    } else if (comparator == 'ne') {
      return currentValue.toLowerCase() != targetValue.toLowerCase();
    }
    return false;
  }

  void _triggerLinks(String? targetId, State newState, [String? interfaceId]) {
    if (targetId == null) return;
    final node = getNodeById(targetId);
    if (node == null) return;

    final context = node.parent;
    final links = context is Context ? context.getLinks() : _body.getLinks();

    for (var link in links) {
      bool triggered = false;
      if (newState == State.OCCURRING) {
        triggered = link.children.whereType<Bind>().any(
          (b) =>
              b.role == 'onBegin' &&
              b.component == targetId &&
              b.interface == interfaceId,
        );
      } else if (newState == State.SLEEPING) {
        triggered = link.children.whereType<Bind>().any(
          (b) =>
              b.role == 'onEnd' &&
              b.component == targetId &&
              b.interface == interfaceId,
        );
      }

      if (triggered) {
        final xconn = link.rawAttributes['xconnector'];
        if (xconn != null) {
          final connId = xconn.contains('#') ? xconn.split('#')[1] : xconn;
          final connector = getConnectorById(connId);
          if (connector != null) {
            final cond = connector.children.firstWhere(
              (c) =>
                  c.xmlTagName == 'compoundCondition' ||
                  c.xmlTagName == 'simpleCondition' ||
                  c.xmlTagName == 'assessmentStatement',
              orElse: () => null as dynamic,
            );
            if (!_evaluateCondition(cond, link)) {
              triggered = false;
            }
          }
        }
      }

      if (triggered) {
        for (var bind in link.children.whereType<Bind>()) {
          final actionStr = bind.role;
          if (actionStr != null &&
              (actionStr == 'start' ||
                  actionStr == 'stop' ||
                  actionStr == 'abort' ||
                  actionStr == 'pause' ||
                  actionStr == 'resume' ||
                  actionStr == 'set')) {
            if (bind.component != null) {
              final bindNode = getNodeById(bind.component!);
              if (bindNode != null) {
                final actionType = Event.getStringAsActionType(actionStr);
                var targetEvent = actionType == ActionType.SET
                    ? bindNode.getPropertyEvent(bind.interface ?? '')
                    : bindNode.getMainEvent();

                if (actionType != ActionType.SET &&
                    bindNode is Context &&
                    bind.interface != null) {
                  final ports = bindNode.children.whereType<Port>().where(
                    (p) => p.id == bind.interface,
                  );
                  if (ports.isNotEmpty) {
                    final port = ports.first;
                    if (port.component != null) {
                      final targetNode = getNodeById(port.component!);
                      if (targetNode != null) {
                        targetEvent = targetNode.getMainEvent();
                      }
                    }
                  }
                }

                if (actionType != ActionType.SET && bindNode is Switch) {
                  final activeNode = resolveSwitch(bindNode);
                  if (activeNode != null) {
                    targetEvent = activeNode.getMainEvent();
                  }
                }

                int delayMs = 0;
                int durationMs = 0;
                for (var child in bind.children) {
                  if (child is BindParam) {
                    if (child.name == 'delay') {
                      delayMs = _parseTimeMs(child.value) ?? 0;
                    } else if (child.name == 'duration') {
                      durationMs = _parseTimeMs(child.value) ?? 0;
                    }
                  }
                }
                if (delayMs == 0) {
                  for (var child in link.children) {
                    if (child is BindParam) {
                      if (child.name == 'delay') {
                        delayMs = _parseTimeMs(child.value) ?? 0;
                      } else if (child.name == 'duration') {
                        durationMs = _parseTimeMs(child.value) ?? 0;
                      }
                    }
                  }
                }
                String? setValue;
                if (actionType == ActionType.SET) {
                  for (var child in bind.children) {
                    if (child is BindParam &&
                        (child.name == 'value' || child.name == 'var')) {
                      setValue = child.value;
                      break;
                    }
                  }
                  if (setValue == null &&
                      bind.rawAttributes.containsKey('value')) {
                    setValue = bind.rawAttributes['value'];
                  }
                  if (setValue == null) {
                    for (var child in link.children) {
                      if (child is BindParam &&
                          (child.name == 'value' || child.name == 'var')) {
                        setValue = child.value;
                        break;
                      }
                    }
                  }
                }
                if (actionType == ActionType.SET && durationMs > 0) {
                  _stackAction(targetEvent, ActionType.START, delay: delayMs);
                  _stackAction(
                    targetEvent,
                    ActionType.SET,
                    delay: delayMs + durationMs,
                    value: setValue,
                  );
                } else {
                  _stackAction(
                    targetEvent,
                    actionType,
                    delay: delayMs,
                    value: setValue,
                  );
                }
              }
            }
          }
        }
      }
    }

    if (context is Context && context != _body) {
      for (var port in context.children.whereType<Port>()) {
        if (port.component == targetId &&
            (port.interface == interfaceId ||
                (interfaceId == null && port.interface == null))) {
          _triggerLinks(context.id, newState, port.id);
        }
      }
    }

    if (context is Switch) {
      for (var switchPort in context.children.where(
        (c) => c.xmlTagName == 'switchPort',
      )) {
        final hasMapping = switchPort.children
            .where((m) => m.xmlTagName == 'mapping')
            .any((m) => m.rawAttributes['component'] == targetId);
        if (hasMapping) {
          _triggerLinks(context.id, newState, switchPort.id);
        }
      }
    }

    final referringNodes = <Node>[];
    void findReferring(Element el) {
      if (el is Node && el.rawAttributes['refer'] == targetId) {
        referringNodes.add(el);
      }
      for (var child in el.children) {
        findReferring(child);
      }
    }

    findReferring(_body);

    for (var refNode in referringNodes) {
      _triggerLinks(refNode.id, newState, interfaceId);
    }
  }

  void triggerSelection(String componentId, String keyCode) {
    _triggerSelectionInternal(componentId, keyCode, null);
  }

  void _triggerSelectionInternal(
    String componentId,
    String keyCode, [
    String? interfaceId,
  ]) {
    final node = getNodeById(componentId);
    if (node == null || node.getMainState() != State.OCCURRING) return;

    final context = node.parent;
    final links = context is Context ? context.getLinks() : _body.getLinks();

    for (var link in links) {
      bool triggered = false;
      triggered = link.children.whereType<Bind>().any((b) {
        if ((b.role == 'onSelection' || b.role == 'onSelect') &&
            b.component == componentId &&
            (b.interface == interfaceId ||
                (interfaceId == null && b.interface == null))) {
          final hasKeyParam =
              b.children.whereType<BindParam>().any(
                (bp) => bp.name == 'keyCode' || bp.name == 'key',
              ) ||
              link.children.whereType<BindParam>().any(
                (bp) => bp.name == 'keyCode' || bp.name == 'key',
              );
          if (!hasKeyParam) {
            return true;
          }
          bool keyMatches = b.children.whereType<BindParam>().any(
            (bp) =>
                (bp.name == 'keyCode' || bp.name == 'key') &&
                bp.value == keyCode,
          );
          if (!keyMatches) {
            keyMatches = link.children.whereType<BindParam>().any(
              (bp) =>
                  (bp.name == 'keyCode' || bp.name == 'key') &&
                  bp.value == keyCode,
            );
          }
          return keyMatches;
        }
        return false;
      });

      if (triggered) {
        final xconn = link.rawAttributes['xconnector'];
        if (xconn != null) {
          final connId = xconn.contains('#') ? xconn.split('#')[1] : xconn;
          final connector = getConnectorById(connId);
          if (connector != null) {
            final cond = connector.children.firstWhere(
              (c) =>
                  c.xmlTagName == 'compoundCondition' ||
                  c.xmlTagName == 'simpleCondition' ||
                  c.xmlTagName == 'assessmentStatement',
              orElse: () => null as dynamic,
            );
            if (!_evaluateCondition(cond, link)) {
              triggered = false;
            }
          }
        }
      }

      if (triggered) {
        for (var bind in link.children.whereType<Bind>()) {
          final actionStr = bind.role;
          if (actionStr != null &&
              (actionStr == 'start' ||
                  actionStr == 'stop' ||
                  actionStr == 'abort' ||
                  actionStr == 'pause' ||
                  actionStr == 'resume' ||
                  actionStr == 'set')) {
            if (bind.component != null) {
              final bindNode = getNodeById(bind.component!);
              if (bindNode != null) {
                final actionType = Event.getStringAsActionType(actionStr);

                var targetEvent = actionType == ActionType.SET
                    ? bindNode.getPropertyEvent(bind.interface ?? '')
                    : bindNode.getMainEvent();

                if (actionType != ActionType.SET &&
                    bindNode is Context &&
                    bind.interface != null) {
                  final ports = bindNode.children.whereType<Port>().where(
                    (p) => p.id == bind.interface,
                  );
                  if (ports.isNotEmpty) {
                    final port = ports.first;
                    if (port.component != null) {
                      final targetNode = getNodeById(port.component!);
                      if (targetNode != null) {
                        targetEvent = targetNode.getMainEvent();
                      }
                    }
                  }
                }

                if (actionType != ActionType.SET && bindNode is Switch) {
                  final activeNode = resolveSwitch(bindNode);
                  if (activeNode != null) {
                    targetEvent = activeNode.getMainEvent();
                  }
                }

                int delayMs = 0;
                int durationMs = 0;
                for (var child in bind.children) {
                  if (child is BindParam) {
                    if (child.name == 'delay') {
                      delayMs = _parseTimeMs(child.value) ?? 0;
                    } else if (child.name == 'duration') {
                      durationMs = _parseTimeMs(child.value) ?? 0;
                    }
                  }
                }
                if (delayMs == 0) {
                  for (var child in link.children) {
                    if (child is BindParam) {
                      if (child.name == 'delay') {
                        delayMs = _parseTimeMs(child.value) ?? 0;
                      } else if (child.name == 'duration') {
                        durationMs = _parseTimeMs(child.value) ?? 0;
                      }
                    }
                  }
                }
                String? setValue;
                if (actionType == ActionType.SET) {
                  for (var child in bind.children) {
                    if (child is BindParam &&
                        (child.name == 'value' || child.name == 'var')) {
                      setValue = child.value;
                      break;
                    }
                  }
                  if (setValue == null &&
                      bind.rawAttributes.containsKey('value')) {
                    setValue = bind.rawAttributes['value'];
                  }
                  if (setValue == null) {
                    for (var child in link.children) {
                      if (child is BindParam &&
                          (child.name == 'value' || child.name == 'var')) {
                        setValue = child.value;
                        break;
                      }
                    }
                  }
                }
                if (actionType == ActionType.SET && durationMs > 0) {
                  _stackAction(targetEvent, ActionType.START, delay: delayMs);
                  _stackAction(
                    targetEvent,
                    ActionType.SET,
                    delay: delayMs + durationMs,
                    value: setValue,
                  );
                } else {
                  _stackAction(
                    targetEvent,
                    actionType,
                    delay: delayMs,
                    value: setValue,
                  );
                }
              }
            }
          }
        }
      }
    }

    if (context is Context && context != _body) {
      for (var port in context.children.whereType<Port>()) {
        if (port.component == componentId &&
            (port.interface == interfaceId ||
                (interfaceId == null && port.interface == null))) {
          _triggerSelectionInternal(context.id ?? '', keyCode, port.id);
        }
      }
    }
  }

  void _stackMainEvtAction(Node node, ActionType actionType, {int delay = 0}) {
    _stackAction(node.getMainEvent(), actionType, delay: delay);
  }

  void _stackAction(
    Event event,
    ActionType actionType, {
    int delay = 0,
    String? value,
  }) {
    final action = Action(
      event: event,
      action: actionType,
      delay: delay,
      value: value ?? '',
    );
    if (delay > 0) {
      _delayedActions.add((action: action, executeTime: virtualClock + delay));
    } else {
      _actionStack.add(action);
    }
  }

  void _processDelayedActions() {
    final ready = <Action>[];
    _delayedActions.removeWhere((item) {
      if (virtualClock >= item.executeTime) {
        ready.add(item.action);
        return true;
      }
      return false;
    });
    _actionStack.addAll(ready);
  }

  void start() {
    _logger.info('[Clock: ${virtualClock / 1000}s] NCLDocument will start');
    _init();
    isPlaying = true;
    tick();
  }

  void tickIndefinitely({int ticksPerSecond = 10, void Function()? onStop}) {
    if (!isPlaying) {
      onStop?.call();
      return;
    }
    _logger.info(
      '[Clock: ${virtualClock / 1000}s] NCLDocument will tick indefinitely at $ticksPerSecond ticks per second',
    );
    final interval = Duration(milliseconds: 1000 ~/ ticksPerSecond);
    Timer.periodic(interval, (timer) {
      if (!isPlaying) {
        timer.cancel();
        onStop?.call();
        return;
      }
      tick(interval.inMilliseconds);
      _logger.info('[Clock: ${virtualClock / 1000}s] Tick');
    });
  }

  void stop() {
    _logger.info('[Clock: ${virtualClock / 1000}s] NCLDocument will stop');
    _delayedActions.clear();

    void stopNode(Node node) {
      if (node.getMainState() == State.OCCURRING ||
          node.getMainState() == State.PAUSED) {
        if (node is Composition) {
          for (var child in node.getNodes()) {
            stopNode(child);
          }
        }
        node.getMainEvent().doAction(ActionType.STOP);
      }
    }

    stopNode(_body);
  }

  int? _parseTimeMs(String? timeStr) {
    if (timeStr == null) return null;
    if (timeStr.endsWith('ms')) {
      return int.tryParse(timeStr.replaceAll('ms', ''));
    } else if (timeStr.endsWith('s')) {
      final s = double.tryParse(timeStr.replaceAll('s', ''));
      if (s != null) {
        return (s * 1000).toInt();
      }
    }
    return int.tryParse(timeStr);
  }
}
