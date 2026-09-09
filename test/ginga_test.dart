import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/ginga_config.dart';
import 'package:gingacc/users.dart';
import 'package:nclui/ncl.dart';
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

    testWidgets('NclWidget mounts example', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NclWidget(src: '../examples/video.ncl'),
      ));

      // Use pump() instead of pumpAndSettle() because the NclWidget uses an infinite periodic timer
      await tester.pump(const Duration(seconds: 1));

      // Assert that NclWidget is in the tree
      expect(find.byType(NclWidget), findsOneWidget);
    });

    testWidgets('NclWidget mounts with config parameter',
        (WidgetTester tester) async {
      final config = GingaConfig(
        users: Users('{"id": "u400", "name": "ConfUser"}'),
      );
      await tester.pumpWidget(MaterialApp(
        home: DefaultAssetBundle(
          bundle: MockGingaTestAssetBundle(),
          child: NclWidget(
            src: 'test.ncl',
            config: config,
          ),
        ),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NclWidget), findsOneWidget);
      final nclWidgetState = tester.state<NclWidgetState>(find.byType(NclWidget));
      expect(nclWidgetState.nclDocument, isNotNull);
      expect(nclWidgetState.nclDocument?.users.getUser('u400'), isNotNull);
      expect(nclWidgetState.nclDocument?.users.getUser('u400')?.name,
          equals('ConfUser'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('NclWidget mounts with GingaConfig from JSON',
        (WidgetTester tester) async {
      final config = await GingaConfig.fromJson(
        '{"usersDataJson": [{"id": "uConfig", "name": "GingaConfigUser"}]}',
      );
      await tester.pumpWidget(MaterialApp(
        home: DefaultAssetBundle(
          bundle: MockGingaTestAssetBundle(),
          child: NclWidget(
            src: 'test.ncl',
            config: config,
          ),
        ),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NclWidget), findsOneWidget);
      final nclWidgetState = tester.state<NclWidgetState>(find.byType(NclWidget));
      expect(nclWidgetState.nclDocument, isNotNull);
      expect(nclWidgetState.nclDocument?.users.getUser('uConfig'), isNotNull);
      expect(nclWidgetState.nclDocument?.users.getUser('uConfig')?.name,
          equals('GingaConfigUser'));
      await tester.pumpWidget(const SizedBox());
    });

    test('HtmlWidget accepts config parameter', () {
      final htmlWidget = HtmlWidget(
        src: 'app.html',
        config: GingaConfig(enableCCWS: true),
      );
      expect(htmlWidget.config.enableCCWS, isTrue);
      expect(htmlWidget.src, equals('app.html'));
    });
  });
}
