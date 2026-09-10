import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ginga.dart';
import 'package:nclui/ncl.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mock_video_player.dart';

const sbtvdVideoNcl = '''
<ncl>
  <head>
    <connectorBase>
      <causalConnector id="onKeySelection">
        <connectorParam name="keyCode"/>
        <simpleCondition role="onSelection" key="\$keyCode"/>
        <simpleAction role="set" value="\$var"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body>
    <port id="init" component="video"/>
    <media id="video" src="sbtvd://video">
      <property name="bounds" value="25%,25%,50%,50%"/>
      <property name="soundLevel" value="0.5"/>
    </media>
    <link xconnector="onKeySelection">
      <bind component="video" role="onSelection">
        <bindParam name="keyCode" value="RED"/>
      </bind>
      <bind component="video" interface="soundLevel" role="set">
        <bindParam name="var" value="0"/>
      </bind>
    </link>
  </body>
</ncl>
''';

void main() {
  late MockVideoPlayer fakePlatform;

  setUp(() {
    fakePlatform = MockVideoPlayer();
    VideoPlayerPlatform.instance = fakePlatform;
  });

  testWidgets('MainAVWidget init, start, stop tests',
      (WidgetTester tester) async {
    final key = GlobalKey<MainAVWidgetState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MainAVWidget(
            key: key,
            src: 'examples/primeiro-joao/media/animGar.mp4',
          ),
        ),
      ),
    );

    expect(
        find.text('Loading MainAV: examples/primeiro-joao/media/animGar.mp4'),
        findsOneWidget);

    fakePlatform.events.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(100, 100),
    ));

    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(
        find.text('Loading MainAV: examples/primeiro-joao/media/animGar.mp4'),
        findsNothing);

    key.currentState?.stop();
    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsNothing);

    key.currentState?.play();
    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsOneWidget);
  });

  testWidgets('MainAVWidget with online butterfly.mp4 URL tests',
      (WidgetTester tester) async {
    final key = GlobalKey<MainAVWidgetState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MainAVWidget(
            key: key,
            src: GingaConfig.defaultMainAVSrc,
          ),
        ),
      ),
    );

    expect(find.text('Loading MainAV: ${GingaConfig.defaultMainAVSrc}'),
        findsOneWidget);

    fakePlatform.events.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(100, 100),
    ));

    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.text('Loading MainAV: ${GingaConfig.defaultMainAVSrc}'),
        findsNothing);

    key.currentState?.stop();
    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsNothing);

    key.currentState?.play();
    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsOneWidget);
  });

  testWidgets(
      'Ginga with enableMainAv controls MainAVWidget via sbtvd media string application',
      (WidgetTester tester) async {
    final config = GingaConfig(
      appSrc: sbtvdVideoNcl,
      mainAvSrc: 'examples/primeiro-joao/media/animGar.mp4',
      enableMainAv: true,
      enableCCWS: false,
    );
    final gingacc = GingaCC(config: config);
    await tester.pumpWidget(Ginga(gingacc: gingacc));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MainAVWidget), findsOneWidget);
    expect(tester.widget(find.byType(MainAVWidget)), isA<AVWidget>());

    final mainAvState =
        tester.state<MainAVWidgetState>(find.byType(MainAVWidget));
    expect(mainAvState, isA<AVWidgetState>());
    expect(mainAvState.isPlaying, isTrue);
    expect(mainAvState.isLooping, isTrue);
    expect(mainAvState.notifyCompletion, isFalse);

    expect(mainAvState.media?.id, equals('video'));
    expect(mainAvState.isPositioned, isTrue);
    expect(mainAvState.leftStr, equals('25%'));
    expect(mainAvState.topStr, equals('25%'));
    expect(mainAvState.widthStr, equals('50%'));
    expect(mainAvState.heightStr, equals('50%'));
    expect(mainAvState.soundLevel, equals(0.5));
    expect(mainAvState.controller?.value.volume, equals(0.5));

    mainAvState.stop();
    await tester.pump();
    expect(mainAvState.isPlaying, isFalse);

    mainAvState.play();
    await tester.pump();
    expect(mainAvState.isPlaying, isTrue);

    final nclWidgetState = tester.state<NclWidgetState>(find.byType(NclWidget));
    nclWidgetState.handleKeyPress('RED');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(mainAvState.soundLevel, equals(0.0));
    expect(mainAvState.controller?.value.volume, equals(0.0));

    await tester.pumpWidget(const SizedBox());
  });
}
