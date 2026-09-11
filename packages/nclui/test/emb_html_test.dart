import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nclui/ncl.dart';

void main() {
  group('embHtml UI', () {
    const htmlContent = '''<!DOCTYPE html>
<html>
  <head><title>Test Form</title></head>
  <body>
    <h1>Hello Embedded HTML</h1>
  </body>
</html>''';

    const embHtmlFullScreen = '''<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="embHtml"
  xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="formReg"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="formDesc" region="formReg" focusIndex="1"/>
    </descriptorBase>
  </head>
  <body>
    <port id="entry" component="htmlForm"/>
    <media id="htmlForm" src="current_service.html" type="text/html" descriptor="formDesc"/>
  </body>
</ncl>''';

    const embHtmlNotFullScreen = '''<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="embHtml"
  xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="formReg" left="20%" top="10%" width="60%" height="80%" zIndex="0"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="formDesc" region="formReg" focusIndex="1"/>
    </descriptorBase>
  </head>
  <body>
    <port id="entry" component="htmlForm"/>
    <media id="htmlForm" src="current_service.html" type="text/html" descriptor="formDesc"/>
  </body>
</ncl>''';

    testWidgets(
        'full screen embedded html advances time and checks pixel dimensions',
        (WidgetTester tester) async {
      final gingacc = GingaCC(
        virtualFiles: {
          'main.ncl': embHtmlFullScreen,
          'current_service.html': htmlContent,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NclWidget(
              src: 'main.ncl',
              gingacc: gingacc,
              bounds: const Rectangle<double>(0.0, 0.0, 720.0, 480.0),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final rootState =
          tester.state<NclWidgetState>(find.byType(NclWidget));
      expect(rootState.nclDocument, isNotNull);

      rootState.tick(1000);
      await tester.pump();

      final htmlState =
          tester.state<HtmlWidgetState>(find.byType(HtmlWidget));
      expect(htmlState.rect.left, equals(0.0));
      expect(htmlState.rect.top, equals(0.0));
      expect(htmlState.rect.width, equals(720.0));
      expect(htmlState.rect.height, equals(480.0));

      rootState.nclDocument?.stop();
    });

    testWidgets(
        'non-full screen embedded html advances time and checks pixel dimensions',
        (WidgetTester tester) async {
      final gingacc = GingaCC(
        virtualFiles: {
          'main.ncl': embHtmlNotFullScreen,
          'current_service.html': htmlContent,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NclWidget(
              src: 'main.ncl',
              gingacc: gingacc,
              bounds: const Rectangle<double>(0.0, 0.0, 720.0, 480.0),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final rootState =
          tester.state<NclWidgetState>(find.byType(NclWidget));
      expect(rootState.nclDocument, isNotNull);

      rootState.tick(1000);
      await tester.pump();

      final htmlState =
          tester.state<HtmlWidgetState>(find.byType(HtmlWidget));
      expect(htmlState.rect.left, moreOrLessEquals(144.0));
      expect(htmlState.rect.top, moreOrLessEquals(48.0));
      expect(htmlState.rect.width, moreOrLessEquals(432.0));
      expect(htmlState.rect.height, moreOrLessEquals(384.0));

      rootState.nclDocument?.stop();
    });
  });
}
