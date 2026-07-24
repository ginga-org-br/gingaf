import 'package:ncldoc/elements.dart';
import 'package:ncldoc/event.dart';
import 'package:test/test.dart';

void main() {
  group('Node Tests', () {
    test('Media Node can return its properties and areas', () {
      final media = Media(rawAttributes: const {'id': 'video1'});
      final prop = Property(
        rawAttributes: const {'id': 'p1', 'name': 'bounds', 'value': '0,0,100,100'},
      );
      final area = Area(rawAttributes: const {'id': 'a1', 'begin': '10s'});
      media.children.addAll([prop, area]);

      expect(media.getProperties().length, 1);
      expect(media.getProperties().first.name, 'bounds');
      expect(media.getProperties().first.value, '0,0,100,100');

      expect(media.getAreas().length, 1);
      expect(media.getAreas().first.begin, '10s');
    });

    test('Context Node can return its properties and areas', () {
      final context = Context(rawAttributes: const {'id': 'ctx1'});
      final prop = Property(
        rawAttributes: const {'id': 'p1', 'name': 'bounds', 'value': '0,0,100,100'},
      );
      final area = Area(rawAttributes: const {'id': 'a1', 'begin': '10s'});
      context.children.addAll([prop, area]);

      expect(context.getProperties().length, 1);
      expect(context.getProperties().first.name, 'bounds');
      expect(context.getProperties().first.value, '0,0,100,100');

      expect(context.getAreas().length, 1);
      expect(context.getAreas().first.begin, '10s');
    });

    test('getMainEvent on Node returns same Event instance', () {
      final media = Media(rawAttributes: const {'id': 'm1'});
      final event1 = media.getMainEvent();
      final event2 = media.getMainEvent();
      expect(event1, same(event2));
      expect(event1.targetNode.id, 'm1');
      expect(event1.type, EventType.PRESENTATION);
    });

    test('getAreaEventState returns state of the area event', () {
      final media = Media(rawAttributes: const {'id': 'm1'});
      expect(media.getAreaEventState('a1'), State.SLEEPING);
      media.getAreaEvent('a1').state = State.OCCURRING;
      expect(media.getAreaEventState('a1'), State.OCCURRING);
    });

    test('doAction', () {
      final media = Media(rawAttributes: const {'id': 'm1'});
      final event = media.getMainEvent();
      expect(event.state, State.SLEEPING);
      expect(event.doAction(ActionType.START), State.OCCURRING);
      expect(event.state, State.OCCURRING);
      expect(event.doAction(ActionType.PAUSE), State.PAUSED);
      expect(event.state, State.PAUSED);
      expect(event.doAction(ActionType.RESUME), State.OCCURRING);
      expect(event.state, State.OCCURRING);
      expect(event.doAction(ActionType.STOP), State.SLEEPING);
      expect(event.state, State.SLEEPING);
    });

    test(
      'doAction does not change state on invalid transitions from SLEEPING',
      () {
        final media = Media(rawAttributes: const {'id': 'm1'});
        final event = media.getMainEvent();
        expect(event.state, State.SLEEPING);
        expect(event.doAction(ActionType.STOP), State.SLEEPING);
        expect(event.doAction(ActionType.ABORT), State.SLEEPING);
        expect(event.doAction(ActionType.PAUSE), State.SLEEPING);
        expect(event.doAction(ActionType.RESUME), State.SLEEPING);
        expect(event.state, State.SLEEPING);
      },
    );

    test(
      'doAction does not change state on invalid transitions from OCCURRING',
      () {
        final media = Media(rawAttributes: const {'id': 'm1'});
        final event = media.getMainEvent();
        event.doAction(ActionType.START);
        expect(event.state, State.OCCURRING);
        expect(event.doAction(ActionType.START), State.OCCURRING);
        expect(event.doAction(ActionType.RESUME), State.OCCURRING);
        expect(event.state, State.OCCURRING);
      },
    );

    test(
      'doAction does not change state on invalid transitions from PAUSED',
      () {
        final media = Media(rawAttributes: const {'id': 'm1'});
        final event = media.getMainEvent();
        event.doAction(ActionType.START);
        event.doAction(ActionType.PAUSE);
        expect(event.state, State.PAUSED);
        expect(event.doAction(ActionType.START), State.PAUSED);
        expect(event.doAction(ActionType.PAUSE), State.PAUSED);
        expect(event.state, State.PAUSED);
      },
    );

    test('doAction ABORT behaves like STOP from OCCURRING and PAUSED', () {
      final media = Media(rawAttributes: const {'id': 'm1'});
      final event = media.getMainEvent();
      event.doAction(ActionType.START);
      expect(event.doAction(ActionType.ABORT), State.SLEEPING);

      event.doAction(ActionType.START);
      event.doAction(ActionType.PAUSE);
      expect(event.doAction(ActionType.ABORT), State.SLEEPING);
    });

    test('Event helper methods work correctly', () {
      expect(Event.getStringAsActionType('start'), ActionType.START);
      expect(Event.getStringAsActionType('stop'), ActionType.STOP);
      expect(Event.getEventStateAsString(State.OCCURRING), 'occurring');
      expect(
        Event.getEventTypeAsString(EventType.PRESENTATION),
        'presentation',
      );
    });

    test('Media Initialization', () {
      final mediaDefault = Media(
        rawAttributes: const {'id': 'm1'},
      );
      expect(mediaDefault.id, 'm1');
      expect(mediaDefault.uri, '');
      expect(mediaDefault.mimeType, 'application/x-ginga-time');

      final mediaCustom = Media(
        rawAttributes: const {'id': 'm2', 'src': 'video.mp4'},
        uri: 'file:///video.mp4',
        mimeType: 'video/mp4',
      );
      expect(mediaCustom.id, 'm2');
      expect(mediaCustom.src, 'video.mp4');
      expect(mediaCustom.uri, 'file:///video.mp4');
      expect(mediaCustom.mimeType, 'video/mp4');

      final mediaCustomUriOnly = Media(
        rawAttributes: const {'id': 'm3'},
        uri: 'file:///audio.mp3',
      );
      expect(mediaCustomUriOnly.id, 'm3');
      expect(mediaCustomUriOnly.uri, 'file:///audio.mp3');
      expect(mediaCustomUriOnly.mimeType, 'application/x-ginga-time');

      final mediaCustomMimeOnly = Media(
        rawAttributes: const {'id': 'm4'},
        mimeType: 'image/png',
      );
      expect(mediaCustomMimeOnly.id, 'm4');
      expect(mediaCustomMimeOnly.uri, '');
      expect(mediaCustomMimeOnly.mimeType, 'image/png');
    });

    test('Settings Initialization', () {
      final settings = Settings(rawAttributes: const {'id': 's1'});
      expect(settings, isA<Settings>());
      expect(settings.id, 's1');
    });
  });
}
