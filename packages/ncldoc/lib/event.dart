import 'elements.dart';

enum NclStateType { occurring, paused, sleeping }

enum NclEventType { presentation, attribution, selection, preparation }

enum NclActionType { abort, pause, resume, start, stop, set }

class NclEvent {
  final NclEventType type;
  final Node targetNode;
  final String? propertyName;
  final String? interfaceId;
  final bool isMain;
  NclStateType state = NclStateType.sleeping;

  NclEvent({
    required this.type,
    required this.targetNode,
    this.propertyName,
    this.interfaceId,
    this.isMain = false,
  });

  NclStateType doNclAction(NclActionType action) {
    switch (action) {
      case NclActionType.start:
        if (state == NclStateType.sleeping) state = NclStateType.occurring;
        break;
      case NclActionType.stop:
      case NclActionType.abort:
        if (state == NclStateType.occurring || state == NclStateType.paused) {
          state = NclStateType.sleeping;
        }
        break;
      case NclActionType.pause:
        if (state == NclStateType.occurring) state = NclStateType.paused;
        break;
      case NclActionType.resume:
        if (state == NclStateType.paused) state = NclStateType.occurring;
        break;
      case NclActionType.set:
        break;
    }
    return state;
  }

  static NclActionType getStringAsActionType(String str) {
    switch (str.toLowerCase()) {
      case 'start':
        return NclActionType.start;
      case 'stop':
        return NclActionType.stop;
      case 'abort':
        return NclActionType.abort;
      case 'pause':
        return NclActionType.pause;
      case 'resume':
        return NclActionType.resume;
      case 'set':
        return NclActionType.set;
      default:
        throw ArgumentError('Unknown action string: $str');
    }
  }

  static String getNclEventStateAsString(NclStateType state) {
    switch (state) {
      case NclStateType.sleeping:
        return 'sleeping';
      case NclStateType.occurring:
        return 'occurring';
      case NclStateType.paused:
        return 'paused';
    }
  }

  static String getEventTypeAsString(NclEventType type) {
    switch (type) {
      case NclEventType.presentation:
        return 'presentation';
      case NclEventType.attribution:
        return 'attribution';
      case NclEventType.selection:
        return 'selection';
      case NclEventType.preparation:
        return 'preparation';
    }
  }
}

class NclAction {
  final NclEvent event;
  final NclActionType action;
  final String value;
  final int duration;
  final int delay;

  NclAction({
    required this.event,
    required this.action,
    this.value = '',
    this.duration = 0,
    this.delay = 0,
  });
}
