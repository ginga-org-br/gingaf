import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nclui/ncl.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mock_video_player.dart';

void main() {
  setUpAll(() {
    VideoPlayerPlatform.instance = MockVideoPlayer();
  });

  testWidgets('NclWidget can change background video via settings property',
      (WidgetTester tester) async {
    const nclData = '''
<ncl>
  <body>
    <port id="p1" component="mainAV"/>
    <media id="mainAV" src="sbtvd://0" />
  </body>
</ncl>
''';

    const mainAvUri = 'examples/primeiro-joao/media/animGar.mp4';
    final config = GingaConfig(mainAvSrc: mainAvUri);
    final gingacc = GingaCC(
      config: config,
      virtualFiles: {'test_bg.ncl': nclData},
    );
    final mainAvKey = GlobalKey<MainAVWidgetState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              MainAVWidget(
                key: mainAvKey,
                src: mainAvUri,
              ),
              NclWidget(
                src: 'test_bg.ncl',
                mainAvKey: mainAvKey,
                gingacc: gingacc,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final MainAVWidget av = tester.widget(find.byType(MainAVWidget));
    expect(av.src, mainAvUri);
    expect(mainAvKey.currentState?.media?.id, 'mainAV');
  });

  testWidgets(
      'NclWidget background video resolution with online butterfly.mp4 URL',
      (WidgetTester tester) async {
    const nclData = '''
<ncl>
  <body>
    <port id="p1" component="mainAV"/>
    <media id="mainAV" src="sbtvd://0" />
  </body>
</ncl>
''';

    const mainAvUri = GingaConfig.defaultMainAVSrc;
    final config = GingaConfig(mainAvSrc: mainAvUri);
    final gingacc = GingaCC(
      config: config,
      virtualFiles: {'test_bg.ncl': nclData},
    );
    final mainAvKey = GlobalKey<MainAVWidgetState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              MainAVWidget(
                key: mainAvKey,
                src: mainAvUri,
              ),
              NclWidget(
                src: 'test_bg.ncl',
                mainAvKey: mainAvKey,
                gingacc: gingacc,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final MainAVWidget av = tester.widget(find.byType(MainAVWidget));
    expect(av.src, mainAvUri);
    expect(mainAvKey.currentState?.media?.id, 'mainAV');
  });

  testWidgets('NclWidget controls external MainAVWidget via mainAvKey',
      (WidgetTester tester) async {
    const nclData = '''
<ncl>
  <body>
    <port id="p1" component="mainAV"/>
    <media id="mainAV" src="sbtvd://0" />
  </body>
</ncl>
''';

    const mainAvUri = 'examples/primeiro-joao/media/animGar.mp4';
    final config = GingaConfig(mainAvSrc: mainAvUri);
    final gingacc = GingaCC(
      config: config,
      virtualFiles: {'test_bg.ncl': nclData},
    );
    final mainAvKey = GlobalKey<MainAVWidgetState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              MainAVWidget(
                key: mainAvKey,
                src: mainAvUri,
              ),
              NclWidget(
                src: 'test_bg.ncl',
                mainAvKey: mainAvKey,
                gingacc: gingacc,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MainAVWidget), findsOneWidget);
    expect(mainAvKey.currentState?.media?.id, 'mainAV');
    expect(mainAvKey.currentState?.document, isNotNull);
  });
}
