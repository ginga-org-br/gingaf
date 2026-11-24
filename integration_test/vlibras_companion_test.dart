import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginga_appui/html_widget.dart';
import 'package:gingacc/gingacc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

Future<Map<String, dynamic>> _waitForVlibrasLoaded(
  WidgetTester tester,
  HtmlWidgetState state,
) async {
  Map<String, dynamic> lastSnapshot = const {};
  for (int i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final controller = state.controller;
    if (controller == null) continue;
    try {
      final raw = await controller.runJavaScriptReturningResult('''
        (function() {
          var lsOk = false;
          try {
            window.localStorage.setItem('__gingaf_test', '1');
            window.localStorage.removeItem('__gingaf_test');
            lsOk = true;
          } catch (_) {}
          var root = document.getElementById('vlibras-app-root');
          var api = window.vlibras || (window.plugin && window.plugin.player);
          return JSON.stringify({
            origin: window.location.origin,
            lsOk: lsOk,
            hasRoot: !!root,
            vlibrasIsLoaded: !!(api && api.isLoaded)
          });
        })()
      ''');
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map) {
        lastSnapshot = Map<String, dynamic>.from(decoded);
        if (lastSnapshot['vlibrasIsLoaded'] == true) {
          return lastSnapshot;
        }
      }
    } catch (_) {}
  }
  return lastSnapshot;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HtmlWidget loads vlibras_companion.html from file path',
      (WidgetTester tester) async {
    final gingacc = GingaCC();
    final htmlKey = GlobalKey<HtmlWidgetState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: HtmlWidget(
            key: htmlKey,
            src: 'examples/multidevice/vlibras_companion.html',
            gingacc: gingacc,
          ),
        ),
      ),
    );

    final snapshot = await _waitForVlibrasLoaded(tester, htmlKey.currentState!);
    await gingacc.ccws.stop();

    expect(snapshot['origin'], isNot('null'));
    expect(snapshot['lsOk'], isTrue);
    expect(snapshot['hasRoot'], isTrue);
    expect(snapshot['vlibrasIsLoaded'], isTrue);
  });

  testWidgets('HtmlWidget.fromContent loads vlibras_companion.html',
      (WidgetTester tester) async {
    final gingacc = GingaCC();
    final htmlKey = GlobalKey<HtmlWidgetState>();
    final content =
        File('examples/multidevice/vlibras_companion.html').readAsStringSync();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: HtmlWidget.fromContent(
            content,
            key: htmlKey,
            src: 'examples/multidevice/vlibras_companion.html',
            gingacc: gingacc,
          ),
        ),
      ),
    );

    final snapshot = await _waitForVlibrasLoaded(tester, htmlKey.currentState!);
    await gingacc.ccws.stop();

    expect(snapshot['origin'], isNot('null'));
    expect(snapshot['lsOk'], isTrue);
    expect(snapshot['hasRoot'], isTrue);
    expect(snapshot['vlibrasIsLoaded'], isTrue);
  });
}
