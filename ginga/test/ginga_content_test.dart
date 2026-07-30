import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ginga_content.dart';

class MockGingaContentAssetBundle extends AssetBundle {
  final Map<String, String> assets;

  MockGingaContentAssetBundle(this.assets);

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
  group('GingaContentLoader Unit Tests', () {
    testWidgets('handles data URIs', (WidgetTester tester) async {
      late GingaContentLoader loader;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              loader = GingaContentLoader()..setBuildContext(context);
              return const SizedBox();
            },
          ),
        ),
      );

      final dataUri = Uri.dataFromString('hello world', mimeType: 'text/plain');
      expect(loader.exists(dataUri), isTrue);
      final content = await loader.load(dataUri);
      expect(content, equals('hello world'));
    });

    testWidgets('handles inline XML strings starting with <',
        (WidgetTester tester) async {
      late GingaContentLoader loader;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              loader = GingaContentLoader()..setBuildContext(context);
              return const SizedBox();
            },
          ),
        ),
      );

      final xmlUri = Uri.parse('<ncl><body/></ncl>');
      expect(loader.exists(xmlUri), isTrue);
      final content = await loader.load(xmlUri);
      expect(content, equals('<ncl><body/></ncl>'));
    });

    testWidgets('handles empty URIs', (WidgetTester tester) async {
      late GingaContentLoader loader;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              loader = GingaContentLoader()..setBuildContext(context);
              return const SizedBox();
            },
          ),
        ),
      );

      final emptyUri = Uri.parse('');
      expect(loader.exists(emptyUri), isFalse);
      final content = await loader.load(emptyUri);
      expect(content, isNull);
    });

    testWidgets('loads assets from DefaultAssetBundle',
        (WidgetTester tester) async {
      late GingaContentLoader loader;
      final mockBundle = MockGingaContentAssetBundle({
        'media/test.ncl': '<ncl></ncl>',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: mockBundle,
            child: Builder(
              builder: (context) {
                loader = GingaContentLoader()..setBuildContext(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      final uri = Uri.parse('media/test.ncl');
      expect(loader.exists(uri), isTrue);
      final content = await loader.load(uri);
      expect(content, equals('<ncl></ncl>'));
    });

    testWidgets('setBuildContext configures loader BuildContext',
        (WidgetTester tester) async {
      final loader = GingaContentLoader();
      final mockBundle = MockGingaContentAssetBundle({
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

      final uri = Uri.parse('media/test2.ncl');
      final content = await loader.load(uri);
      expect(content, equals('<ncl>test2</ncl>'));
    });
  });
}
