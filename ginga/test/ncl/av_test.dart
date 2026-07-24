import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ncl/ncl_app.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player/video_player.dart';

class MockVideoPlayer extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  final StreamController<VideoEvent> events =
      StreamController<VideoEvent>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int textureId) async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    return 1;
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {}

  @override
  Future<void> play(int textureId) async {}

  @override
  Future<void> pause(int textureId) async {}

  @override
  Future<void> setVolume(int textureId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> seekTo(int textureId, Duration position) async {}

  @override
  Future<Duration> getPosition(int textureId) async {
    return Duration.zero;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return events.stream;
  }

  @override
  Widget buildView(int textureId) {
    return Container();
  }
}

void main() {
  late MockVideoPlayer fakePlatform;

  setUp(() {
    fakePlatform = MockVideoPlayer();
    VideoPlayerPlatform.instance = fakePlatform;
  });

  testWidgets('AVWidget rendering initialization test',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AVWidget(
            uri: 'video.mp4',
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    fakePlatform.events.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(100, 100),
    ));

    await tester.pumpAndSettle();

    expect(find.byType(VideoPlayer), findsOneWidget);
  });

  testWidgets('NCLMediaState visual attributes and properties mapping tests',
      (WidgetTester tester) async {
    final doc = NCLDocument.fromXML('''
<ncl>
  <body>
    <media id="m1" src="video.mp4" focusBorderColor="red" selBorderColor="green">
      <property name="bounds" value="10,20,150,250"/>
      <property name="background" value="blue"/>
    </media>
  </body>
</ncl>
''');
    final media = doc.body.getNodes().first as Media;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              AVWidget(
                uri: 'video.mp4',
                media: media,
              ),
            ],
          ),
        ),
      ),
    );

    final Positioned positioned = tester.widget(find.byType(Positioned));
    expect(positioned.left, 10.0);
    expect(positioned.top, 20.0);
    expect(positioned.width, 150.0);
    expect(positioned.height, 250.0);

    final state = tester.state<AVWidgetState>(find.byType(AVWidget));
    expect(state.background, Colors.blue);
    expect(state.focusBorderColor, Colors.red);
    expect(state.selBorderColor, Colors.green);
  });

  testWidgets('NCLMediaState default visual attributes when omitted',
      (WidgetTester tester) async {
    final doc = NCLDocument.fromXML('''
<ncl>
  <body>
    <media id="m1" src="video.mp4"/>
  </body>
</ncl>
''');
    final media = doc.body.getNodes().first as Media;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              AVWidget(
                uri: 'video.mp4',
                media: media,
              ),
            ],
          ),
        ),
      ),
    );

    final Positioned positioned = tester.widget(find.byType(Positioned));
    final size = MediaQuery.of(tester.element(find.byType(AVWidget))).size;
    expect(positioned.left, 0.0);
    expect(positioned.top, 0.0);
    expect(positioned.width, size.width);
    expect(positioned.height, size.height);
  });

  testWidgets('NCLMediaState bounds and background properties mapping tests',
      (WidgetTester tester) async {
    final doc = NCLDocument.fromXML('''
<ncl>
  <body>
    <media id="m1" src="video.mp4">
      <property name="bounds" value="10,20,150,250"/>
      <property name="background" value="blue"/>
    </media>
  </body>
</ncl>
''');
    final media = doc.body.getNodes().first as Media;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              AVWidget(
                uri: 'video.mp4',
                media: media,
              ),
            ],
          ),
        ),
      ),
    );

    final Positioned positioned = tester.widget(find.byType(Positioned));
    expect(positioned.left, 10.0);
    expect(positioned.top, 20.0);
    expect(positioned.width, 150.0);
    expect(positioned.height, 250.0);

    final state = tester.state<AVWidgetState>(find.byType(AVWidget));
    expect(state.background, Colors.blue);
  });

  testWidgets('ImageWidget rendering without source URI',
      (WidgetTester tester) async {
    final doc = NCLDocument.fromXML('''
<ncl>
  <body>
    <media id="m1" type="image/png">
      <property name="background" value="green"/>
      <property name="bounds" value="0,80,20,20"/>
    </media>
  </body>
</ncl>
''');
    final media = doc.body.getNodes().first as Media;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ImageWidget(
                uri: '',
                media: media,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.error), findsNothing);

    final state = tester.state<ImageWidgetState>(find.byType(ImageWidget));
    expect(state.background, Colors.green);
  });
}
