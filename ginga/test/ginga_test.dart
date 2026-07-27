import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ginga.dart';
import 'package:gingaf/ncl/ncl_app.dart';

class MockGingaTestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData(0);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return '<ncl><body><media id="m1"/></body></ncl>';
  }
}

void main() {
  group('GingaConfig Logic Tests', () {
    test(
        'Constructor should accept .ncl and .html extensions case-insensitively',
        () {
      expect(GingaConfig('app.ncl').appUri, 'app.ncl');
      expect(GingaConfig('app.html').appUri, 'app.html');
      expect(GingaConfig('APP.NCL').appUri, 'APP.NCL');
      expect(GingaConfig('APP.HTML').appUri, 'APP.HTML');
    });

    test('Constructor should capture CCWS environment (true by default)', () {
      final config = GingaConfig('app.ncl');
      expect(config.enableCCWS, isTrue);
    });

    test('Constructor should capture enableMainAv (true by default)', () {
      final config = GingaConfig('app.ncl');
      expect(config.enableMainAv, isTrue);
    });

    test('Constructor should support explicit enableMainAv deactivation', () {
      final config = GingaConfig('app.ncl', true, null, false);
      expect(config.enableMainAv, isFalse);
    });

    test('Constructor should support explicit CCWS deactivation', () {
      final config = GingaConfig('app.ncl', false);
      expect(config.enableCCWS, isFalse);
    });

    test(
        'Constructor should reject unsupported extensions and set appPath to null',
        () {
      expect(GingaConfig('app.txt').appUri, isNull);
      expect(GingaConfig('app.lua').appUri, isNull);
      expect(GingaConfig('app').appUri, isNull);
      expect(GingaConfig('').appUri, isNull);
    });
    test('Constructor should capture manual usersDataJson', () {
      final config = GingaConfig('app.ncl', true, null, true, '{"id":"test"}');
      expect(config.usersDataJson, equals('{"id":"test"}'));
    });

    test('Constructor should accept file path for usersDataJson profile parameter', () {
      final config = GingaConfig('app.ncl', true, null, true, '/path/to/user_data.json');
      expect(config.usersDataJson, equals('/path/to/user_data.json'));
    });
  });

  group('Widget Tests', () {
    testWidgets('NCLApp mounts example', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NCLApp(uri: '../examples/video.ncl'),
      ));

      // Use pump() instead of pumpAndSettle() because the NCLApp uses an infinite periodic timer
      await tester.pump(const Duration(seconds: 1));

      // Assert that NCLApp is in the tree
      expect(find.byType(NCLApp), findsOneWidget);
    });

    testWidgets('NCLApp mounts with userDataJson', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: DefaultAssetBundle(
          bundle: MockGingaTestAssetBundle(),
          child: NCLApp(
            uri: 'test.ncl',
            usersDataJson: '{"id": "u400", "name": "ConfUser"}',
          ),
        ),
      ));

      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      expect(find.byType(NCLApp), findsOneWidget);
      final nclAppState = tester.state<NCLAppState>(find.byType(NCLApp));
      expect(nclAppState.nclDocument, isNotNull);
      expect(nclAppState.nclDocument?.users.getUser('u400'), isNotNull);
      expect(nclAppState.nclDocument?.users.getUser('u400')?.name, equals('ConfUser'));
    });
  });
}
