import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/gingacc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nclui/html.dart';

const _testStatusHtml = '''
<!DOCTYPE html>
<html>
<body>
    <h1>Runtime Bridge Test</h1>
    <script>
        setTimeout(() => {
            if (window.HTMLAppChannel) {
                HTMLAppChannel.postMessage("BRIDGE_READY");
            }
        }, 500);
    </script>
</body>
</html>
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Verify HtmlWidget run on real platform',
      (WidgetTester tester) async {
    final gingacc = GingaCC(
      virtualFiles: {'test_status.html': _testStatusHtml},
    );
    final completer = Completer<String>();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: HtmlWidget(
            src: 'test_status.html',
            gingacc: gingacc,
            javaScriptChannels: {
              'HTMLAppChannel': (message) {
                if (!completer.isCompleted) {
                  completer.complete(message.message);
                }
              }
            },
          ),
        ),
      ),
    );

    // Wait for the message with a timeout
    final result = await completer.future.timeout(const Duration(seconds: 10));

    expect(result, equals("BRIDGE_READY"));
    expect(find.byType(HtmlWidget), findsOneWidget);
  });
}
