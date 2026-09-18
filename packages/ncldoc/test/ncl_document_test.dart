import 'dart:io';

import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NclDocument from nodes Tests', () {
    test('tick increments virtual clock', () {
      final doc = NclDocument.fromContent('<ncl><body id="body"></body></ncl>');
      expect(doc.virtualClock, 0);
      doc.start();
      final changed1 = doc.tick(10);
      expect(changed1, isEmpty);
      expect(doc.virtualClock, 10);
      final changed2 = doc.tick(1);
      expect(changed2, isEmpty);
      expect(doc.virtualClock, 11);
    });

    test('tick does not go backwards', () {
      final doc = NclDocument.fromContent('<ncl><body id="body"></body></ncl>');
      doc.start();
      final changed3 = doc.tick(100);
      expect(changed3, isEmpty);
      expect(doc.virtualClock, 100);
      final changed4 = doc.tick(0);
      expect(changed4, isEmpty);
      expect(doc.virtualClock, 100);
    });

    test('automatic start via Port', () {
      final doc = NclDocument.fromContent(
        '<ncl><body id="body"><media id="m1"/><port id="p1" component="m1"/></body></ncl>',
      );
      doc.start();
      expect(doc.getBodyState(), NclStateType.occurring);
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.occurring);
      doc.stop();
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.sleeping);
      expect(doc.getBodyState(), NclStateType.sleeping);
    });

    test('causal link between two media', () {
      final doc = NclDocument.fromContent('''
<ncl>
<body id="body">
  <media id="m1"/>
  <media id="m2"/>
  <port id="p1" component="m1"/>
  <link id="l1">
    <bind role="onBegin" component="m1"/>
    <bind role="start" component="m2"/>
  </link>
</body>
</ncl>
''');
      doc.start();
      expect(doc.getBodyState(), NclStateType.occurring);
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.occurring);
      expect(doc.getNodeById('m2')?.getMainState(), NclStateType.occurring);
      doc.stop();
      expect(doc.getNodeById('m1')?.getMainState(), NclStateType.sleeping);
      expect(doc.getNodeById('m2')?.getMainState(), NclStateType.sleeping);
      expect(doc.getBodyState(), NclStateType.sleeping);
    });

    test('Settings is not present if none is provided', () {
      final doc = NclDocument.fromContent('<ncl><body id="body"></body></ncl>');
      doc.start();
      expect(doc.body.children.whereType<Settings>(), isEmpty);
    });

    test('NclDocument Composition', () {
      final doc = NclDocument.fromContent(
        '<ncl><body id="body"><media id="m1" src="v.mp4"/><port id="p1" component="m1"/></body></ncl>',
      );
      doc.start();

      expect(doc.body.getMedias().length, 1);
      expect(doc.body.getPorts().length, 1);
      expect(doc.body.getMedias().first.id, 'm1');
      expect(doc.body.getPorts().first.id, 'p1');
    });

    test('Settings element is present when provided', () {
      final doc = NclDocument.fromContent(
        '<ncl><body id="body"><media id="s1" type="application/x-ncl-settings"/></body></ncl>',
      );
      doc.start();
      expect(doc.body.children.whereType<Settings>().first.id, 's1');
    });

    test('NclDocument.fromContent parses NCL XML string correctly', () {
      final xml =
          '<ncl><body id="body"><media id="m1" src="m1.mp4"/></body></ncl>';
      final doc = NclDocument.fromContent(xml);
      expect(doc.getNodeById('m1'), isNotNull);
    });

    test('docSrc default in fromContent', () {
      final doc = NclDocument.fromContent('<ncl><body id="body"></body></ncl>');
      expect(doc.docSrc, 'tmp.ncl');
    });

    test('resolving relative media path against file docUri', () {
      final dummy = File('video.mp4')..writeAsStringSync('');
      try {
        final doc = NclDocument.fromContent(
          '<ncl><body id="body"><media id="m1" src="video.mp4" /></body></ncl>',
          docSrc: 'file:///C:/Users/test/video.ncl',
        );
        final media = doc.getNodeById('m1') as Media;
        expect(media.uri, 'file:///C:/Users/test/video.mp4');
      } finally {
        if (dummy.existsSync()) dummy.deleteSync();
      }
    });

    test('NclDocument loads systemVariables from GingaConfig', () async {
      final config = await GingaConfig.fromJson(
        '{"systemVariables": {"system.language": "fra", "channel.key": "ch1"}}',
      );
      final gingacc = GingaCC(config: config);
      final doc = NclDocument.fromContent(
        '<ncl><body><port id="p1" component="m1"/><media id="m1" src="m1.mp4"/></body></ncl>',
        gingacc: gingacc,
      );
      expect(doc.getSystemVariable('system.language'), equals('fra'));
      final s = doc.body.children.whereType<Settings>().firstOrNull;
      expect(doc.getPropertyValue(s, 'system.language'), equals('fra'));
      expect(doc.getSystemVariable('channel.key'), equals('ch1'));
      expect(doc.config, equals(config));
    });

    test(
        'NclDocument.fromSrc loads config with systemVariables from configSrc raw JSON',
        () async {
      final gingacc = GingaCC(
        config: await GingaConfig.fromJson(
            '{"userDataJson": "users.json", "systemVariables": {"system.language": "spa", "user.pref": "dark"}}'),
      );
      final doc = NclDocument.fromContent(
        '<ncl><body><port id="p1" component="m1"/><media id="m1" src="m1.mp4"/></body></ncl>',
        gingacc: gingacc,
      );
      expect(doc.users, isNotNull);
      expect(doc.getSystemVariable('system.language'), equals('spa'));
      expect(doc.getSystemVariable('user.pref'), equals('dark'));
    });
  });
}
