import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCL Single User Profile Tests', () {
    test(
      'verifies active user dynamic property update and instant switch constituent re-evaluation',
      () {
        final xml = '''
<ncl id="dynPropDoc">
<head>
<ruleBase>
  <rule id="rCC" var="closedCaptioning" comparator="eq" value="true"/>
</ruleBase>
</head>
<body>
<settings id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
  <property name="closedCaptioning"/>
</settings>
<port id="p1" component="swSub"/>
<switch id="swSub">
  <bindRule rule="rCC" constituent="mSub"/>
  <defaultComponent component="mNoSub"/>
  <media id="mSub" src="video_cc.mp4"/>
  <media id="mNoSub" src="video.mp4"/>
</switch>
</body>
</ncl>
''';

        final doc = NCLDocument.fromContent(xml);
        final user = NCLUserData(
          id: 'u1',
          name: 'Viewer',
          initialProperties: {'closedCaptioning': false},
        );

        doc.users.registerUser(user);
        doc.users.setActiveUser('u1');

        final sw = doc.getNodeById('swSub') as Switch;
        expect(doc.evaluateRule('rCC'), isFalse);
        expect(doc.resolveSwitch(sw)?.id, equals('mNoSub'));

        doc.users.setUserProperty('u1', 'closedCaptioning', true);
        expect(doc.evaluateRule('rCC'), isTrue);
        expect(doc.resolveSwitch(sw)?.id, equals('mSub'));
      },
    );

    test('verifies all required viewer profile basic attributes', () {
      final xml = '''
    <ncl>
      <head>
        <settings id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
          <property name="nickname"/>
          <property name="parentalControl"/>
          <property name="maxContentRating"/>
          <property name="avatar"/>
          <property name="audioLanguage"/>
          <property name="closedCaptioningLanguage"/>
          <property name="userInterfaceLanguage"/>
          <property name="closedCaptioning"/>
          <property name="closedSigning"/>
          <property name="closedSigningSide"/>
          <property name="closedSigningWidth"/>
          <property name="audioDescription"/>
          <property name="dialogEnhancement"/>
          <property name="voiceGuidance"/>
        </settings>
      </head>
      <body>
        <media id="m1"/>
      </body>
    </ncl>
    ''';
      final doc = NCLDocument.fromContent(
        xml,
        usersDataJson: '''
    {
      "id": "uViewer1",
      "name": "Alice",
      "properties": {
        "nickname": "Alice",
        "parentalControl": true,
        "maxContentRating": "14",
        "avatar": "alice.png",
        "audioLanguage": "pt-BR",
        "closedCaptioningLanguage": "pt-BR",
        "userInterfaceLanguage": "pt-BR",
        "closedCaptioning": true,
        "closedSigning": false,
        "closedSigningSide": "right",
        "closedSigningWidth": 28,
        "audioDescription": false,
        "dialogEnhancement": false,
        "voiceGuidance": false
      }
    }
    ''',
      );

      final user = doc.users.activeUser;
      expect(user, isNotNull);
      expect(user!.id, equals('uViewer1'));

      final settingsNode = doc.getElementById('userSettings') as Settings;

      expect(doc.getPropertyValue(settingsNode, 'nickname'), equals('Alice'));
      expect(doc.getPropertyValue(settingsNode, 'parentalControl'), equals('true'));
      expect(doc.getPropertyValue(settingsNode, 'maxContentRating'), equals('14'));
      expect(doc.getPropertyValue(settingsNode, 'avatar'), equals('alice.png'));
      expect(doc.getPropertyValue(settingsNode, 'audioLanguage'), equals('pt-BR'));
      expect(doc.getPropertyValue(settingsNode, 'closedCaptioningLanguage'), equals('pt-BR'));
      expect(doc.getPropertyValue(settingsNode, 'userInterfaceLanguage'), equals('pt-BR'));
      expect(doc.getPropertyValue(settingsNode, 'closedCaptioning'), equals('true'));
      expect(doc.getPropertyValue(settingsNode, 'closedSigning'), equals('false'));
      expect(doc.getPropertyValue(settingsNode, 'closedSigningSide'), equals('right'));
      expect(doc.getPropertyValue(settingsNode, 'closedSigningWidth'), equals('28'));
      expect(doc.getPropertyValue(settingsNode, 'audioDescription'), equals('false'));
      expect(doc.getPropertyValue(settingsNode, 'dialogEnhancement'), equals('false'));
      expect(doc.getPropertyValue(settingsNode, 'voiceGuidance'), equals('false'));
    });
  });
}
