import 'elements.dart';

enum NCLState { OCCURRING, PAUSED, SLEEPING }

enum NCLEvent { PRESENTATION, ATTRIBUTION, SELECTION, PREPARATION }

enum NCLAction { ABORT, PAUSE, RESUME, START, STOP, SET }

class Event {
  final NCLEvent type;
  final Node targetNode;
  final String? propertyName;
  final String? interfaceId;
  final bool isMain;
  NCLState state = NCLState.SLEEPING;

  Event({
    required this.type,
    required this.targetNode,
    this.propertyName,
    this.interfaceId,
    this.isMain = false,
  });

  NCLState doAction(NCLAction action) {
    switch (action) {
      case NCLAction.START:
        if (state == NCLState.SLEEPING) state = NCLState.OCCURRING;
        break;
      case NCLAction.STOP:
      case NCLAction.ABORT:
        if (state == NCLState.OCCURRING || state == NCLState.PAUSED) {
          state = NCLState.SLEEPING;
        }
        break;
      case NCLAction.PAUSE:
        if (state == NCLState.OCCURRING) state = NCLState.PAUSED;
        break;
      case NCLAction.RESUME:
        if (state == NCLState.PAUSED) state = NCLState.OCCURRING;
        break;
      case NCLAction.SET:
        break;
    }
    return state;
  }

  static NCLAction getStringAsActionType(String str) {
    switch (str.toLowerCase()) {
      case 'start':
        return NCLAction.START;
      case 'stop':
        return NCLAction.STOP;
      case 'abort':
        return NCLAction.ABORT;
      case 'pause':
        return NCLAction.PAUSE;
      case 'resume':
        return NCLAction.RESUME;
      case 'set':
        return NCLAction.SET;
      default:
        throw ArgumentError('Unknown action string: $str');
    }
  }

  static String getEventStateAsString(NCLState state) {
    switch (state) {
      case NCLState.SLEEPING:
        return 'sleeping';
      case NCLState.OCCURRING:
        return 'occurring';
      case NCLState.PAUSED:
        return 'paused';
    }
  }

  static String getEventTypeAsString(NCLEvent type) {
    switch (type) {
      case NCLEvent.PRESENTATION:
        return 'presentation';
      case NCLEvent.ATTRIBUTION:
        return 'attribution';
      case NCLEvent.SELECTION:
        return 'selection';
      case NCLEvent.PREPARATION:
        return 'preparation';
    }
  }
}

class Action {
  final Event event;
  final NCLAction action;
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
