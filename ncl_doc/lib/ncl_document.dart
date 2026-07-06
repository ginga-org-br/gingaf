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
  final List<Action> _actionStack = [];
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
  void doNclEditingCommand(String command) {
    NCLParser(baseURI: baseURI).doNclEditingCommand(this, command);
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

  Head? getHead() => _head;
  Context getBody() => _body;
  State getBodyState() => _body.getMainState();

  Settings getSettings() => _settings;

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
              _stackPorts(actionItem.event.targetNode as Context);
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
          if (parent is Context) {
            if (newState == State.OCCURRING) {
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
    if (_actionStack.isEmpty && _body.getMainState() == State.SLEEPING) {
      isPlaying = false;
    }
  }

  void _triggerLinks(String? targetId, State newState, [String? interfaceId]) {
    if (targetId == null) return;
    final node = getNodeById(targetId);
    final context = node?.parent;

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
