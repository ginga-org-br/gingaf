import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/ginga_config.dart';
import 'package:gingacc/users.dart';
import 'package:nclui/ncl.dart';

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
  testWidgets('Verify NclWidget launches with branding logo',
      (WidgetTester tester) async {
    final mockBundle = MockNCLAssetBundle();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: DefaultAssetBundle(
            bundle: mockBundle,
            child: NclWidget(src: "test_image.ncl"),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NclWidget), findsOneWidget);
  });

  testWidgets(
      'Verify NclWidget receives config parameter and accesses configuration',
      (WidgetTester tester) async {
    final mockBundle = MockNCLAssetBundle();
    final config = GingaConfig(
      users: Users('{"id": "uConfig"}'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: DefaultAssetBundle(
            bundle: mockBundle,
            child: NclWidget(
              src: "test_image.ncl",
              config: config,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NclWidget), findsOneWidget);
    final appWidget = tester.widget<NclWidget>(find.byType(NclWidget));
    expect(appWidget.config.users.getUser('uConfig'), isNotNull);
  });
}
