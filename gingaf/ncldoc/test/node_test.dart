import 'package:ncldoc/elements.dart';
import 'package:ncldoc/event.dart';
import 'package:test/test.dart';

void main() {
  group('Node Tests', () {
    test('Media Node can return its properties and areas', () {
      final media = Media(rawAttributes: const {'id': 'video1'});
      final prop = Property(
        rawAttributes: const {
          'id': 'p1',
          'name': 'bounds',
          'value': '0,0,100,100',
        },
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
        rawAttributes: const {
          'id': 'p1',
          'name': 'bounds',
          'value': '0,0,100,100',
        },
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
      expect(event1.type, NCLEvent.PRESENTATION);
    });

    test('getAreaEventState returns state of the area event', () {
      final media = Media(rawAttributes: const {'id': 'm1'});
      expect(media.getAreaEventState('a1'), NCLState.SLEEPING);
      media.getAreaEvent('a1').state = NCLState.OCCURRING;
      expect(media.getAreaEventState('a1'), NCLState.OCCURRING);
    });

    test('doAction', () {
      final media = Media(rawAttributes: const {'id': 'm1'});
      final event = media.getMainEvent();
      expect(event.state, NCLState.SLEEPING);
      expect(event.doAction(NCLAction.START), NCLState.OCCURRING);
      expect(event.state, NCLState.OCCURRING);
      expect(event.doAction(NCLAction.PAUSE), NCLState.PAUSED);
      expect(event.state, NCLState.PAUSED);
      expect(event.doAction(NCLAction.RESUME), NCLState.OCCURRING);
      expect(event.state, NCLState.OCCURRING);
      expect(event.doAction(NCLAction.STOP), NCLState.SLEEPING);
      expect(event.state, NCLState.SLEEPING);
    });

    test(
      'doAction does not change state on invalid transitions from SLEEPING',
      () {
        final media = Media(rawAttributes: const {'id': 'm1'});
        final event = media.getMainEvent();
        expect(event.state, NCLState.SLEEPING);
        expect(event.doAction(NCLAction.STOP), NCLState.SLEEPING);
        expect(event.doAction(NCLAction.ABORT), NCLState.SLEEPING);
        expect(event.doAction(NCLAction.PAUSE), NCLState.SLEEPING);
        expect(event.doAction(NCLAction.RESUME), NCLState.SLEEPING);
        expect(event.state, NCLState.SLEEPING);
      },
    );

    test(
      'doAction does not change state on invalid transitions from OCCURRING',
      () {
        final media = Media(rawAttributes: const {'id': 'm1'});
        final event = media.getMainEvent();
        event.doAction(NCLAction.START);
        expect(event.state, NCLState.OCCURRING);
        expect(event.doAction(NCLAction.START), NCLState.OCCURRING);
        expect(event.doAction(NCLAction.RESUME), NCLState.OCCURRING);
        expect(event.state, NCLState.OCCURRING);
      },
    );

    test(
      'doAction does not change state on invalid transitions from PAUSED',
      () {
        final media = Media(rawAttributes: const {'id': 'm1'});
        final event = media.getMainEvent();
        event.doAction(NCLAction.START);
        event.doAction(NCLAction.PAUSE);
        expect(event.state, NCLState.PAUSED);
        expect(event.doAction(NCLAction.START), NCLState.PAUSED);
        expect(event.doAction(NCLAction.PAUSE), NCLState.PAUSED);
        expect(event.state, NCLState.PAUSED);
      },
    );

    test('doAction ABORT behaves like STOP from OCCURRING and PAUSED', () {
      final media = Media(rawAttributes: const {'id': 'm1'});
      final event = media.getMainEvent();
      event.doAction(NCLAction.START);
      expect(event.doAction(NCLAction.ABORT), NCLState.SLEEPING);

      event.doAction(NCLAction.START);
      event.doAction(NCLAction.PAUSE);
      expect(event.doAction(NCLAction.ABORT), NCLState.SLEEPING);
    });

    test('Event helper methods work correctly', () {
      expect(Event.getStringAsActionType('start'), NCLAction.START);
      expect(Event.getStringAsActionType('stop'), NCLAction.STOP);
      expect(Event.getEventStateAsString(NCLState.OCCURRING), 'occurring');
      expect(Event.getEventTypeAsString(NCLEvent.PRESENTATION), 'presentation');
    });

    test('Media Initialization', () {
      final mediaDefault = Media(rawAttributes: const {'id': 'm1'});
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
