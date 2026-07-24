import 'elements.dart';

enum State { OCCURRING, PAUSED, SLEEPING }

enum EventType { PRESENTATION, ATTRIBUTION, SELECTION, PREPARATION }

enum ActionType { ABORT, PAUSE, RESUME, START, STOP, SET }

class Event {
  final EventType type;
  final Node targetNode;
  final String? propertyName;
  final String? interfaceId;
  final bool isMain;
  State state = State.SLEEPING;

  Event({
    required this.type,
    required this.targetNode,
    this.propertyName,
    this.interfaceId,
    this.isMain = false,
  });

  State doAction(ActionType action) {
    switch (action) {
      case ActionType.START:
        if (state == State.SLEEPING) state = State.OCCURRING;
        break;
      case ActionType.STOP:
      case ActionType.ABORT:
        if (state == State.OCCURRING || state == State.PAUSED) {
          state = State.SLEEPING;
        }
        break;
      case ActionType.PAUSE:
        if (state == State.OCCURRING) state = State.PAUSED;
        break;
      case ActionType.RESUME:
        if (state == State.PAUSED) state = State.OCCURRING;
        break;
      case ActionType.SET:
        break;
    }
    return state;
  }

  static ActionType getStringAsActionType(String str) {
    switch (str.toLowerCase()) {
      case 'start':
        return ActionType.START;
      case 'stop':
        return ActionType.STOP;
      case 'abort':
        return ActionType.ABORT;
      case 'pause':
        return ActionType.PAUSE;
      case 'resume':
        return ActionType.RESUME;
      case 'set':
        return ActionType.SET;
      default:
        throw ArgumentError('Unknown action string: $str');
    }
  }

  static String getEventStateAsString(State state) {
    switch (state) {
      case State.SLEEPING:
        return 'sleeping';
      case State.OCCURRING:
        return 'occurring';
      case State.PAUSED:
        return 'paused';
    }
  }

  static String getEventTypeAsString(EventType type) {
    switch (type) {
      case EventType.PRESENTATION:
        return 'presentation';
      case EventType.ATTRIBUTION:
        return 'attribution';
      case EventType.SELECTION:
        return 'selection';
      case EventType.PREPARATION:
        return 'preparation';
    }
  }
}

class Action {
  final Event event;
  final ActionType action;
  final String value;
  final int duration;
  final int delay;

  Action({
    required this.event,
    required this.action,
    this.value = '',
    this.duration = 0,
    this.delay = 0,
  });
}
