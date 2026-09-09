import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/gingacc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nclui/html.dart';

const _testCcwsHtml = '''
<!DOCTYPE html>
<html>
<body>
    <div id="status">Connecting...</div>
    <script>
        async function fetchService() {
            const startPort = 44642; // default port of Ginga CC WebServices from NBR15606-11
            const maxRetry = 20;
            for (let port = startPort; port < startPort + maxRetry; port++) {
                try {
                    const controller = new AbortController();
                    const timeoutId = setTimeout(() => controller.abort(), 500);

                    const response = await fetch(`http://localhost:\${port}/dtv/current-service`, { signal: controller.signal });
                    clearTimeout(timeoutId);

                    if (response.ok) {
                        const data = await response.json();
                        if (window.HTMLAppChannel) {
                            window.HTMLAppChannel.postMessage("SUCCESS: " + JSON.stringify(data));
                        }
                        return;
                    }
                } catch (error) { }
            }
        }
        fetchService();
    </script>
</body>
</html>
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CCWS HTML Mocked Integration Tests', () {
    late GingaCC gingacc;

    setUp(() async {
      gingacc = GingaCC(
        config: GingaConfig(enableCCWS: true),
        virtualFiles: {'test_ccws.html': _testCcwsHtml},
      );
      await gingacc.start();
    });

    tearDown(() async {
      await gingacc.stop();
    });

    testWidgets(
        'Verify HtmlWidget successful request /dtv/current-service via MockBundle',
        (WidgetTester tester) async {
      final completer = Completer<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlWidget(
              src: 'test_ccws.html',
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

      // Wait for the diagnostic logic to probe ports and resolve the service
      final result =
          await completer.future.timeout(const Duration(seconds: 15));

      expect(result, contains("SUCCESS"));
      expect(result,
          contains(defaultCurrentService["serviceContextId"] as String));
      expect(result, contains(defaultCurrentService["serviceName"] as String));
      expect(gingacc.ccws.isRunning, isTrue);
    });
  });
}
