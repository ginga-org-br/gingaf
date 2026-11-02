import 'package:playground/playground.dart';
import 'package:test/test.dart';

void main() {
  group('NclDslTranspiler', () {
    test('transpiles standard XML NCL to concise DSL', () {
      const xml = '''<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="app">
  <head>
    <regionBase>
      <region id="rg1" width="100%" height="100%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="ds1" region="rg1"/>
    </descriptorBase>
  </head>
  <body id="body">
    <port id="p1" component="m1"/>
    <media id="m1" src="video.mp4" descriptor="ds1"/>
  </body>
</ncl>''';

      final dsl = NclDslTranspiler.xmlToDsl(xml);
      expect(dsl, contains('ncl app {'));
      expect(dsl, contains('head {'));
      expect(dsl, contains('regionBase {'));
      expect(dsl, contains('region rg1 { width: "100%", height: "100%" }'));
      expect(dsl, contains('descriptor ds1 { region: "rg1" }'));
      expect(dsl, contains('port p1 -> m1'));
      expect(dsl, contains('media m1 { src: "video.mp4", descriptor: "ds1" }'));
    });

    test('transpiles concise DSL to standard XML NCL', () {
      const dsl = '''
ncl myApp {
  head {
    regionBase {
      region rg_main { width: "80%", height: "80%" }
    }
    descriptorBase {
      descriptor ds_main { region: "rg_main" }
    }
  }
  body {
    port p_start -> m_main
    media m_main { src: "intro.mp4", descriptor: "ds_main" }
  }
}
''';

      final xml = NclDslTranspiler.dslToXml(dsl);
      expect(xml, contains('<ncl id="myApp" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">'));
      expect(xml, contains('<head>'));
      expect(xml, contains('<regionBase>'));
      expect(xml, contains('<region width="80%" height="80%" id="rg_main"/>'));
      expect(xml, contains('<descriptor region="rg_main" id="ds_main"/>'));
      expect(xml, contains('<port id="p_start" component="m_main"/>'));
      expect(xml, contains('<media src="intro.mp4" descriptor="ds_main" id="m_main"/>'));
    });

    test('transpiles links and binds with arrow syntax', () {
      const dsl = '''
ncl linkApp {
  body {
    link l1 {
      bind onBegin -> video1
      bind start -> audio1
    }
  }
}
''';

      final xml = NclDslTranspiler.dslToXml(dsl);
      expect(xml, contains('<link id="l1">'));
      expect(xml, contains('<bind role="onBegin" component="video1"/>'));
      expect(xml, contains('<bind role="start" component="audio1"/>'));

      final roundtripDsl = NclDslTranspiler.xmlToDsl(xml);
      expect(roundtripDsl, contains('bind onBegin -> video1'));
      expect(roundtripDsl, contains('bind start -> audio1'));
    });

    test('handles empty and whitespace input', () {
      expect(NclDslTranspiler.xmlToDsl(''), isEmpty);
      expect(NclDslTranspiler.xmlToDsl('   '), isEmpty);
      expect(NclDslTranspiler.dslToXml(''), isEmpty);
      expect(NclDslTranspiler.dslToXml('   '), isEmpty);
    });

    test('transpiles interface qualifiers on ports and binds', () {
      const xml = '''
<ncl id="app">
  <body>
    <port id="p1" component="m1" interface="area1"/>
    <link>
      <bind role="onBegin" component="m1" interface="area1"/>
    </link>
  </body>
</ncl>''';

      final dsl = NclDslTranspiler.xmlToDsl(xml);
      expect(dsl, contains('port p1 -> m1::area1'));
      expect(dsl, contains('bind onBegin -> m1::area1'));

      final generatedXml = NclDslTranspiler.dslToXml(dsl);
      expect(generatedXml, contains('<port id="p1" component="m1" interface="area1"/>'));
      expect(generatedXml, contains('<bind role="onBegin" component="m1" interface="area1"/>'));
    });
  });
}
