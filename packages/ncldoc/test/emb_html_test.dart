import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('embHtml', () {
    const htmlContent = '''<!DOCTYPE html>
<html>
<body>
  <h1>Test HTML</h1>
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

    test('full screen embedded html advances time and checks pixel dimensions',
        () {
      final gingacc = GingaCC(
        virtualFiles: {
          'current_service.html': htmlContent,
        },
      );
      final doc = NclDocument.fromContent(embHtmlFullScreen, gingacc: gingacc);
      final htmlMedia = doc.getNodeById('htmlForm') as Media;

      doc.start();
      doc.tick(1000);

      expect(doc.getNodeById('htmlForm')?.getMainState().name,
          equals('occurring'));
      expect(
          doc.getActiveMedia().map((m) => m.id).toList(), contains('htmlForm'));

      doc.stop();
      expect(
          doc.getNodeById('htmlForm')?.getMainState().name, equals('sleeping'));

      final resolvedWidthStr = htmlMedia.rawAttributes['resolvedWidth']!;
      final resolvedHeightStr = htmlMedia.rawAttributes['resolvedHeight']!;
      expect(resolvedWidthStr, equals('100.00%'));
      expect(resolvedHeightStr, equals('100.00%'));
    });

    test(
        'non-full screen embedded html advances time and checks pixel dimensions',
        () {
      final gingacc = GingaCC(
        virtualFiles: {
          'current_service.html': htmlContent,
        },
      );
      final doc =
          NclDocument.fromContent(embHtmlNotFullScreen, gingacc: gingacc);
      final htmlMedia = doc.getNodeById('htmlForm') as Media;

      doc.start();
      doc.tick(1000);

      expect(doc.getNodeById('htmlForm')?.getMainState().name,
          equals('occurring'));
      expect(
          doc.getActiveMedia().map((m) => m.id).toList(), contains('htmlForm'));

      doc.stop();
      expect(
          doc.getNodeById('htmlForm')?.getMainState().name, equals('sleeping'));

      final region = doc.getElementById('formReg') as Region;
      expect(region.width, equals('60%'));
      expect(region.height, equals('80%'));

      final resolvedWidthStr = htmlMedia.rawAttributes['resolvedWidth']!;
      final resolvedHeightStr = htmlMedia.rawAttributes['resolvedHeight']!;
      expect(resolvedWidthStr, equals('60.00%'));
      expect(resolvedHeightStr, equals('80.00%'));
    });
  });
}
