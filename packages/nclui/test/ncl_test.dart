import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncldoc/ncl_document.dart';
import 'package:nclui/ncl.dart';

const _testImageNcl = '''
<ncl>
  <body>
    <port id="init" component="ginga_logo"/>
    <media id="ginga_logo" src="https://upload.wikimedia.org/wikipedia/commons/c/ce/Ginga_Middleware_Logo.png" />
  </body>
</ncl>
''';

void main() {
  testWidgets('Verify NclWidget launches with branding logo',
      (WidgetTester tester) async {
    final gingacc = GingaCC(
      virtualFiles: {'test_image.ncl': _testImageNcl},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: NclWidget(
            src: "test_image.ncl",
            gingacc: gingacc,
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
    final config = GingaConfig(
      users: Users('{"id": "uConfig"}'),
    );
    final gingacc = GingaCC(
      config: config,
      virtualFiles: {'test_image.ncl': _testImageNcl},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: NclWidget(
            src: "test_image.ncl",
            gingacc: gingacc,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NclWidget), findsOneWidget);
    final appWidget = tester.widget<NclWidget>(find.byType(NclWidget));
    expect(appWidget.gingacc?.config.users.getUser('uConfig'), isNotNull);
  });

  testWidgets(
      'NclWidget.createMediaWidget creates ImageWidget for image mime types',
      (tester) async {
    final media = Media(
      rawAttributes: {'id': 'img1', 'src': 'test.png'},
      mimeType: 'image/png',
    );
    final widget = NclWidget.createMediaWidget(media: media);
    expect(widget, isNotNull);
    expect(widget, isA<ImageWidget>());
  });

  testWidgets(
      'NclWidget.createMediaWidget creates AVWidget for video mime types',
      (tester) async {
    final media = Media(
      rawAttributes: {'id': 'vid1', 'src': 'test.mp4'},
      mimeType: 'video/mp4',
    );
    final widget = NclWidget.createMediaWidget(media: media);
    expect(widget, isNotNull);
    expect(widget, isA<AVWidget>());
  });

  testWidgets(
      'NclWidget.createMediaWidget creates LuaWidget for lua mime types',
      (tester) async {
    final media = Media(
      rawAttributes: {'id': 'lua1', 'src': 'test.lua'},
      mimeType: 'application/x-ncl-NCLua',
    );
    final widget = NclWidget.createMediaWidget(media: media);
    expect(widget, isNotNull);
    expect(widget, isA<LuaWidget>());
  });

  testWidgets(
      'NclWidget.createMediaWidget creates TextWidget for text/plain mime types',
      (tester) async {
    final media = Media(
      rawAttributes: {'id': 'txt1', 'src': 'test.txt'},
      mimeType: 'text/plain',
    );
    final widget = NclWidget.createMediaWidget(media: media);
    expect(widget, isNotNull);
    expect(widget, isA<TextWidget>());
  });

  testWidgets('NclWidget builds and renders correctly', (tester) async {
    const nclContent = '''
<ncl id="test_doc">
  <head>
    <regionBase>
      <region id="rg1" width="100%" height="100%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="d1" region="rg1"/>
    </descriptorBase>
  </head>
  <body>
    <port id="p1" component="m1"/>
    <media id="m1" src="data:text/plain,Hello" type="text/plain" descriptor="d1"/>
  </body>
</ncl>
''';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NclWidget(src: nclContent),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NclWidget), findsOneWidget);
    expect(find.byKey(const Key('ncl_app_stack')), findsOneWidget);
  });
}
