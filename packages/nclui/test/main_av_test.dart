import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/ginga_config.dart';
import 'package:nclui/ncl.dart';
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

    final mockBundle = MockNCLAssetBundle(assets: {
      'test_bg.ncl': nclData,
    });

    const mainAvUri = 'examples/primeiro-joao/media/animGar.mp4';
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
              DefaultAssetBundle(
                bundle: mockBundle,
                child: NclWidget(
                  src: 'test_bg.ncl',
                  config: GingaConfig(mainAvSrc: mainAvUri),
                  mainAvKey: mainAvKey,
                ),
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

    final mockBundle = MockNCLAssetBundle(assets: {
      'test_bg.ncl': nclData,
    });

    const mainAvUri = GingaConfig.defaultMainAVSrc;
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
              DefaultAssetBundle(
                bundle: mockBundle,
                child: NclWidget(
                  src: 'test_bg.ncl',
                  config: GingaConfig(mainAvSrc: mainAvUri),
                  mainAvKey: mainAvKey,
                ),
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
      'NclWidget controls external MainAVWidget via mainAvKey',
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

    const mainAvUri = 'examples/primeiro-joao/media/animGar.mp4';
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
              DefaultAssetBundle(
                bundle: mockBundle,
                child: NclWidget(
                  src: 'test_bg.ncl',
                  config: GingaConfig(mainAvSrc: mainAvUri),
                  mainAvKey: mainAvKey,
                ),
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
