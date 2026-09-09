import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/ginga_config.dart';
import 'package:nclui/html_app.dart';
import 'package:nclui/ncl_app.dart';
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
            usersDataSrc: 'test/user_data1.json',
          ),
        ),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NCLApp), findsOneWidget);
      final nclAppState = tester.state<NCLAppState>(find.byType(NCLApp));
      expect(nclAppState.nclDocument, isNotNull);
      expect(nclAppState.nclDocument?.users.getUser('u400'), isNotNull);
      expect(nclAppState.nclDocument?.users.getUser('u400')?.name,
          equals('ConfUser'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'NCLApp mounts with usersDataSrc parameter and resolves usersDataJson',
        (WidgetTester tester) async {
      final config = GingaConfig(
        appSrc: 'test.ncl',
        enableCCWS: true,
        usersDataSrc: 'test/user_data2.json',
      );
      await tester.pumpWidget(MaterialApp(
        home: DefaultAssetBundle(
          bundle: MockGingaTestAssetBundle(),
          child: NCLApp(
            src: 'test.ncl',
            usersDataSrc: config.usersDataSrc,
          ),
        ),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NCLApp), findsOneWidget);
      final nclAppState = tester.state<NCLAppState>(find.byType(NCLApp));
      expect(nclAppState.nclDocument, isNotNull);
      expect(nclAppState.nclDocument?.users.getUser('uConfig'), isNotNull);
      expect(nclAppState.nclDocument?.users.getUser('uConfig')?.name,
          equals('GingaConfigUser'));
      await tester.pumpWidget(const SizedBox());
    });

    test('HTMLApp accepts enableCCWS parameter', () {
      final htmlApp = HTMLApp(src: 'app.html', enableCCWS: true);
      expect(htmlApp.enableCCWS, isTrue);
      expect(htmlApp.src, equals('app.html'));
    });
  });
}
