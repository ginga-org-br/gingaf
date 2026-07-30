import 'dart:async';
import 'package:flutter/material.dart' hide Action, State;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ginga.dart';
import 'package:gingaf/main_av.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import '../mock_video_player.dart';

class MockNCLAssetBundle extends CachingAssetBundle {
  final Map<String, String> assets;
  MockNCLAssetBundle({required this.assets});

  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (assets.containsKey(key)) {
      return assets[key]!;
    }
    throw FlutterError('MockNCLAssetBundle: Unknown key $key');
  }
}

void main() {
  setUpAll(() {
    VideoPlayerPlatform.instance = MockVideoPlayer();
  });

  testWidgets('NCLApp can change background video via settings property', (WidgetTester tester) async {
    const nclData = '''
<ncl>
  <body>
    <port id="p1" component="mainAV"/>
    <media id="mainAV" src="sbtvd://0" />
  </body>
</ncl>
''';

    final mockBundle = MockNCLAssetBundle(assets: {
      'test_bg.ncl': nclData,
    });

    final config = GingaConfig('test_bg.ncl', false, true, null, 'examples/primeiro-joao/media/animGar.mp4');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultAssetBundle(
            bundle: mockBundle,
            child: Ginga(config: config),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final MainAVWidget mainAV = tester.widget(find.byType(MainAVWidget));
    expect(mainAV.controller.uri, config.mainAvSrc);
  });

  testWidgets('NCLApp background video resolution with online butterfly.mp4 URL', (WidgetTester tester) async {
    const nclData = '''
<ncl>
  <body>
    <port id="p1" component="mainAV"/>
    <media id="mainAV" src="sbtvd://0" />
  </body>
</ncl>
''';

    final mockBundle = MockNCLAssetBundle(assets: {
      'test_bg.ncl': nclData,
    });

    final config = GingaConfig('test_bg.ncl', false, true, null, 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultAssetBundle(
            bundle: mockBundle,
            child: Ginga(config: config),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final MainAVWidget mainAV = tester.widget(find.byType(MainAVWidget));
    expect(mainAV.controller.uri, 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4');
  });
}
