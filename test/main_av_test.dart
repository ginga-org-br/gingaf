import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/ginga_config.dart';
import 'package:nclui/main_av.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mock_video_player.dart';

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
}
