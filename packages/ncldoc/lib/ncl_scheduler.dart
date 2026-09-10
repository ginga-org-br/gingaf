import 'dart:async';

import 'package:logging/logging.dart';

import 'ncl_document.dart';

final _logger = Logger('ncl_doc');

class NclScheduler {
  final NclDocument document;
  final Map<String, String> systemVariables = {'system.language': 'por'};
  int virtualClock = 0;
  bool isPlaying = false;
  final List<NclAction> _actionStack = [];
  final List<({NclAction action, int executeTime})> _delayedNclActions = [];
  final List<NclAction> uiQueue = [];
  final List<Node> _timedNodes = [];

  NclScheduler(this.document);

  void _init() {
    _gatherTimedNodes();
    _stackMainEvtNclAction(document.body, NclActionType.start);
    _stackPorts(document.body);
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

    gather(document.body);
  }

  void _stackPorts(Context comp) {
    for (var port in comp.getPorts()) {
      if (port.component != null) {
        final node = document.getNodeById(port.component!);
        if (node != null) {
          _stackMainEvtNclAction(node, NclActionType.start);
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
    _processDelayedNclActions();
    final changedNodes = _executeNclActionStack();
    _checkIsPlaying();

    if (document.currentFocusNodeId == null ||
        document.getNodeById(document.currentFocusNodeId!)?.getMainState() !=
            NclStateType.occurring) {
      document.moveFocus('NONE');
    }

    return changedNodes.whereType<Media>().toSet();
  }

  void _updateTimedNodesClock(int incrementMs) {
    final targetTime = virtualClock + incrementMs;
    if (targetTime < virtualClock) return;

    int delta = targetTime - virtualClock;
    if (delta > 0) {
      for (var node in _timedNodes) {
        if (node.getMainState() == NclStateType.occurring) {
          int t1 = node.time;
          int t2 = t1 + delta;
          node.time = t2;

          for (var area in node.getAreas()) {
            final beginMs = _parseTimeMs(area.begin);
            final endMs = _parseTimeMs(area.end);

            if (beginMs != null) {
              if (t1 < beginMs && t2 >= beginMs) {
                _stackNclAction(node.getAreaNclEvent(area.id ?? ''), NclActionType.start);
              }
            }
            if (endMs != null) {
              if (t1 < endMs && t2 >= endMs) {
                _stackNclAction(node.getAreaNclEvent(area.id ?? ''), NclActionType.stop);
              }
            }
          }

          final limit = node.explicitDurMs;
          if (limit != null && t2 >= limit) {
            _logger.info(
              '[Clock: ${(targetTime / 1000).toStringAsFixed(3)}s] Node "${node.id}" reached duration limit (${limit}ms)',
            );
            _stackMainEvtNclAction(node, NclActionType.stop);
          }
        }
      }
      virtualClock = targetTime;
    }
  }

  Set<Node> _executeNclActionStack() {
    final changedNodes = <Node>{};
    while (_actionStack.isNotEmpty) {
      final actionItem = _actionStack.removeAt(0);
      if (actionItem.action == NclActionType.set) {
        if (actionItem.value.isNotEmpty &&
            actionItem.event.propertyName != null) {
          actionItem.event.targetNode.setPropertyValue(
            actionItem.event.propertyName!,
            actionItem.value,
          );
          final propName = actionItem.event.propertyName!;
          if (propName == 'service.currentFocus') {
            document.setFocus(actionItem.value);
          } else if (propName.startsWith('service.') ||
              propName.startsWith('system.')) {
            document.envVariables[propName] = actionItem.value;
          }
          final referId = actionItem.event.targetNode.rawAttributes['refer'];
          if (referId != null) {
            final refNode = document.getNodeById(referId);
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
        actionItem.event.state = NclStateType.sleeping;
        if (prevState != NclStateType.sleeping) {
          _triggerLinks(
            actionItem.event.targetNode.id,
            NclStateType.sleeping,
            actionItem.event.propertyName,
          );
        }
        changedNodes.add(actionItem.event.targetNode);
        continue;
      }
      final prevState = actionItem.event.state;
      actionItem.event.doNclAction(actionItem.action);
      final newState = actionItem.event.state;
      if (newState != prevState) {
        final nodeId = actionItem.event.targetNode.id;
        final interfaceId = actionItem.event.interfaceId;
        _logger.info(
          '[Clock: ${(virtualClock / 1000).toStringAsFixed(3)}s] Node "$nodeId"${interfaceId != null ? ' (area $interfaceId)' : ''} changed state: ${NclEvent.getNclEventStateAsString(prevState)} -> ${NclEvent.getNclEventStateAsString(newState)}',
        );

        _triggerLinks(nodeId, newState, interfaceId);
        changedNodes.add(actionItem.event.targetNode);

        if (actionItem.event.isMain) {
          if (newState == NclStateType.occurring) {
            actionItem.event.targetNode.time = 0;
            if (actionItem.event.targetNode is Context) {
              if ((actionItem.event.targetNode as Context).activeNodes == 0) {
                _stackPorts(actionItem.event.targetNode as Context);
              }
            }
            if (actionItem.event.targetNode is Switch) {
              final activeNode = document.resolveSwitch(
                actionItem.event.targetNode as Switch,
              );
              if (activeNode != null) {
                _stackMainEvtNclAction(activeNode, NclActionType.start);
              }
            }
          } else if (newState == NclStateType.sleeping) {
            for (var area in actionItem.event.targetNode.getAreas()) {
              final areaEvt = actionItem.event.targetNode.getAreaNclEvent(
                area.id ?? '',
              );
              if (areaEvt.state != NclStateType.sleeping) {
                _stackNclAction(areaEvt, NclActionType.stop);
              }
            }
            if (actionItem.event.targetNode is Switch) {
              for (var child
                  in (actionItem.event.targetNode as Switch).children) {
                if (child is Node &&
                    child.getMainState() != NclStateType.sleeping) {
                  _stackMainEvtNclAction(child, NclActionType.stop);
                }
              }
            }
          }

          final parent = actionItem.event.targetNode.parent;
          if (parent is Context) {
            if (newState == NclStateType.occurring) {
              if (parent.getMainState() == NclStateType.sleeping) {
                _stackMainEvtNclAction(parent, NclActionType.start);
              }
              parent.activeNodes++;
            } else if (newState == NclStateType.sleeping) {
              if (parent.activeNodes > 0) parent.activeNodes--;
              if (parent.activeNodes == 0) {
                _stackMainEvtNclAction(parent, NclActionType.stop);
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
        _delayedNclActions.isEmpty &&
        document.body.getMainState() == NclStateType.sleeping) {
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
      final results =
          cond.children.map((c) => _evaluateCondition(c, link)).toList();
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
    var targetValue = valueAssess.rawAttributes['value'] ?? '';

    if (targetValue.startsWith('\$')) {
      final paramName = targetValue.substring(1);
      final bindParam = link.children
          .whereType<BindParam>()
          .where((bp) => bp.name == paramName)
          .firstOrNull;
      if (bindParam != null && bindParam.value != null) {
        targetValue = bindParam.value!;
      } else {
        final paramEl = link.children
            .where((c) => c.rawAttributes['name'] == paramName)
            .firstOrNull;
        if (paramEl != null && paramEl.rawAttributes['value'] != null) {
          targetValue = paramEl.rawAttributes['value']!;
        }
      }
    }

    final bind = link.children
        .whereType<Bind>()
        .where((b) => b.role == role)
        .firstOrNull;
    if (bind == null || bind.component == null) return false;

    final targetNode = document.getNodeById(bind.component!);
    if (targetNode == null) return false;

    String currentValue = '';
    final isProperty =
        attrAssess.rawAttributes['attributeType'] == 'nodeProperty';
    if (isProperty && bind.interface != null) {
      currentValue =
          document.getPropertyValue(targetNode, bind.interface!) ?? '';
    } else {
      currentValue = NclEvent.getNclEventStateAsString(
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

  void _triggerLinks(
    String? targetId,
    NclStateType newState, [
    String? interfaceId,
  ]) {
    if (targetId == null) return;
    final node = document.getNodeById(targetId);
    if (node == null) return;

    final context = node.parent;
    final links =
        context is Context ? context.getLinks() : document.body.getLinks();

    for (var link in links) {
      bool triggered = false;
      if (newState == NclStateType.occurring) {
        triggered = link.children.whereType<Bind>().any(
              (b) =>
                  b.role == 'onBegin' &&
                  b.component == targetId &&
                  b.interface == interfaceId,
            );
      } else if (newState == NclStateType.sleeping) {
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
          final connector = document.getElementById(connId);
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
              final bindNode = document.getNodeById(bind.component!);
              if (bindNode != null) {
                final actionType = NclEvent.getStringAsActionType(actionStr);
                var targetNclEvent = actionType == NclActionType.set
                    ? bindNode.getPropertyNclEvent(bind.interface ?? '')
                    : bindNode.getMainNclEvent();

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

                if (actionType != NclActionType.set &&
                    bindNode is Context &&
                    bind.interface != null) {
                  final ports = bindNode.children.whereType<Port>().where(
                        (p) => p.id == bind.interface,
                      );
                  if (ports.isNotEmpty) {
                    final port = ports.first;
                    if (port.component != null) {
                      final targetNode = document.getNodeById(port.component!);
                      if (targetNode != null) {
                        targetNclEvent = targetNode.getMainNclEvent();
                      }
                    }
                  }
                }

                if (actionType != NclActionType.set && bindNode is Switch) {
                  if (actionType == NclActionType.stop) {
                    for (var child in bindNode.children) {
                      if (child is Node &&
                          child.getMainState() != NclStateType.sleeping) {
                        _stackNclAction(
                          child.getMainNclEvent(),
                          NclActionType.stop,
                          delay: delayMs,
                        );
                      }
                    }
                    continue;
                  } else {
                    final activeNode = document.resolveSwitch(bindNode);
                    if (activeNode != null) {
                      targetNclEvent = activeNode.getMainNclEvent();
                    }
                  }
                }
                String? setValue;
                if (actionType == NclActionType.set) {
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
                if (actionType == NclActionType.set && durationMs > 0) {
                  _stackNclAction(targetNclEvent, NclActionType.start, delay: delayMs);
                  _stackNclAction(
                    targetNclEvent,
                    NclActionType.set,
                    delay: delayMs + durationMs,
                    value: setValue,
                  );
                } else {
                  _stackNclAction(
                    targetNclEvent,
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

    if (context is Context && context != document.body) {
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

    findReferring(document.body);

    for (var refNode in referringNodes) {
      _triggerLinks(refNode.id, newState, interfaceId);
    }
  }

  List<Link> getLinksForComponent(String componentId) {
    final links = <Link>[];
    final node = document.getNodeById(componentId);
    Element? curr = node?.parent;
    while (curr != null) {
      if (curr is Context) {
        links.addAll(curr.getLinks());
      }
      curr = curr.parent;
    }
    final bodyLinks = document.body.getLinks();
    for (var l in bodyLinks) {
      if (!links.contains(l)) {
        links.add(l);
      }
    }
    return links;
  }

  void triggerSelection(String componentId, String keyCode) {
    _triggerSelectionInternal(componentId, keyCode, null);
  }

  void _triggerSelectionInternal(
    String componentId,
    String keyCode, [
    String? interfaceId,
  ]) {
    final node = document.getNodeById(componentId);
    if (node == null || node.getMainState() != NclStateType.occurring) return;

    final context = node.parent;
    final links = getLinksForComponent(componentId);

    for (var link in links) {
      bool triggered = false;
      triggered = link.children.whereType<Bind>().any((b) {
        if ((b.role == 'onSelection' || b.role == 'onSelect') &&
            b.component == componentId &&
            (b.interface == interfaceId ||
                (interfaceId == null && b.interface == null))) {
          final hasKeyParam = b.children.whereType<BindParam>().any(
                    (bp) => bp.name == 'keyCode' || bp.name == 'key',
                  ) ||
              link.children.whereType<BindParam>().any(
                    (bp) => bp.name == 'keyCode' || bp.name == 'key',
                  );
          if (!hasKeyParam) {
            return keyCode == 'ENTER' ||
                keyCode == 'OK' ||
                keyCode == 'SELECT' ||
                keyCode.isEmpty;
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
          final connector = document.getElementById(connId);
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
              final bindNode = document.getNodeById(bind.component!);
              if (bindNode != null) {
                final actionType = NclEvent.getStringAsActionType(actionStr);

                var targetNclEvent = actionType == NclActionType.set
                    ? bindNode.getPropertyNclEvent(bind.interface ?? '')
                    : bindNode.getMainNclEvent();

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

                if (actionType != NclActionType.set &&
                    bindNode is Context &&
                    bind.interface != null) {
                  final ports = bindNode.children.whereType<Port>().where(
                        (p) => p.id == bind.interface,
                      );
                  if (ports.isNotEmpty) {
                    final port = ports.first;
                    if (port.component != null) {
                      final targetNode = document.getNodeById(port.component!);
                      if (targetNode != null) {
                        targetNclEvent = targetNode.getMainNclEvent();
                      }
                    }
                  }
                }

                if (actionType != NclActionType.set && bindNode is Switch) {
                  if (actionType == NclActionType.stop) {
                    for (var child in bindNode.children) {
                      if (child is Node &&
                          child.getMainState() != NclStateType.sleeping) {
                        _stackNclAction(
                          child.getMainNclEvent(),
                          NclActionType.stop,
                          delay: delayMs,
                        );
                      }
                    }
                    continue;
                  } else {
                    final activeNode = document.resolveSwitch(bindNode);
                    if (activeNode != null) {
                      targetNclEvent = activeNode.getMainNclEvent();
                    }
                  }
                }
                String? setValue;
                if (actionType == NclActionType.set) {
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
                if (actionType == NclActionType.set && durationMs > 0) {
                  _stackNclAction(targetNclEvent, NclActionType.start, delay: delayMs);
                  _stackNclAction(
                    targetNclEvent,
                    NclActionType.set,
                    delay: delayMs + durationMs,
                    value: setValue,
                  );
                } else {
                  _stackNclAction(
                    targetNclEvent,
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

    if (context is Context && context != document.body) {
      for (var port in context.children.whereType<Port>()) {
        if (port.component == componentId &&
            (port.interface == interfaceId ||
                (interfaceId == null && port.interface == null))) {
          _triggerSelectionInternal(context.id ?? '', keyCode, port.id);
        }
      }
    }
  }

  void _stackMainEvtNclAction(Node node, NclActionType actionType, {int delay = 0}) {
    _stackNclAction(node.getMainNclEvent(), actionType, delay: delay);
  }

  void _stackNclAction(
    NclEvent event,
    NclActionType actionType, {
    int delay = 0,
    String? value,
  }) {
    final action = NclAction(
      event: event,
      action: actionType,
      delay: delay,
      value: value ?? '',
    );
    if (delay > 0) {
      _delayedNclActions.add((action: action, executeTime: virtualClock + delay));
    } else {
      _actionStack.add(action);
    }
  }

  void _processDelayedNclActions() {
    final ready = <NclAction>[];
    _delayedNclActions.removeWhere((item) {
      if (virtualClock >= item.executeTime) {
        ready.add(item.action);
        return true;
      }
      return false;
    });
    _actionStack.addAll(ready);
  }

  void start() {
    _logger.info('[Clock: ${virtualClock / 1000}s] NclDocument will start');
    document.body.getMainNclEvent().doNclAction(NclActionType.start);
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
      '[Clock: ${virtualClock / 1000}s] NclDocument will tick indefinitely at $ticksPerSecond ticks per second',
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
    _logger.info('[Clock: ${virtualClock / 1000}s] NclDocument will stop');
    _delayedNclActions.clear();

    void stopNode(Node node) {
      if (node.getMainState() == NclStateType.occurring ||
          node.getMainState() == NclStateType.paused) {
        if (node is Composition) {
          for (var child in node.getNodes()) {
            stopNode(child);
          }
        }
        node.getMainNclEvent().doNclAction(NclActionType.stop);
      }
    }

    stopNode(document.body);
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
