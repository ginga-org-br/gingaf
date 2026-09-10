import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ginga.dart';
import 'package:nclui/ncl.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mock_video_player.dart';

const testVirtualFiles = {
  'test.ncl':
      '<ncl><body><port id="p1" component="m1"/><media id="m1" src="m1.mp4"/></body></ncl>',
  'test/user_data1.json': '[{"id": "u400", "name": "ConfUser"}]',
  'test/user_data2.json': '[{"id": "uConfig", "name": "GingaConfigUser"}]',
};

void main() {
  group('Widget Tests', () {
    setUp(() {
      VideoPlayerPlatform.instance = MockVideoPlayer();
    });

    testWidgets('NclWidget mounts example', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NclWidget(src: '../examples/video.ncl'),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NclWidget), findsOneWidget);
    });

    testWidgets('NclWidget mounts with config parameter',
        (WidgetTester tester) async {
      final config = GingaConfig(
        users: Users('{"id": "u400", "name": "ConfUser"}'),
      );
      final gingacc = GingaCC(
        config: config,
        virtualFiles: testVirtualFiles,
      );
      await tester.pumpWidget(MaterialApp(
        home: NclWidget(
          src: 'test.ncl',
          gingacc: gingacc,
        ),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NclWidget), findsOneWidget);
      final nclWidgetState =
          tester.state<NclWidgetState>(find.byType(NclWidget));
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
      final gingacc = GingaCC(
        config: config,
        virtualFiles: testVirtualFiles,
      );
      await tester.pumpWidget(MaterialApp(
        home: NclWidget(
          src: 'test.ncl',
          gingacc: gingacc,
        ),
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NclWidget), findsOneWidget);
      final nclWidgetState =
          tester.state<NclWidgetState>(find.byType(NclWidget));
      expect(nclWidgetState.nclDocument, isNotNull);
      expect(nclWidgetState.nclDocument?.users.getUser('uConfig'), isNotNull);
      expect(nclWidgetState.nclDocument?.users.getUser('uConfig')?.name,
          equals('GingaConfigUser'));
      await tester.pumpWidget(const SizedBox());
    });

    test('HtmlWidget accepts gingacc parameter', () {
      final gingacc = GingaCC(config: GingaConfig(startWithCCWS: true));
      final htmlWidget = HtmlWidget(
        src: 'app.html',
        gingacc: gingacc,
      );
      expect(htmlWidget.gingacc?.config.startWithCCWS, isTrue);
      expect(htmlWidget.src, equals('app.html'));
    });

    testWidgets('Ginga mounts single MainAVWidget and plays when app is running',
        (WidgetTester tester) async {
      final config = GingaConfig(
        appSrc: 'test.ncl',
        mainAvSrc: 'examples/primeiro-joao/media/animGar.mp4',
        startWithMainAv: true,
        startWithCCWS: false,
      );
      final gingacc = GingaCC(
        config: config,
        virtualFiles: testVirtualFiles,
      );
      await tester.pumpWidget(Ginga(
        gingacc: gingacc,
      ));

      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(MainAVWidget), findsOneWidget);
      expect(find.byType(NclWidget), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
