import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/html/html_app.dart';
import 'package:integration_test/integration_test.dart';

class MockHTMLAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'test_status.html') {
      return '''
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
    }
    throw FlutterError('MockHTMLAssetBundle: Unknown key $key');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Verify HTMLApp run on real platform',
      (WidgetTester tester) async {
    final mockBundle = MockHTMLAssetBundle();
    final completer = Completer<String>();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: DefaultAssetBundle(
            bundle: mockBundle,
            child: HTMLApp(
              uri: "test_status.html",
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

    // Wait for the message with a timeout
    final result = await completer.future.timeout(const Duration(seconds: 10));

    expect(result, equals("BRIDGE_READY"));
    expect(find.byType(HTMLApp), findsOneWidget);
  });
}
