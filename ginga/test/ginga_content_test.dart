import 'dart:io';

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

      final dataSrc = Uri.dataFromString('hello world', mimeType: 'text/plain').toString();
      expect(loader.exists(dataSrc), isTrue);
      final content = await loader.load(dataSrc);
      expect(content, equals('hello world'));
    });

    testWidgets('handles non-existent file URI sources',
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

      const fileUriSrc = 'file:///non_existent_dir/non_existent_file.ncl';
      expect(loader.exists(fileUriSrc), isFalse);
      final content = await loader.load(fileUriSrc);
      expect(content, isNull);
    });

    testWidgets('handles empty sources', (WidgetTester tester) async {
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

      const emptySrc = '';
      expect(loader.exists(emptySrc), isFalse);
      final content = await loader.load(emptySrc);
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

      const src = 'media/test.ncl';
      expect(loader.exists(src), isTrue);
      final content = await loader.load(src);
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

      const src = 'media/test2.ncl';
      final content = await loader.load(src);
      expect(content, equals('<ncl>test2</ncl>'));
    });
  });
}
