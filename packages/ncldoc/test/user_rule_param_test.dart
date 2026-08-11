import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NCL Rule User Parameter Tests', () {
    test(
      'evaluates rule with explicit user attribute bound to user settings and active user profile',
      () {
        final xml = '''
<ncl id="ruleUserDoc">
<head>
<userBase>
  <userProfile id="pAdult" max="1"/>
</userBase>
<ruleBase>
  <rule id="rMale" user="pAdult" var="gender" comparator="eq" value="male"/>
  <rule id="rFemale" user="pAdult" var="gender" comparator="eq" value="female"/>
</ruleBase>
</head>
<body>
  <settings id="uSettings" type="application/x-ncl-user-settings" user="pAdult">
    <property name="gender"/>
  </settings>
  <port id="pMain" component="swAd"/>
  <switch id="swAd">
    <bindRule rule="rMale" constituent="mMaleAd"/>
    <defaultComponent component="mGeneralAd"/>
    <media id="mMaleAd" src="ad_male.png"/>
    <media id="mGeneralAd" src="ad_general.png"/>
  </switch>
</body>
</ncl>
''';

        final doc = NCLDocument.fromContent(
          xml,
          userData: '''
        {
          "id": "u1",
          "name": "Bob",
          "properties": {
            "gender": "male",
            "age": 30
          }
        }
        ''',
        );

        final sw = doc.getNodeById('swAd') as Switch;
        expect(doc.evaluateRule('rMale'), isTrue);
        expect(doc.evaluateRule('rFemale'), isFalse);
        expect(doc.resolveSwitch(sw)?.id, equals('mMaleAd'));
      },
    );

    test('updates user profile dynamic property and re-evaluates active rules', () {
      final xml = '''
<ncl id="userEventStateDoc">
<head>
<userBase>
  <userProfile id="u1" max="1"/>
</userBase>
<ruleBase>
  <rule id="rAge30" user="u1" var="age" comparator="gte" value="30"/>
</ruleBase>
</head>
<body>
  <settings id="userSet" type="application/x-ncl-user-settings" user="u1">
    <property name="age"/>
  </settings>
  <port id="pMain" component="swAge"/>
  <switch id="swAge">
    <bindRule rule="rAge30" constituent="mAdult"/>
    <defaultComponent component="mChild"/>
    <media id="mAdult" src="adult.mp4"/>
    <media id="mChild" src="child.mp4"/>
  </switch>
</body>
</ncl>
''';

      final doc = NCLDocument.fromContent(
        xml,
        userData: '''
      {
        "id": "u1",
        "name": "Alice",
        "properties": {
          "age": 20
        }
      }
      ''',
      );

      final sw = doc.getNodeById('swAge') as Switch;
      expect(doc.evaluateRule('rAge30'), isFalse);
      expect(doc.resolveSwitch(sw)?.id, equals('mChild'));

      doc.users.setUserProperty('u1', 'age', 35);
      expect(doc.evaluateRule('rAge30'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mAdult'));
    });

    test('supports switching active user profile dynamically', () {
      final xml = '''
<ncl id="userSwitchProfileDoc">
<head>
<userBase>
  <userProfile id="pUser" max="1"/>
</userBase>
<ruleBase>
  <rule id="rPremium" user="pUser" var="tier" comparator="eq" value="gold"/>
</ruleBase>
</head>
<body>
  <settings id="uSettings" type="application/x-ncl-user-settings" user="pUser">
    <property name="tier"/>
  </settings>
  <switch id="swTier">
    <bindRule rule="rPremium" constituent="mGoldContent"/>
    <defaultComponent component="mFreeContent"/>
    <media id="mGoldContent" src="gold.mp4"/>
    <media id="mFreeContent" src="free.mp4"/>
  </switch>
</body>
</ncl>
''';

      final doc = NCLDocument.fromContent(
        xml,
        userData: '''
      [
        {
          "id": "user1",
          "name": "User One",
          "properties": {"tier": "free"}
        },
        {
          "id": "user2",
          "name": "User Two",
          "properties": {"tier": "gold"}
        }
      ]
      ''',
      );

      final sw = doc.getNodeById('swTier') as Switch;
      expect(doc.evaluateRule('rPremium'), isFalse);
      expect(doc.resolveSwitch(sw)?.id, equals('mFreeContent'));

      doc.users.setActiveUser('user2');
      expect(doc.evaluateRule('rPremium'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mGoldContent'));
    });

    test('evaluates compound rules bound to user properties accurately across user state updates', () {
      final xml = '''
<ncl id="userCompoundRuleDoc">
<head>
<userBase>
  <userProfile id="pUser" max="1"/>
</userBase>
<ruleBase>
  <rule id="rAdultMale" user="pUser" var="gender" comparator="eq" value="male"/>
  <rule id="rOver18" user="pUser" var="age" comparator="gte" value="18"/>
  <compositeRule id="rAdultMaleCombined" operator="and">
    <rule id="rAdultMale"/>
    <rule id="rOver18"/>
  </compositeRule>
</ruleBase>
</head>
<body>
  <settings id="uSettings" type="application/x-ncl-user-settings" user="pUser">
    <property name="gender"/>
    <property name="age"/>
  </settings>
  <switch id="swContent">
    <bindRule rule="rAdultMaleCombined" constituent="mTargeted"/>
    <defaultComponent component="mDefault"/>
    <media id="mTargeted" src="targeted.mp4"/>
    <media id="mDefault" src="default.mp4"/>
  </switch>
</body>
</ncl>
''';

      final doc = NCLDocument.fromContent(
        xml,
        userData: '''
      {
        "id": "u1",
        "name": "User One",
        "properties": {"gender": "male", "age": 16}
      }
      ''',
      );

      final sw = doc.getNodeById('swContent') as Switch;
      expect(doc.evaluateRule('rAdultMaleCombined'), isFalse);
      expect(doc.resolveSwitch(sw)?.id, equals('mDefault'));

      doc.users.setUserProperty('u1', 'age', 21);
      expect(doc.evaluateRule('rAdultMaleCombined'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mTargeted'));
    });
  });
}
