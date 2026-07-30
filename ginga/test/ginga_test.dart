import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ginga.dart';
import 'package:gingaf/html/html_app.dart';
import 'package:gingaf/ncl/ncl_app.dart';

import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'mock_video_player.dart';

class MockGingaTestAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'test/user_data1.json') {
      return '[{"id": "u400", "name": "ConfUser"}]';
    } else if (key == 'test/user_data2.json') {
      return '[{"id": "uConfig", "name": "GingaConfigUser"}]';
    } else {
      return '<ncl><body><port id="p1" component="m1"/><media id="m1" src="m1.mp4"/></body></ncl>';
    }
  }
}

void main() {
  group('GingaConfig Logic Tests', () {
    test(
        'Constructor should accept string sources',
        () {
      expect(GingaConfig('app.ncl').appSrc, 'app.ncl');
      expect(GingaConfig('app.html').appSrc, 'app.html');
      expect(GingaConfig('APP.NCL').appSrc, 'APP.NCL');
      expect(GingaConfig('APP.HTML').appSrc, 'APP.HTML');
    });
    test('Constructor should capture manual usersDataSrc', () {
      final config = GingaConfig('app.ncl', true, true, 'test/user_data1.json');
      expect(config.usersDataSrc, equals('test/user_data1.json'));
    });

    test('Constructor should accept file path for usersDataSrc profile parameter', () {
      final config = GingaConfig('app.ncl', true, true, '/path/to/user_data.json');
      expect(config.usersDataSrc, equals('/path/to/user_data.json'));
    });
  });

  group('Widget Tests', () {
    setUp(() {
      VideoPlayerPlatform.instance = MockVideoPlayer();
    });

    testWidgets('NCLApp mounts example', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NCLApp(src: '../examples/video.ncl'),
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
            src: 'test.ncl',
            config: GingaConfig('test.ncl', true, false, 'test/user_data1.json'),
          ),
        ),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NCLApp), findsOneWidget);
      final nclAppState = tester.state<NCLAppState>(find.byType(NCLApp));
      expect(nclAppState.nclDocument, isNotNull);
      expect(nclAppState.nclDocument?.users.getUser('u400'), isNotNull);
      expect(nclAppState.nclDocument?.users.getUser('u400')?.name, equals('ConfUser'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('NCLApp mounts with GingaConfig parameter and resolves usersDataJson', (WidgetTester tester) async {
      final config = GingaConfig('test.ncl', true, false, 'test/user_data2.json');
      await tester.pumpWidget(MaterialApp(
        home: DefaultAssetBundle(
          bundle: MockGingaTestAssetBundle(),
          child: NCLApp(
            src: 'test.ncl',
            config: config,
          ),
        ),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NCLApp), findsOneWidget);
      final nclAppState = tester.state<NCLAppState>(find.byType(NCLApp));
      expect(nclAppState.nclDocument, isNotNull);
      expect(nclAppState.nclDocument?.users.getUser('uConfig'), isNotNull);
      expect(nclAppState.nclDocument?.users.getUser('uConfig')?.name, equals('GingaConfigUser'));
      await tester.pumpWidget(const SizedBox());
    });

    test('HTMLApp accepts GingaConfig parameter', () {
      final config = GingaConfig('app.html', true);
      final htmlApp = HTMLApp(src: 'app.html', config: config);
      expect(htmlApp.config, equals(config));
      expect(htmlApp.src, equals('app.html'));
    });
  });
}
