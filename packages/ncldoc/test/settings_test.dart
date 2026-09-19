import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('Settings Tests', () {
    late NclParser parser;

    setUp(() {
      parser = NclParser();
    });

    test('Settings media property request redirects to gingacc systemVariables', () {
      final sharedVars = {'system.language': 'por'};
      final gingacc = GingaCC(config: GingaConfig(systemVariables: sharedVars));
      final doc = NclDocument.fromContent(
        '''
<ncl>
  <body>
    <media id="s1" type="application/x-ncl-settings" />
    <media id="s2" type="application/x-ginga-settings" />
  </body>
</ncl>
''',
        gingacc: gingacc,
      );
      final s1 = doc.body.children.whereType<Settings>().first;
      expect(doc.getPropertyValue(s1, 'system.language'), equals('por'));

      doc.dispatchSettingsUpdate('system.language', 'eng');
      expect(doc.getPropertyValue(s1, 'system.language'), equals('eng'));
    });

    test('parser only creates Settings if present in document', () {
      const xml = '<ncl><body><media id="m1" src="video.mp4"/></body></ncl>';
      final (_, body) = parser.parseString(xml);
      final settingsList = body.children.whereType<Settings>().toList();
      expect(settingsList, isEmpty);
    });
  });
}
