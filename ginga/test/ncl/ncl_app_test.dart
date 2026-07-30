import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingaf/ginga.dart';
import 'package:gingaf/ncl/ncl_app.dart';

class MockNCLAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'test_image.ncl') {
      return '''
<ncl>
  <body>
    <port id="init" component="ginga_logo"/>
    <media id="ginga_logo" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png" />
  </body>
</ncl>
''';
    }
    throw FlutterError('MockNCLAssetBundle: Unknown key $key');
  }
}

void main() {
  testWidgets('Verify NCLApp launches with branding logo',
      (WidgetTester tester) async {
    final mockBundle = MockNCLAssetBundle();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: DefaultAssetBundle(
            bundle: mockBundle,
            child: NCLApp(uri: "test_image.ncl"),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NCLApp), findsOneWidget);
  });

  testWidgets('Verify NCLApp receives GingaConfig as parameter and accesses configuration',
      (WidgetTester tester) async {
    final mockBundle = MockNCLAssetBundle();
    final config = GingaConfig('test_image.ncl', true, true, '{"id": "uConfig"}');

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: DefaultAssetBundle(
            bundle: mockBundle,
            child: NCLApp(
              uri: "test_image.ncl",
              config: config,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NCLApp), findsOneWidget);
    final appWidget = tester.widget<NCLApp>(find.byType(NCLApp));
    expect(appWidget.config, equals(config));
    expect(appWidget.config.usersDataSrc, equals('{"id": "uConfig"}'));
  });
}
