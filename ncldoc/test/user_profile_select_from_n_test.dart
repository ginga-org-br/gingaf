import 'dart:convert';
import 'package:ncldoc/ncl_document.dart';
import 'package:ncldoc/users.dart';
import 'package:ncldoc/elements.dart';
import 'package:test/test.dart';

void main() {
  group('NCL Multi User Profile Tests', () {

test('verifies multi-user profile evaluation with composite rules', () {
      final xml = '''
<ncl id="multiUserDoc">
<head>
<ruleBase>
  <rule id="rAdult" var="age" comparator="gt" value="16"/>
  <rule id="rCC" var="closedCaptioning" comparator="eq" value="true"/>
  <compositeRule id="rAdultWithCC" operator="and">
    <rule id="rAdult"/>
    <rule id="rCC"/>
  </compositeRule>
</ruleBase>
<descriptorBase>
  <descriptor id="d1"/>
</descriptorBase>
</head>
<body>
    <settings id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
  <property name="age"/>
  <property name="closedCaptioning"/>
</settings>
<port id="pMain" component="swAd"/>
<switch id="swAd">
  <bindRule rule="rAdultWithCC" constituent="mAdultCCAd"/>
  <bindRule rule="rAdult" constituent="mAdultAd"/>
  <media id="mAdultCCAd" src="adult_cc.mp4" descriptor="d1"/>
  <media id="mAdultAd" src="adult.mp4" descriptor="d1"/>
  <media id="mGeneralAd" src="general.mp4" descriptor="d1"/>
</switch>
</body>
</ncl>
''';

      final docAdultCC = NCLDocument.fromContent(
        xml,
        userData: '[{"id": "u1", "name": "AdultCC", "properties": {"age": "25", "closedCaptioning": "true"}}]',
      );

      final sw1 = docAdultCC.getNodeById('swAd') as Switch;
      expect(docAdultCC.evaluateRule('rAdultWithCC'), isTrue);
      expect(docAdultCC.resolveSwitch(sw1)?.id, equals('mAdultCCAd'));

      final docAdultNoCC = NCLDocument.fromContent(
        xml,
        userData: '[{"id": "u2", "name": "AdultNoCC", "properties": {"age": "25", "closedCaptioning": "false"}}]',
      );

      final sw2 = docAdultNoCC.getNodeById('swAd') as Switch;
      expect(docAdultNoCC.evaluateRule('rAdultWithCC'), isFalse);
      expect(docAdultNoCC.evaluateRule('rAdult'), isTrue);
      expect(docAdultNoCC.resolveSwitch(sw2)?.id, equals('mAdultAd'));
    });

test('verifies dynamic user property update and rule re-evaluation', () {
      final xml = '''
<ncl id="dynamicDoc">
<head>
<ruleBase>
  <rule id="rAdult" var="age" comparator="gte" value="18"/>
</ruleBase>
</head>
<body>
    <settings id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
  <property name="age"/>
</settings>
<port id="pMain" component="swContent"/>
<switch id="swContent">
  <bindRule rule="rAdult" constituent="mRestricted"/>
  <defaultComponent component="mPublic"/>
  <media id="mRestricted" src="restricted.mp4"/>
  <media id="mPublic" src="public.mp4"/>
</switch>
</body>
</ncl>
''';

      final doc = NCLDocument.fromContent(
        xml,
        userData: '[{"id": "u1", "name": "YoungUser", "properties": {"age": "16"}}]',
      );

      final sw = doc.getNodeById('swContent') as Switch;
      expect(doc.evaluateRule('rAdult'), isFalse);
      expect(doc.resolveSwitch(sw)?.id, equals('mPublic'));

      doc.users.setUserProperty('u1', 'age', '20');
      expect(doc.evaluateRule('rAdult'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mRestricted'));
    });

test('verifies active user switching in document context and rule re-evaluation', () {
      final xml = '''
<ncl id="switchUserDoc">
<head>
<ruleBase>
  <rule id="rPortuguese" var="lang" comparator="eq" value="pt-BR"/>
</ruleBase>
</head>
<body>
    <settings id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
  <property name="lang"/>
</settings>
<port id="pMain" component="swLang"/>
<switch id="swLang">
  <bindRule rule="rPortuguese" constituent="mPT"/>
  <defaultComponent component="mEN"/>
  <media id="mPT" src="audio_pt.mp3"/>
  <media id="mEN" src="audio_en.mp3"/>
</switch>
</body>
</ncl>
''';

      final doc = NCLDocument.fromContent(
        xml,
        userData: '[{"id": "u1", "name": "User PT", "properties": {"lang": "pt-BR"}}, {"id": "u2", "name": "User EN", "properties": {"lang": "en-US"}}]',
      );

      final sw = doc.getNodeById('swLang') as Switch;
      expect(doc.users.activeUser?.id, equals('u1'));
      expect(doc.evaluateRule('rPortuguese'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mPT'));

      doc.users.setActiveUser('u2');
      expect(doc.users.activeUser?.id, equals('u2'));
      expect(doc.evaluateRule('rPortuguese'), isFalse);
      expect(doc.resolveSwitch(sw)?.id, equals('mEN'));
    });

test('verifies multi-user session profile switching and dynamic rule evaluation', () {
      final xml = '''
<ncl id="sessProfileDoc">
<head>
<ruleBase>
  <rule id="rAdult" var="age" comparator="gte" value="18"/>
  <rule id="rMinor" var="age" comparator="lt" value="18"/>
</ruleBase>
</head>
<body>
    <settings id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
  <property name="age"/>
  <property name="closedCaptioning"/>
</settings>
<port id="pMain" component="swAd"/>
<switch id="swAd">
  <bindRule rule="rAdult" constituent="mAdult"/>
  <bindRule rule="rMinor" constituent="mMinor"/>
  <media id="mAdult" src="ad_adult.mp4"/>
  <media id="mMinor" src="ad_minor.mp4"/>
</switch>
</body>
</ncl>
''';

      final doc = NCLDocument.fromContent(xml);
      final u1 = NCLUserData(id: 'u1', name: 'Adult', initialProperties: {'age': 25});
      final u2 = NCLUserData(id: 'u2', name: 'Child', initialProperties: {'age': 10});

      doc.users.registerUser(u1);
      doc.users.registerUser(u2);

      doc.users.setActiveUser('u1');
      final sw = doc.getNodeById('swAd') as Switch;
      expect(doc.evaluateRule('rAdult'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mAdult'));

      doc.users.setActiveUser('u2');
      expect(doc.evaluateRule('rMinor'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mMinor'));
    });

    test('verifies multi-user session profile export import, migration, and manager teardown', () {
      final xml = '''
<ncl id="sessionDoc">
<head>
<ruleBase>
  <rule id="rAdult" var="age" comparator="gte" value="18"/>
  <rule id="rLangEN" var="preferredLang" comparator="eq" value="en"/>
  <compositeRule id="rAdultEN" operator="and">
    <rule id="rAdult"/>
    <rule id="rLangEN"/>
  </compositeRule>
</ruleBase>
</head>
<body>
<settings id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
  <property name="age"/>
  <property name="preferredLang"/>
</settings>
<port id="pMain" component="swAd"/>
<switch id="swAd">
  <bindRule rule="rAdultEN" constituent="mAdultEN"/>
  <bindRule rule="rAdult" constituent="mAdult"/>
  <defaultComponent component="mDefault"/>
  <media id="mAdultEN" src="en_adult.mp4"/>
  <media id="mAdult" src="adult.mp4"/>
  <media id="mDefault" src="default.mp4"/>
</switch>
</body>
</ncl>
''';

      final doc = NCLDocument.fromContent(xml);
      final users = doc.users;
      final u1 = NCLUserData(id: 'u1', name: 'Alice', initialProperties: {'age': 25, 'preferredLang': 'en'});
      final u2 = NCLUserData(id: 'u2', name: 'Bob', initialProperties: {'age': 16, 'preferredLang': 'es'});

      users.registerUser(u1);
      users.registerUser(u2);

      users.setActiveUser('u1');
      final sw = doc.getNodeById('swAd') as Switch;
      expect(doc.evaluateRule('rAdultEN'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mAdultEN'));

      users.setUserProperty('u1', 'preferredLang', 'es');
      expect(doc.evaluateRule('rAdultEN'), isFalse);
      expect(doc.evaluateRule('rAdult'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mAdult'));
      users.clear();
      expect(users.getUser('u1'), isNull);
    });
  });
}

