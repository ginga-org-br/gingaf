import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/main_av.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'mock_video_player.dart';

void main() {
  late MockVideoPlayer fakePlatform;

  setUp(() {
    fakePlatform = MockVideoPlayer();
    VideoPlayerPlatform.instance = fakePlatform;
  });

  testWidgets('MainAVController and MainAVWidget init, start, stop tests',
      (WidgetTester tester) async {
    final controller = MainAVController()..setMainAvUri('examples/primeiro-joao/media/animGar.mp4');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MainAVWidget(controller: controller),
        ),
      ),
    );

    expect(find.text('Loading Background AV: examples/primeiro-joao/media/animGar.mp4'), findsOneWidget);

    fakePlatform.events.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(100, 100),
    ));

    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.text('Loading Background AV: examples/primeiro-joao/media/animGar.mp4'), findsNothing);

    controller.stop();
    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsNothing);

    controller.play();
    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsOneWidget);
  });

  testWidgets('MainAVController and MainAVWidget with online butterfly.mp4 URL tests',
      (WidgetTester tester) async {
    final controller = MainAVController()..setMainAvUri('https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MainAVWidget(controller: controller),
        ),
      ),
    );

    expect(find.text('Loading Background AV: https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4'), findsOneWidget);

    fakePlatform.events.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(100, 100),
    ));

    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.text('Loading Background AV: https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4'), findsNothing);

    controller.stop();
    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsNothing);

    controller.play();
    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsOneWidget);
  });
}
