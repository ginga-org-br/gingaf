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

    test('getMainNclEvent on Node returns same NclEvent instance', () {
      final media = Media(rawAttributes: const {'id': 'm1'});
      final event1 = media.getMainNclEvent();
      final event2 = media.getMainNclEvent();
      expect(event1, same(event2));
      expect(event1.targetNode.id, 'm1');
      expect(event1.type, NclEventType.presentation);
    });

    test('getAreaNclEventState returns state of the area event', () {
      final media = Media(rawAttributes: const {'id': 'm1'});
      expect(media.getAreaNclEventState('a1'), NclStateType.sleeping);
      media.getAreaNclEvent('a1').state = NclStateType.occurring;
      expect(media.getAreaNclEventState('a1'), NclStateType.occurring);
    });

    test('doNclAction', () {
      final media = Media(rawAttributes: const {'id': 'm1'});
      final event = media.getMainNclEvent();
      expect(event.state, NclStateType.sleeping);
      expect(event.doNclAction(NclActionType.start), NclStateType.occurring);
      expect(event.state, NclStateType.occurring);
      expect(event.doNclAction(NclActionType.pause), NclStateType.paused);
      expect(event.state, NclStateType.paused);
      expect(event.doNclAction(NclActionType.resume), NclStateType.occurring);
      expect(event.state, NclStateType.occurring);
      expect(event.doNclAction(NclActionType.stop), NclStateType.sleeping);
      expect(event.state, NclStateType.sleeping);
    });

    test(
      'doNclAction does not change state on invalid transitions from SLEEPING',
      () {
        final media = Media(rawAttributes: const {'id': 'm1'});
        final event = media.getMainNclEvent();
        expect(event.state, NclStateType.sleeping);
        expect(event.doNclAction(NclActionType.stop), NclStateType.sleeping);
        expect(event.doNclAction(NclActionType.abort), NclStateType.sleeping);
        expect(event.doNclAction(NclActionType.pause), NclStateType.sleeping);
        expect(event.doNclAction(NclActionType.resume), NclStateType.sleeping);
        expect(event.state, NclStateType.sleeping);
      },
    );

    test(
      'doNclAction does not change state on invalid transitions from OCCURRING',
      () {
        final media = Media(rawAttributes: const {'id': 'm1'});
        final event = media.getMainNclEvent();
        event.doNclAction(NclActionType.start);
        expect(event.state, NclStateType.occurring);
        expect(event.doNclAction(NclActionType.start), NclStateType.occurring);
        expect(event.doNclAction(NclActionType.resume), NclStateType.occurring);
        expect(event.state, NclStateType.occurring);
      },
    );

    test(
      'doNclAction does not change state on invalid transitions from PAUSED',
      () {
        final media = Media(rawAttributes: const {'id': 'm1'});
        final event = media.getMainNclEvent();
        event.doNclAction(NclActionType.start);
        event.doNclAction(NclActionType.pause);
        expect(event.state, NclStateType.paused);
        expect(event.doNclAction(NclActionType.start), NclStateType.paused);
        expect(event.doNclAction(NclActionType.pause), NclStateType.paused);
        expect(event.state, NclStateType.paused);
      },
    );

    test('doNclAction ABORT behaves like STOP from OCCURRING and PAUSED', () {
      final media = Media(rawAttributes: const {'id': 'm1'});
      final event = media.getMainNclEvent();
      event.doNclAction(NclActionType.start);
      expect(event.doNclAction(NclActionType.abort), NclStateType.sleeping);

      event.doNclAction(NclActionType.start);
      event.doNclAction(NclActionType.pause);
      expect(event.doNclAction(NclActionType.abort), NclStateType.sleeping);
    });

    test('NclEvent helper methods work correctly', () {
      expect(NclEvent.getStringAsActionType('start'), NclActionType.start);
      expect(NclEvent.getStringAsActionType('stop'), NclActionType.stop);
      expect(NclEvent.getNclEventStateAsString(NclStateType.occurring), 'occurring');
      expect(NclEvent.getEventTypeAsString(NclEventType.presentation), 'presentation');
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
