import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ginga.dart';
import 'package:gingaf/ncl/ncl_app.dart';

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
  });
}
