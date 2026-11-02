import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/gingacc.dart';
import 'package:gingaf/ginga.dart';
import 'package:nclui/html.dart' as html;
import 'package:nclui/ncl.dart' as ncl;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'mock_video_player.dart';

void main() {
  group('Playground Catalog Examples Launch Tests', () {
    setUp(() {
      VideoPlayerPlatform.instance = MockVideoPlayer();
    });

    final catalogFile = File('examples/catalog.json');
    final catalogData =
        jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
    final examples = catalogData['examples'] as Map<String, dynamic>;

    for (final entry in examples.entries) {
      final exampleKey = entry.key;
      final mainFile =
          (entry.value as Map<String, dynamic>)['mainFile'] as String;
      final examplePath = 'examples/$mainFile';

      testWidgets(
          'launches playground with catalog example $exampleKey ($examplePath)',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final config = GingaConfig(
          enablePlayground: true,
          appSrc: examplePath,
        );
        final gingacc = GingaCC(config: config);

        await tester.pumpWidget(Ginga(gingacc: gingacc));
        await tester.pump(const Duration(milliseconds: 100));

        final editorFinder = find.byType(PlaygroundEditor);
        expect(editorFinder, findsOneWidget);

        final editorRect = tester.getRect(editorFinder);
        expect(editorRect.left, equals(0.0));

        await tester.tap(find.byKey(const Key('monaco_run_button')));
        await tester.pump(const Duration(milliseconds: 100));

        final isHtml = mainFile.toLowerCase().endsWith('.html') ||
            mainFile.toLowerCase().endsWith('.htm') ||
            mainFile.toLowerCase().endsWith('.xhtml');

        if (isHtml) {
          expect(find.byType(html.HtmlWidget), findsWidgets);
        } else {
          expect(find.byType(ncl.NclWidget), findsWidgets);
          final nclRect = tester.getRect(find.byType(ncl.NclWidget).first);
          expect(editorRect.right, lessThanOrEqualTo(nclRect.left));
        }

        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
