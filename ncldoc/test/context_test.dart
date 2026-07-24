import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('Context Tests', () {
    test('Context Initialization', () {
      final context = Context(rawAttributes: const {'id': 'c1'});
      expect(context, isA<Context>());
      expect(context.id, 'c1');
    });

    test('getBody is returned correctly when provided', () {
      final c1 = Context(rawAttributes: const {'id': 'c1'});
      final doc = NCLDocument.fromBodyElements([c1]);
      expect(doc.body.id, 'body');
      expect(doc.body.children.first.id, 'c1');
    });

    test('Port Initialization', () {
      final port = Port(
        rawAttributes: const {'id': 'p1', 'component': 'm1', 'interface': 'i1'},
      );
      expect(port.id, 'p1');
      expect(port.component, 'm1');
      expect(port.interface, 'i1');
    });

    test('getPorts returns only Port children', () {
      final context = Context(rawAttributes: const {'id': 'c1'});
      final port = Port(rawAttributes: const {'id': 'p1', 'component': 'm1'});
      final media = Media(rawAttributes: const {'id': 'm1'});
      context.children.addAll([port, media]);
      expect(context.getPorts().length, 1);
      expect(context.getPorts().first.id, 'p1');
    });
  });
}
