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
    <div id="search">Searching CCWS starting at port 44642...</div>
    <div id="status"></div>
    <div id="request">request GET to /dtv/current-service/</div>
    <script>
        async function probePort(port) {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 300);
            try {
                const response = await fetch(`http://127.0.0.1:\${port}/dtv/current-service/`, { signal: controller.signal });
                clearTimeout(timeoutId);
                if (response.ok) {
                    const data = await response.json();
                    return { port, data };
                }
            } catch (_) {}
            return null;
        }

        async function fetchService() {
            const startPort = 44642; // default port of Ginga CC WebServices from NBR15606-11
            const maxPort = 65535;
            const batchSize = 64;
            const statusDiv = document.getElementById('status');

            const firstTry = await probePort(startPort);
            if (firstTry) {
                statusDiv.textContent = `Found CCWS on port \${startPort}.`;
                statusDiv.style.color = "green";
                if (window.HTMLAppChannel) {
                    window.HTMLAppChannel.postMessage("SUCCESS: " + JSON.stringify(firstTry.data));
                }
                return;
            }

            for (let current = startPort + 1; current <= maxPort; current += batchSize) {
                const limit = Math.min(current + batchSize, maxPort + 1);
                const batch = [];
                for (let p = current; p < limit; p++) {
                    batch.push(probePort(p));
                }

                const results = await Promise.all(batch);
                const found = results.find(r => r !== null);
                if (found) {
                    statusDiv.textContent = `Found CCWS on port \${found.port}.`;
                    statusDiv.style.color = "green";
                    if (window.HTMLAppChannel) {
                        window.HTMLAppChannel.postMessage("SUCCESS: " + JSON.stringify(found.data));
                    }
                    return;
                }
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
        config: GingaConfig(startWithCCWS: true),
        virtualFiles: {'test_ccws.html': _testCcwsHtml},
      );
      await gingacc.ccws.start();
    });

    tearDown(() async {
      await gingacc.ccws.stop();
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
