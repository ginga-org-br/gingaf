import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ccws/ccws.dart';
import 'package:ccws/router.dart';
import 'package:gingaf/html/html_app.dart';
import 'package:integration_test/integration_test.dart';

class MockCCWSAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'test_ccws.html') {
      return '''
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
    }
    throw FlutterError('MockCCWSAssetBundle: Unknown key $key');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CCWS HTML Mocked Integration Tests', () {
    late CCWS ccws;

    setUp(() async {
      ccws = CCWS();
      await ccws.start();
    });

    tearDown(() async {
      await ccws.stop();
    });

    testWidgets(
        'Verify HTMLApp successful request /dtv/current-service via MockBundle',
        (WidgetTester tester) async {
      final mockBundle = MockCCWSAssetBundle();
      final completer = Completer<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: DefaultAssetBundle(
              bundle: mockBundle,
              child: HTMLApp(
                src: "test_ccws.html",
                javaScriptChannels: {
                  "HTMLAppChannel": (message) {
                    if (!completer.isCompleted) {
                      completer.complete(message.message);
                    }
                  }
                },
              ),
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
      expect(ccws.isRunning, isTrue);
    });
  });
}
