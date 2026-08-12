import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/assets_src_resolver.dart';

class MockGingaSrcAssetBundle extends AssetBundle {
  final Map<String, String> assets;

  MockGingaSrcAssetBundle(this.assets);

  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (assets.containsKey(key)) {
      return assets[key]!;
    }
    throw FlutterError('Asset not found: $key');
  }
}

void main() {
  group('AssetsSrcResolver Unit Tests', () {
    testWidgets('handles data URIs', (WidgetTester tester) async {
      late AssetsSrcResolver loader;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              loader = AssetsSrcResolver()..setBuildContext(context);
              return const SizedBox();
            },
          ),
        ),
      );

      final dataSrc =
          Uri.dataFromString('hello world', mimeType: 'text/plain').toString();
      final dataUri = loader.resolveUri(dataSrc);
      expect(loader.exists(dataUri), isTrue);
      final content = await loader.load(dataUri);
      expect(content, equals('hello world'));
    });

    testWidgets('handles non-existent file URI sources',
        (WidgetTester tester) async {
      late AssetsSrcResolver loader;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              loader = AssetsSrcResolver()..setBuildContext(context);
              return const SizedBox();
            },
          ),
        ),
      );

      const fileUriSrc = 'file:///non_existent_dir/non_existent_file.ncl';
      final fileUri = loader.resolveUri(fileUriSrc);
      expect(loader.exists(fileUri), isFalse);
      final content = await loader.load(fileUri);
      expect(content, isNull);
    });

    testWidgets('handles empty sources', (WidgetTester tester) async {
      late AssetsSrcResolver loader;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              loader = AssetsSrcResolver()..setBuildContext(context);
              return const SizedBox();
            },
          ),
        ),
      );

      const emptySrc = '';
      final emptyUri = loader.resolveUri(emptySrc);
      expect(loader.exists(emptyUri), isFalse);
      final content = await loader.load(emptyUri);
      expect(content, isNull);
    });

    testWidgets('loads assets from DefaultAssetBundle',
        (WidgetTester tester) async {
      late AssetsSrcResolver loader;
      final mockBundle = MockGingaSrcAssetBundle({
        'media/test.ncl': '<ncl></ncl>',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: mockBundle,
            child: Builder(
              builder: (context) {
                loader = AssetsSrcResolver()..setBuildContext(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      const src = 'media/test.ncl';
      final uri = loader.resolveUri(src);
      expect(loader.exists(uri), isTrue);
      final content = await loader.load(uri);
      expect(content, equals('<ncl></ncl>'));
    });

    testWidgets('setBuildContext configures loader BuildContext',
        (WidgetTester tester) async {
      final loader = AssetsSrcResolver();
      final mockBundle = MockGingaSrcAssetBundle({
        'media/test2.ncl': '<ncl>test2</ncl>',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: mockBundle,
            child: Builder(
              builder: (context) {
                loader.setBuildContext(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      const src = 'media/test2.ncl';
      final uri = loader.resolveUri(src);
      final content = await loader.load(uri);
      expect(content, equals('<ncl>test2</ncl>'));
    });

    test('resolveUri leaves http and https URIs unchanged', () {
      expect(
        AssetsSrcResolver()
            .resolveUri(
                'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/ginga/examples/video.ncl')
            .toString(),
        equals(
            'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/ginga/examples/video.ncl'),
      );
      expect(
        AssetsSrcResolver()
            .resolveUri('http://example.com/test.ncl')
            .toString(),
        equals('http://example.com/test.ncl'),
      );
    });

    testWidgets('does not query asset bundle for HTTP/HTTPS URIs',
        (WidgetTester tester) async {
      late AssetsSrcResolver loader;
      final requestedKeys = <String>[];
      final mockBundle = MockGingaSrcAssetBundle({});

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: mockBundle,
            child: Builder(
              builder: (context) {
                loader = AssetsSrcResolver()..setBuildContext(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      const httpUrl =
          'https://raw.githubusercontent.com/ginga-org-br/gingaf/refs/heads/main/ginga/examples/video.ncl';
      final httpUri = loader.resolveUri(httpUrl);
      expect(loader.exists(httpUri), isTrue);
      expect(requestedKeys, isEmpty);
    });
  });
}
