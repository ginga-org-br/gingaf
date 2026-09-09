import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nclui/main_av_controller.dart';
import 'package:nclui/ncl_app.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mock_video_player.dart';

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

  testWidgets('NCLApp can change background video via settings property',
      (WidgetTester tester) async {
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

    final controller = MainAVController()
      ..setMainAvUri('examples/primeiro-joao/media/animGar.mp4');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultAssetBundle(
            bundle: mockBundle,
            child: NCLApp(
              src: 'test_bg.ncl',
              mainAVController: controller,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final AVWidget av = tester.widget(find.byType(AVWidget));
    expect(av.src, controller.uri);
  });

  testWidgets(
      'NCLApp background video resolution with online butterfly.mp4 URL',
      (WidgetTester tester) async {
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

    final controller = MainAVController()
      ..setMainAvUri(
          'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultAssetBundle(
            bundle: mockBundle,
            child: NCLApp(
              src: 'test_bg.ncl',
              mainAVController: controller,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final AVWidget av = tester.widget(find.byType(AVWidget));
    expect(av.src,
        'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4');
  });
}
