import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('embNcl', () {
    const videoNcl = '''<ncl>
  <body>
    <port id="init" component="video"/>
    <media id="video" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4">
      <area id="a1" begin="2s" end="4s"/>
    </media>
    <media id="green_bg">
      <property name="background" value="green"/>
      <property name="bounds" value="0%,80%,20%,20%"/>
    </media>
    <media id="red_bg">
      <property name="background" value="red"/>
      <property name="bounds" value="80%,80%,20%,20%"/>
      <property name="explicitDur" value="2s"/>
    </media>
    <link id="l1">
      <bind role="onBegin" component="video" interface="a1"/>
      <bind role="start" component="green_bg"/>
    </link>
    <link id="l2">
      <bind role="onEnd" component="video" interface="a1"/>
      <bind role="stop" component="green_bg"/>
      <bind role="start" component="red_bg"/>
    </link>
  </body>
</ncl>''';

    const embNclFullScreen = '''<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="embHtml"
  xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="formReg"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="nclDesc" region="formReg" focusIndex="1"/>
    </descriptorBase>
  </head>
  <body>
    <port id="entry" component="embNcl"/>
    <media id="embNcl" src="video.ncl" type="text/ncl" descriptor="nclDesc"/>
  </body>
</ncl>''';

    const embNclNotFullScreen = '''<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="embHtml"
  xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
  <head>
    <regionBase>
      <region id="formReg" left="20%" top="10%" width="60%" height="80%" zIndex="0"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="nclDesc" region="formReg" focusIndex="1"/>
    </descriptorBase>
  </head>
  <body>
    <port id="entry" component="embNcl"/>
    <media id="embNcl" src="video.ncl" type="text/ncl" descriptor="nclDesc"/>
  </body>
</ncl>''';

    test('full screen embedded ncl advances time and checks pixel dimensions',
        () {
      final gingacc = GingaCC(
        virtualFiles: {
          'video.ncl': videoNcl,
        },
      );
      final doc = NclDocument.fromContent(embNclFullScreen, gingacc: gingacc);
      final embMedia = doc.getNodeById('embNcl') as Media;
      final videoDoc = NclDocument.fromContent(
        gingacc.virtualFiles![embMedia.src]!,
        gingacc: gingacc,
      );

      doc.start();
      videoDoc.start();

      doc.tick(1000);
      videoDoc.tick(1000);

      expect(
          doc.getNodeById('embNcl')?.getMainState().name, equals('occurring'));
      expect(
          doc.getActiveMedia().map((m) => m.id).toList(), contains('embNcl'));

      expect(videoDoc.getNodeById('video')?.getMainState().name,
          equals('occurring'));
      expect(videoDoc.getActiveMedia().map((m) => m.id).toList(),
          contains('video'));

      doc.tick(1500);
      videoDoc.tick(1500);

      expect(
          doc.getNodeById('embNcl')?.getMainState().name, equals('occurring'));
      expect(videoDoc.getNodeById('green_bg')?.getMainState().name,
          equals('occurring'));
      expect(videoDoc.getActiveMedia().map((m) => m.id).toList(),
          contains('green_bg'));

      doc.tick(2000);
      videoDoc.tick(2000);

      expect(videoDoc.getNodeById('green_bg')?.getMainState().name,
          equals('sleeping'));
      expect(videoDoc.getNodeById('red_bg')?.getMainState().name,
          equals('occurring'));
      expect(videoDoc.getActiveMedia().map((m) => m.id).toList(),
          contains('red_bg'));

      doc.stop();
      videoDoc.stop();

      expect(
          doc.getNodeById('embNcl')?.getMainState().name, equals('sleeping'));
      expect(videoDoc.getNodeById('video')?.getMainState().name,
          equals('sleeping'));

      final resolvedWidthStr = embMedia.rawAttributes['resolvedWidth']!;
      final resolvedHeightStr = embMedia.rawAttributes['resolvedHeight']!;
      expect(resolvedWidthStr, equals('100.00%'));
      expect(resolvedHeightStr, equals('100.00%'));
    });

    test(
        'non-full screen embedded ncl advances time and checks pixel dimensions',
        () {
      final gingacc = GingaCC(
        virtualFiles: {
          'video.ncl': videoNcl,
        },
      );
      final doc =
          NclDocument.fromContent(embNclNotFullScreen, gingacc: gingacc);
      final embMedia = doc.getNodeById('embNcl') as Media;
      final videoDoc = NclDocument.fromContent(
        gingacc.virtualFiles![embMedia.src]!,
        gingacc: gingacc,
      );

      doc.start();
      videoDoc.start();

      doc.tick(1000);
      videoDoc.tick(1000);

      expect(
          doc.getNodeById('embNcl')?.getMainState().name, equals('occurring'));
      expect(
          doc.getActiveMedia().map((m) => m.id).toList(), contains('embNcl'));

      expect(videoDoc.getNodeById('video')?.getMainState().name,
          equals('occurring'));
      expect(videoDoc.getActiveMedia().map((m) => m.id).toList(),
          contains('video'));

      doc.tick(1500);
      videoDoc.tick(1500);

      expect(
          doc.getNodeById('embNcl')?.getMainState().name, equals('occurring'));
      expect(videoDoc.getNodeById('green_bg')?.getMainState().name,
          equals('occurring'));
      expect(videoDoc.getActiveMedia().map((m) => m.id).toList(),
          contains('green_bg'));

      doc.tick(2000);
      videoDoc.tick(2000);

      expect(videoDoc.getNodeById('green_bg')?.getMainState().name,
          equals('sleeping'));
      expect(videoDoc.getNodeById('red_bg')?.getMainState().name,
          equals('occurring'));
      expect(videoDoc.getActiveMedia().map((m) => m.id).toList(),
          contains('red_bg'));

      doc.stop();
      videoDoc.stop();

      expect(
          doc.getNodeById('embNcl')?.getMainState().name, equals('sleeping'));
      expect(videoDoc.getNodeById('video')?.getMainState().name,
          equals('sleeping'));

      final region = doc.getElementById('formReg') as Region;
      expect(region.width, equals('60%'));
      expect(region.height, equals('80%'));

      final resolvedWidthStr = embMedia.rawAttributes['resolvedWidth']!;
      final resolvedHeightStr = embMedia.rawAttributes['resolvedHeight']!;
      expect(resolvedWidthStr, equals('60.00%'));
      expect(resolvedHeightStr, equals('80.00%'));
    });
  });
}
