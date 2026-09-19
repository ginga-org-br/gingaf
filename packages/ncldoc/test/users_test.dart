import 'package:ncldoc/ncl_document.dart';
import 'package:test/test.dart';

void main() {
  group('NclDocument Users and UserSettings Tests', () {
    test('verifies all required viewer profile basic attributes', () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="uViewer1" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
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
    </media>
    <media id="m1"/>
  </body>
</ncl>
''';
      const usersJson = '''
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
''';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      final user = doc.users.currentUser;
      expect(user, isNotNull);
      expect(user!.id, equals('uViewer1'));

      final settingsNode = doc.getElementById('userSettings') as UserSettings;

      expect(doc.getPropertyValue(settingsNode, 'nickname'), equals('Alice'));
      expect(doc.getPropertyValue(settingsNode, 'parentalControl'),
          equals('true'));
      expect(
          doc.getPropertyValue(settingsNode, 'maxContentRating'), equals('14'));
      expect(doc.getPropertyValue(settingsNode, 'avatar'), equals('alice.png'));
      expect(
          doc.getPropertyValue(settingsNode, 'audioLanguage'), equals('pt-BR'));
      expect(doc.getPropertyValue(settingsNode, 'closedCaptioningLanguage'),
          equals('pt-BR'));
      expect(doc.getPropertyValue(settingsNode, 'userInterfaceLanguage'),
          equals('pt-BR'));
      expect(doc.getPropertyValue(settingsNode, 'closedCaptioning'),
          equals('true'));
      expect(
          doc.getPropertyValue(settingsNode, 'closedSigning'), equals('false'));
      expect(doc.getPropertyValue(settingsNode, 'closedSigningSide'),
          equals('right'));
      expect(doc.getPropertyValue(settingsNode, 'closedSigningWidth'),
          equals('28'));
      expect(doc.getPropertyValue(settingsNode, 'audioDescription'),
          equals('false'));
      expect(doc.getPropertyValue(settingsNode, 'dialogEnhancement'),
          equals('false'));
      expect(
          doc.getPropertyValue(settingsNode, 'voiceGuidance'), equals('false'));
    });

    test('fails to parse UserSettings without user attribute', () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="u1" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uSettings" type="application/x-ncl-user-settings"/>
  </body>
</ncl>
''';
      expect(() => NclDocument.fromContent(xml), throwsFormatException);
    });

    test(
        'fails to parse UserSettings when user attribute does not match userProfile or currentUser',
        () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="u1" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uSettings" type="application/x-ncl-user-settings" user="uUnknown"/>
  </body>
</ncl>
''';
      expect(() => NclDocument.fromContent(xml), throwsFormatException);
    });

    test('parses UserSettings with valid user attribute', () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="u1" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uSettings1" type="application/x-ncl-user-settings" user="currentUser"/>
    <media id="uSettings2" type="application/x-ncl-user-settings" user="u1"/>
  </body>
</ncl>
''';
      final doc = NclDocument.fromContent(xml);
      final s1 = doc.getElementById('uSettings1') as UserSettings;
      final s2 = doc.getElementById('uSettings2') as UserSettings;
      expect(s1.user, equals('currentUser'));
      expect(s2.user, equals('u1'));
    });

    test(
        'verifies current User dynamic property update and instant switch constituent re-evaluation',
        () {
      const xml = '''
<ncl id="dynPropDoc">
<head>
<userBase>
  <userProfile id="u1" max="1"/>
</userBase>
<ruleBase>
  <rule id="rCC" user="currentUser" var="closedCaptioning" comparator="eq" value="true"/>
</ruleBase>
</head>
<body>
<media id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
  <property name="closedCaptioning"/>
</media>
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
      const usersJson = '''
{
  "id": "u1",
  "name": "Viewer",
  "properties": {
    "closedCaptioning": false
  }
}
''';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      final sw = doc.getSwitchById('swSub')!;
      expect(doc.evaluateRule('rCC'), isFalse);
      expect(doc.resolveSwitch(sw)?.id, equals('mNoSub'));

      doc.users.setUserProperty('u1', 'closedCaptioning', true);
      expect(doc.evaluateRule('rCC'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mSub'));
    });

    test('verifies multi-user profile evaluation with composite rules', () {
      const xml = '''
<ncl id="multiUserDoc">
<head>
<userBase>
  <userProfile id="pAdult" max="1"/>
</userBase>
<ruleBase>
  <rule id="rAdult" user="currentUser" var="age" comparator="gt" value="16"/>
  <rule id="rCC" user="currentUser" var="closedCaptioning" comparator="eq" value="true"/>
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
<media id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
  <property name="age"/>
  <property name="closedCaptioning"/>
</media>
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
      const usersJson1 =
          '[{"id": "u1", "name": "AdultCC", "properties": {"age": "25", "closedCaptioning": "true"}}]';
      final docAdultCC = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson1),
          ),
        ),
      );

      final sw1 = docAdultCC.getSwitchById('swAd')!;
      expect(docAdultCC.evaluateRule('rAdultWithCC'), isTrue);
      expect(docAdultCC.resolveSwitch(sw1)?.id, equals('mAdultCCAd'));

      const usersJson2 =
          '[{"id": "u2", "name": "AdultNoCC", "properties": {"age": "25", "closedCaptioning": "false"}}]';
      final docAdultNoCC = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson2),
          ),
        ),
      );

      final sw2 = docAdultNoCC.getSwitchById('swAd')!;
      expect(docAdultNoCC.evaluateRule('rAdultWithCC'), isFalse);
      expect(docAdultNoCC.evaluateRule('rAdult'), isTrue);
      expect(docAdultNoCC.resolveSwitch(sw2)?.id, equals('mAdultAd'));
    });

    test('verifies dynamic user property update and rule re-evaluation', () {
      const xml = '''
<ncl id="dynamicDoc">
<head>
<userBase>
  <userProfile id="u1" max="1"/>
</userBase>
<ruleBase>
  <rule id="rAdult" user="currentUser" var="age" comparator="gte" value="18"/>
</ruleBase>
</head>
<body>
<media id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
  <property name="age"/>
</media>
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
      const usersJson =
          '[{"id": "u1", "name": "YoungUser", "properties": {"age": "16"}}]';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      final sw = doc.getSwitchById('swContent')!;
      expect(doc.evaluateRule('rAdult'), isFalse);
      expect(doc.resolveSwitch(sw)?.id, equals('mPublic'));

      doc.users.setUserProperty('u1', 'age', '20');
      expect(doc.evaluateRule('rAdult'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mRestricted'));
    });

    test(
        'verifies current User switching in document context and rule re-evaluation',
        () {
      const xml = '''
<ncl id="switchUserDoc">
<head>
<userBase>
  <userProfile id="u1" max="1"/>
  <userProfile id="u2" max="1"/>
</userBase>
<ruleBase>
  <rule id="rPortuguese" user="currentUser" var="lang" comparator="eq" value="pt-BR"/>
</ruleBase>
</head>
<body>
<media id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
  <property name="lang"/>
</media>
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
      const usersJson = '''
[
  {"id": "u1", "name": "User PT", "properties": {"lang": "pt-BR"}},
  {"id": "u2", "name": "User EN", "properties": {"lang": "en-US"}}
]
''';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      final sw = doc.getSwitchById('swLang')!;
      expect(doc.users.currentUser?.id, equals('u1'));
      expect(doc.evaluateRule('rPortuguese'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mPT'));

      doc.users.setCurrentUser('u2');
      expect(doc.users.currentUser?.id, equals('u2'));
      expect(doc.evaluateRule('rPortuguese'), isFalse);
      expect(doc.resolveSwitch(sw)?.id, equals('mEN'));
    });

    test(
        'verifies multi-user session profile switching and dynamic rule evaluation',
        () {
      const xml = '''
<ncl id="sessProfileDoc">
<head>
<userBase>
  <userProfile id="u1" max="1"/>
  <userProfile id="u2" max="1"/>
</userBase>
<ruleBase>
  <rule id="rAdult" user="currentUser" var="age" comparator="gte" value="18"/>
  <rule id="rMinor" user="currentUser" var="age" comparator="lt" value="18"/>
</ruleBase>
</head>
<body>
<media id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
  <property name="age"/>
  <property name="closedCaptioning"/>
</media>
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
      const usersJson = '''
[
  {"id": "u1", "name": "Adult", "properties": {"age": 25}},
  {"id": "u2", "name": "Child", "properties": {"age": 10}}
]
''';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      doc.users.setCurrentUser('u1');
      final sw = doc.getSwitchById('swAd')!;
      expect(doc.evaluateRule('rAdult'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mAdult'));

      doc.users.setCurrentUser('u2');
      expect(doc.evaluateRule('rMinor'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mMinor'));
    });

    test(
        'verifies multi-user session profile export import, migration, and manager teardown',
        () {
      const xml = '''
<ncl id="sessionDoc">
<head>
<userBase>
  <userProfile id="u1" max="1"/>
  <userProfile id="u2" max="1"/>
</userBase>
<ruleBase>
  <rule id="rAdult" user="currentUser" var="age" comparator="gte" value="18"/>
  <rule id="rLangEN" user="currentUser" var="preferredLang" comparator="eq" value="en"/>
  <compositeRule id="rAdultEN" operator="and">
    <rule id="rAdult"/>
    <rule id="rLangEN"/>
  </compositeRule>
</ruleBase>
</head>
<body>
<media id="userSettings" type="application/x-ncl-user-settings" user="currentUser">
  <property name="age"/>
  <property name="preferredLang"/>
</media>
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
      const usersJson = '''
[
  {"id": "u1", "name": "Alice", "properties": {"age": 25, "preferredLang": "en"}},
  {"id": "u2", "name": "Bob", "properties": {"age": 16, "preferredLang": "es"}}
]
''';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      final users = doc.users;
      users.setCurrentUser('u1');
      final sw = doc.getSwitchById('swAd')!;
      expect(doc.evaluateRule('rAdultEN'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mAdultEN'));

      users.setUserProperty('u1', 'preferredLang', 'es');
      expect(doc.evaluateRule('rAdultEN'), isFalse);
      expect(doc.evaluateRule('rAdult'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mAdult'));

      users.clear();
      expect(users.getUser('u1'), isNull);
    });

    test('stores and updates properties on UserData in document context', () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="user1" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uSettings" type="application/x-ncl-user-settings" user="currentUser">
      <property name="age"/>
      <property name="language"/>
      <property name="theme"/>
    </media>
  </body>
</ncl>
''';
      const usersJson = '''
{
  "id": "user1",
  "name": "Alice",
  "properties": {
    "age": 25,
    "language": "pt-BR"
  }
}
''';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      final user = doc.users.currentUser!;
      expect(user.id, equals('user1'));
      expect(user.name, equals('Alice'));
      expect(user.getProperty('age'), equals(25));
      expect(user.getProperty('language'), equals('pt-BR'));
      expect(user.hasProperty('age'), isTrue);
      expect(user.hasProperty('gender'), isFalse);

      user.setProperty('theme', 'dark');
      expect(user.getProperty('theme'), equals('dark'));
      final settings = doc.getElementById('uSettings') as UserSettings;
      expect(doc.getPropertyValue(settings, 'theme'), equals('dark'));
    });

    test('registers users and sets current Users from JSON and runtime', () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="u1" max="1"/>
      <userProfile id="u2" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uSettings" type="application/x-ncl-user-settings" user="currentUser">
      <property name="name"/>
    </media>
  </body>
</ncl>
''';
      const usersJson = '''
[
  {"id": "u1", "name": "User One"},
  {"id": "u2", "name": "User Two"}
]
''';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      expect(doc.users.allUsers.length, equals(2));
      expect(doc.users.currentUser?.id, equals('u1'));

      doc.users.setCurrentUser('u2');
      expect(doc.users.currentUser?.id, equals('u2'));
      expect(doc.users.getUser('u1')?.name, equals('User One'));

      final settings = doc.getElementById('uSettings') as UserSettings;
      expect(doc.getPropertyValue(settings, 'name'), equals('User Two'));
    });

    test('gets and sets user properties synchronously and handles user removal',
        () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="u1" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uSettings" type="application/x-ncl-user-settings" user="currentUser">
      <property name="preferredQuality"/>
    </media>
  </body>
</ncl>
''';
      const usersJson = '{"id": "u1", "name": "User One"}';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      expect(doc.users.setUserProperty('u1', 'preferredQuality', 'HD'), isTrue);
      expect(doc.users.getUserProperty('u1', 'preferredQuality'), equals('HD'));

      final settings = doc.getElementById('uSettings') as UserSettings;
      expect(doc.getPropertyValue(settings, 'preferredQuality'), equals('HD'));

      doc.users.removeUser('u1');
      expect(doc.users.getUser('u1'), isNull);
      expect(doc.users.currentUser, isNull);
    });

    test('loads user data via JSON param into document', () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="uRemote1" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uSettings" type="application/x-ncl-user-settings" user="uRemote1">
      <property name="level"/>
    </media>
  </body>
</ncl>
''';
      const usersJson = '{}';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      const remoteUserJson =
          '{"id": "uRemote1", "name": "Remote User", "properties": {"level": "premium"}}';
      doc.users.loadUserData(remoteUserJson);

      expect(doc.users.getUser('uRemote1'), isNotNull);
      expect(doc.users.getUserProperty('uRemote1', 'level'), equals('premium'));

      final settings = doc.getElementById('uSettings') as UserSettings;
      expect(doc.getPropertyValue(settings, 'level'), equals('premium'));
    });

    test(
        'evaluates profile query with numeric comparison operators in document context',
        () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="u1" max="1"/>
      <userProfile id="u2" max="1"/>
      <userProfile id="profileGte" max="1"/>
      <userProfile id="profileLt" max="1"/>
      <userProfile id="profileGt" max="1"/>
      <userProfile id="profileLte" max="1"/>
      <userProfile id="profileNe" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uAdult" type="application/x-ncl-user-settings" user="u1">
      <property name="age"/>
      <property name="rating"/>
    </media>
    <media id="uMinor" type="application/x-ncl-user-settings" user="u2">
      <property name="age"/>
      <property name="rating"/>
    </media>
  </body>
</ncl>
''';
      const usersJson = '''
[
  {"id": "u1", "name": "Adult", "properties": {"age": 20, "rating": 4.5}},
  {"id": "u2", "name": "Minor", "properties": {"age": 15, "rating": 2.0}}
]
''';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      final userAdult = doc.users.getUser('u1')!;
      final userMinor = doc.users.getUser('u2')!;

      final profileGte = UserProfileQuery(
          {'attribute': 'age', 'comparator': 'gte', 'value': 18});
      final profileLt = UserProfileQuery(
          {'attribute': 'age', 'comparator': 'lt', 'value': 18});
      final profileGt = UserProfileQuery(
          {'attribute': 'rating', 'comparator': 'gt', 'value': 3.0});
      final profileLte = UserProfileQuery(
          {'attribute': 'rating', 'comparator': 'lte', 'value': 2.0});
      final profileNe = UserProfileQuery(
          {'attribute': 'age', 'comparator': 'neq', 'value': 15});

      expect(doc.users.getMatchingUsersForProfile(profileGte),
          contains(userAdult));
      expect(doc.users.getMatchingUsersForProfile(profileGte),
          isNot(contains(userMinor)));

      expect(doc.users.getMatchingUsersForProfile(profileLt),
          isNot(contains(userAdult)));
      expect(
          doc.users.getMatchingUsersForProfile(profileLt), contains(userMinor));

      expect(
          doc.users.getMatchingUsersForProfile(profileGt), contains(userAdult));
      expect(doc.users.getMatchingUsersForProfile(profileGt),
          isNot(contains(userMinor)));

      expect(doc.users.getMatchingUsersForProfile(profileLte),
          contains(userMinor));

      expect(
          doc.users.getMatchingUsersForProfile(profileNe), contains(userAdult));
      expect(doc.users.getMatchingUsersForProfile(profileNe),
          isNot(contains(userMinor)));
    });

    test(
        'evaluates profile query with nested AND and OR operators in document context',
        () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="u1" max="1"/>
      <userProfile id="profileAnd" max="1"/>
      <userProfile id="profileOr" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uSettings" type="application/x-ncl-user-settings" user="u1">
      <property name="age"/>
      <property name="gender"/>
      <property name="lang"/>
    </media>
  </body>
</ncl>
''';
      const usersJson = '''
{
  "id": "u1",
  "name": "Alice",
  "properties": {"age": 25, "gender": "female", "lang": "pt"}
}
''';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      final user = doc.users.getUser('u1')!;

      final profileAnd = UserProfileQuery({
        'operator': 'and',
        'rules': [
          {'attribute': 'age', 'comparator': 'gte', 'value': 18},
          {'attribute': 'gender', 'comparator': 'eq', 'value': 'female'},
        ],
      });
      final profileOr = UserProfileQuery({
        'operator': 'or',
        'rules': [
          {'attribute': 'lang', 'comparator': 'eq', 'value': 'en'},
          {'attribute': 'lang', 'comparator': 'eq', 'value': 'pt'},
        ],
      });

      expect(doc.users.getMatchingUsersForProfile(profileAnd), contains(user));
      expect(doc.users.getMatchingUsersForProfile(profileOr), contains(user));
    });

    test(
        'evaluates profile with getMatchingUsersForProfile in document context',
        () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="u1" max="1"/>
      <userProfile id="profileGold" max="1"/>
      <userProfile id="profileVip" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uSettings" type="application/x-ncl-user-settings" user="u1">
      <property name="tier"/>
      <property name="credits"/>
    </media>
  </body>
</ncl>
''';
      const usersJson = '''
[
  {"id": "u1", "name": "User 1", "properties": {"tier": "gold", "credits": 100}},
  {"id": "u2", "name": "User 2", "properties": {"tier": "silver", "credits": 20}}
]
''';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      final profileGold = UserProfileQuery(
          {'attribute': 'tier', 'comparator': 'eq', 'value': 'gold'});
      final profileVip = UserProfileQuery(
          {'attribute': 'credits', 'comparator': 'gte', 'value': 500});

      final goldUsers = doc.users.getMatchingUsersForProfile(profileGold);
      expect(goldUsers.map((u) => u.id), contains('u1'));
      expect(goldUsers.map((u) => u.id), isNot(contains('u2')));
      expect(doc.users.getMatchingUsersForProfile(profileVip), isEmpty);
    });

    test('retrieves all matching users for profile in document context', () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="u1" max="1"/>
      <userProfile id="profileAdmin" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uAdmin" type="application/x-ncl-user-settings" user="u1">
      <property name="role"/>
      <property name="points"/>
    </media>
  </body>
</ncl>
''';
      const usersJson = '''
[
  {"id": "u1", "name": "User 1", "properties": {"role": "admin", "points": 100}},
  {"id": "u2", "name": "User 2", "properties": {"role": "guest", "points": 50}},
  {"id": "u3", "name": "User 3", "properties": {"role": "admin", "points": 200}}
]
''';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      final profileAdmin = UserProfileQuery(
          {'attribute': 'role', 'comparator': 'eq', 'value': 'admin'});

      final matchingAdmins = doc.users.getMatchingUsersForProfile(profileAdmin);
      expect(matchingAdmins.map((u) => u.id), containsAll(['u1', 'u3']));
      expect(matchingAdmins.map((u) => u.id), isNot(contains('u2')));
      expect(matchingAdmins.length, equals(2));
    });

    test(
        'supports UserProfileQuery fromJson and toJson serialization in document context',
        () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="u1" max="1"/>
      <userProfile id="profileGte" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uSettings" type="application/x-ncl-user-settings" user="u1">
      <property name="age"/>
    </media>
  </body>
</ncl>
''';
      const usersJson =
          '{"id": "u1", "name": "Adult", "properties": {"age": 20}}';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      final profile = UserProfileQuery(
          {'attribute': 'age', 'comparator': 'gte', 'value': '18'});
      expect(profile.query['attribute'], equals('age'));

      final userAdult = doc.users.getUser('u1')!;
      expect(
          doc.users.getMatchingUsersForProfile(profile), contains(userAdult));

      final exportedJson = profile.toJson();
      expect(exportedJson,
          equals({'attribute': 'age', 'comparator': 'gte', 'value': '18'}));
    });

    test(
        'evaluates neq comparator and Users batch helper methods in document context',
        () {
      const xml = '''
<ncl>
  <head>
    <userBase>
      <userProfile id="u1" max="1"/>
      <userProfile id="u2" max="1"/>
      <userProfile id="pNeq" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uAdmin" type="application/x-ncl-user-settings" user="u1">
      <property name="role"/>
      <property name="city"/>
    </media>
    <media id="uGuest" type="application/x-ncl-user-settings" user="u2">
      <property name="role"/>
      <property name="city"/>
    </media>
  </body>
</ncl>
''';
      const usersJson = '''
[
  {"id": "u1", "name": "Alice", "properties": {"role": "admin", "city": "San Francisco", "tags": "flutter,dart,ncl"}},
  {"id": "u2", "name": "Bob", "properties": {"role": "guest", "city": "San Jose", "tags": "python,ncl"}}
]
''';
      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users(usersJson),
          ),
        ),
      );

      expect(doc.users.allUsers.length, equals(2));
      expect(doc.users.getCurrentUserProperty('role'), equals('admin'));

      final admins = doc.users.getUsersByProperty('role', 'admin');
      expect(admins.map((u) => u.id), equals(['u1']));

      final pNeq = UserProfileQuery(
          {'attribute': 'role', 'comparator': 'neq', 'value': 'guest'});

      final u1 = doc.users.getUser('u1')!;
      final u2 = doc.users.getUser('u2')!;
      final matchingUsers = doc.users.getMatchingUsersForProfile(pNeq);
      expect(matchingUsers, contains(u1));
      expect(matchingUsers, isNot(contains(u2)));
      expect(matchingUsers.length, equals(1));
    });
  });

  group('NCL User Profile Tests', () {
    test(
      'onBeginTestVarStart triggers male ad when current User gender is male',
      () {
        final xmlString = '''
<ncl id="multiUserDoc">
  <head>
    <regionBase>
      <region id="rgAd" left="75%" top="75%" width="20%" height="20%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dAd" region="rgAd"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onBeginTestVarStart">
        <compoundCondition operator="and">
          <simpleCondition role="onBegin"/>
          <assessmentStatement comparator="eq">
            <attributeAssessment role="var" attributeType="nodeProperty" eventType="attribution"/>
            <valueAssessment value="\$value"/>
          </assessmentStatement>
        </compoundCondition>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
    <userBase>
      <userProfile id="pAdult" src="adult_query.json" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uSettings" type="application/x-ncl-user-settings" user="pAdult">
      <property name="gender"/>
    </media>
    <port id="pMain" component="mVideo"/>
    <media id="mVideo" src="video.mp4">
      <area id="aSec2" begin="2s"/>
    </media>
    <media id="mMaleAd" src="ad_male.png" descriptor="dAd"/>
    <media id="mGeneralAd" src="ad_general.png" descriptor="dAd"/>
    <link xconnector="onBeginTestVarStart">
      <bind role="onBegin" component="mVideo" interface="aSec2"/>
      <bind role="var" component="uSettings" interface="gender"/>
      <bindParam name="value" value="male"/>
      <bind role="start" component="mMaleAd"/>
    </link>
    <link xconnector="onBeginTestVarStart">
      <bind role="onBegin" component="mVideo" interface="aSec2"/>
      <bind role="var" component="uSettings" interface="gender"/>
      <bindParam name="value" value="female"/>
      <bind role="start" component="mGeneralAd"/>
    </link>
  </body>
</ncl>
''';

        final gingacc = GingaCC(
          config: GingaConfig(
            users: Users(
              '[{"id": "u1", "name": "Bob", "gender": "male", "age": 30}]',
            ),
          ),
        );
        final doc = NclDocument.fromContent(
          xmlString,
          gingacc: gingacc,
        );

        doc.start();
        expect(doc.isPlaying, isTrue);

        final mMaleAd = doc.getNodeById('mMaleAd') as Media;
        final mGeneralAd = doc.getNodeById('mGeneralAd') as Media;

        expect(mMaleAd.getMainState(), equals(NclStateType.sleeping));
        expect(mGeneralAd.getMainState(), equals(NclStateType.sleeping));

        doc.tick(2000);

        expect(mMaleAd.getMainState(), equals(NclStateType.occurring));
        expect(mGeneralAd.getMainState(), equals(NclStateType.sleeping));
      },
    );

    test(
      'onBeginTestVarStart triggers general ad when current User gender is female',
      () {
        final xmlString = '''
<ncl id="multiUserDoc">
  <head>
    <regionBase>
      <region id="rgAd" left="75%" top="75%" width="20%" height="20%"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dAd" region="rgAd"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onBeginTestVarStart">
        <compoundCondition operator="and">
          <simpleCondition role="onBegin"/>
          <assessmentStatement comparator="eq">
            <attributeAssessment role="var" attributeType="nodeProperty" eventType="attribution"/>
            <valueAssessment value="\$value"/>
          </assessmentStatement>
        </compoundCondition>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
    <userBase>
      <userProfile id="pAdult" src="adult_query.json" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uSettings" type="application/x-ncl-user-settings" user="pAdult">
      <property name="gender"/>
    </media>
    <port id="pMain" component="mVideo"/>
    <media id="mVideo" src="video.mp4">
      <area id="aSec2" begin="2s"/>
    </media>
    <media id="mMaleAd" src="ad_male.png" descriptor="dAd"/>
    <media id="mGeneralAd" src="ad_general.png" descriptor="dAd"/>
    <link xconnector="onBeginTestVarStart">
      <bind role="onBegin" component="mVideo" interface="aSec2"/>
      <bind role="var" component="uSettings" interface="gender"/>
      <bindParam name="value" value="male"/>
      <bind role="start" component="mMaleAd"/>
    </link>
    <link xconnector="onBeginTestVarStart">
      <bind role="onBegin" component="mVideo" interface="aSec2"/>
      <bind role="var" component="uSettings" interface="gender"/>
      <bindParam name="value" value="female"/>
      <bind role="start" component="mGeneralAd"/>
    </link>
  </body>
</ncl>
''';

        final gingacc = GingaCC(
          config: GingaConfig(
            users: Users(
              '[{"id": "u2", "name": "Alice", "gender": "female", "age": 30}]',
            ),
          ),
        );
        final doc = NclDocument.fromContent(
          xmlString,
          gingacc: gingacc,
        );

        doc.start();
        expect(doc.isPlaying, isTrue);

        final mMaleAd = doc.getNodeById('mMaleAd') as Media;
        final mGeneralAd = doc.getNodeById('mGeneralAd') as Media;

        expect(mMaleAd.getMainState(), equals(NclStateType.sleeping));
        expect(mGeneralAd.getMainState(), equals(NclStateType.sleeping));

        doc.tick(2000);

        expect(mMaleAd.getMainState(), equals(NclStateType.sleeping));
        expect(mGeneralAd.getMainState(), equals(NclStateType.occurring));
      },
    );

    // NOT COMPLIANT: <rule> with user
    test(
      'evaluates rule with explicit user attribute bound to user settings and current User profile',
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
  <media id="uSettings" type="application/x-ncl-user-settings" user="pAdult">
    <property name="gender"/>
  </media>
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

        final doc = NclDocument.fromContent(
          xml,
          gingacc: GingaCC(
            config: GingaConfig(
              users: Users('''
        {
          "id": "u1",
          "name": "Bob",
          "properties": {
            "gender": "male",
            "age": 30
          }
        }
        '''),
            ),
          ),
        );

        final sw = doc.getSwitchById('swAd')!;
        expect(doc.evaluateRule('rMale'), isTrue);
        expect(doc.evaluateRule('rFemale'), isFalse);
        expect(doc.resolveSwitch(sw)?.id, equals('mMaleAd'));
      },
    );

    test('updates user profile dynamic property and re-evaluates active rules',
        () {
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
  <media id="userSet" type="application/x-ncl-user-settings" user="u1">
    <property name="age"/>
  </media>
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

      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users('''
      {
        "id": "u1",
        "name": "Alice",
        "properties": {
          "age": 20
        }
      }
      '''),
          ),
        ),
      );

      final sw = doc.getSwitchById('swAge')!;
      expect(doc.evaluateRule('rAge30'), isFalse);
      expect(doc.resolveSwitch(sw)?.id, equals('mChild'));

      doc.users.setUserProperty('u1', 'age', 35);
      expect(doc.evaluateRule('rAge30'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mAdult'));
    });

    test('supports switching current User profile dynamically', () {
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
  <media id="uSettings" type="application/x-ncl-user-settings" user="pUser">
    <property name="tier"/>
  </media>
  <switch id="swTier">
    <bindRule rule="rPremium" constituent="mGoldContent"/>
    <defaultComponent component="mFreeContent"/>
    <media id="mGoldContent" src="gold.mp4"/>
    <media id="mFreeContent" src="free.mp4"/>
  </switch>
</body>
</ncl>
''';

      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users('''
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
      '''),
          ),
        ),
      );

      final sw = doc.getSwitchById('swTier')!;
      expect(doc.evaluateRule('rPremium'), isFalse);
      expect(doc.resolveSwitch(sw)?.id, equals('mFreeContent'));

      doc.users.setCurrentUser('user2');
      expect(doc.evaluateRule('rPremium'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mGoldContent'));
    });

    test(
        'evaluates compound rules bound to user properties accurately across user state updates',
        () {
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
  <media id="uSettings" type="application/x-ncl-user-settings" user="pUser">
    <property name="gender"/>
    <property name="age"/>
  </media>
  <switch id="swContent">
    <bindRule rule="rAdultMaleCombined" constituent="mTargeted"/>
    <defaultComponent component="mDefault"/>
    <media id="mTargeted" src="targeted.mp4"/>
    <media id="mDefault" src="default.mp4"/>
  </switch>
</body>
</ncl>
''';

      final doc = NclDocument.fromContent(
        xml,
        gingacc: GingaCC(
          config: GingaConfig(
            users: Users('''
      {
        "id": "u1",
        "name": "User One",
        "properties": {"gender": "male", "age": 16}
      }
      '''),
          ),
        ),
      );

      final sw = doc.getSwitchById('swContent')!;
      expect(doc.evaluateRule('rAdultMaleCombined'), isFalse);
      expect(doc.resolveSwitch(sw)?.id, equals('mDefault'));

      doc.users.setUserProperty('u1', 'age', 21);
      expect(doc.evaluateRule('rAdultMaleCombined'), isTrue);
      expect(doc.resolveSwitch(sw)?.id, equals('mTargeted'));
    });
    // NOT COMPLIANT ends

    test(
      'current_user sets user properties on lua media using virtual files',
      () async {
        const currentUserNcl = '''<ncl id="multiUserDoc">
  <head>
    <regionBase>
      <region id="rgTop" left="5%" top="3%" width="90%" height="12%" zIndex="10"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dTop" region="rgTop"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onEndStop">
        <simpleCondition role="onEnd"/>
        <simpleAction role="stop"/>
      </causalConnector>
      <causalConnector id="onBeginOrAttributionSet">
        <connectorParam name="var"/>
        <compoundCondition operator="or">
          <simpleCondition role="onBegin"/>
          <simpleCondition role="onEndAttribution"/>
        </compoundCondition>
        <simpleAction role="set" value="\$var" max="unbounded" qualifier="par"/>
      </causalConnector>
    </connectorBase>
  </head>
  <body id="body">
    <media id="uSettings" type="application/x-ncl-user-settings" user="currentUser">
      <property name="id"/>
      <property name="name"/>
      <property name="gender"/>
      <property name="age"/>
    </media>
    <port id="pMain" component="mVideo"/>
    <port id="pTop" component="mUserLua"/>
    <media id="mUserLua" src="user_info.lua" descriptor="dTop">
      <property name="userId"/>
      <property name="userName"/>
      <property name="userGender"/>
      <property name="userAge"/>
    </media>
    <media id="mVideo" src="https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4"/>
    <link xconnector="onBeginOrAttributionSet">
      <bind role="onBegin" component="mVideo"/>
      <bind role="onEndAttribution" component="uSettings" interface="id"/>
      <bind role="get1" component="uSettings" interface="id"/>
      <bind role="get2" component="uSettings" interface="name"/>
      <bind role="get3" component="uSettings" interface="gender"/>
      <bind role="get4" component="uSettings" interface="age"/>
      <bind role="set" component="mUserLua" interface="userId">
        <bindParam name="var" value="\$get1"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userName">
        <bindParam name="var" value="\$get2"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userGender">
        <bindParam name="var" value="\$get3"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userAge">
        <bindParam name="var" value="\$get4"/>
      </bind>
    </link>
  </body>
</ncl>''';

        const userInfoLua = '''local event = event or require('event')

local userId = ""
local userName = ""
local userGender = ""
local userAge = ""

local function draw()
    canvas:clear()
    local w, h = canvas:attrSize()
    w = w or 1280
    h = h or 100
    canvas:attrColor(15, 20, 30, 220)
    canvas:drawRoundRect('fill', 0, 0, w, h, 12, 12)
    canvas:attrColor(80, 120, 200, 255)
    canvas:drawRoundRect('frame', 0, 0, w, h, 12, 12)
    canvas:attrColor(255, 255, 255, 255)
    canvas:attrFont('default', 22, 'normal', 'bold')
    local text = string.format('User Settings: "id": %s    "name": %s    "gender": %s    "age": %s',
        tostring(userId), tostring(userName), tostring(userGender), tostring(userAge))
    canvas:drawTextRect(text, 20, 0, w - 40, h, 'center', 'center')
    canvas:flush()
end

draw()

event.register(function(evt)
    if evt.class == 'ncl' and evt.type == 'attribution' then
        local prop = evt.name
        local val = evt.value
        if prop == 'userId' or prop == 'id' then
            userId = val
        elseif prop == 'userName' or prop == 'name' then
            userName = val
        elseif prop == 'userGender' or prop == 'gender' then
            userGender = val
        elseif prop == 'userAge' or prop == 'age' then
            userAge = val
        end
        draw()
    end
end)
''';

        const usersDataJson = '''[
  {
    "id": "u1",
    "name": "Bob",
    "gender": "male",
    "age": 30
  },
  {
    "id": "u3",
    "name": "Kid",
    "gender": "female",
    "age": 10
  }
]''';

        final gingacc = GingaCC(
          virtualFiles: {
            'current_user.ncl': currentUserNcl,
            'user_info.lua': userInfoLua,
            'users_data_with_adult_male.json': usersDataJson,
          },
          config: GingaConfig(
            appSrc: 'current_user.ncl',
            users: Users(usersDataJson),
          ),
        );

        final doc =
            await NclDocument.fromSrc('current_user.ncl', gingacc: gingacc);
        doc.start();

        final uSettings = doc.getElementById('uSettings') as Media;
        expect(doc.getPropertyValue(uSettings, 'id'), equals('u1'));
        expect(doc.getPropertyValue(uSettings, 'name'), equals('Bob'));
        expect(doc.getPropertyValue(uSettings, 'gender'), equals('male'));
        expect(doc.getPropertyValue(uSettings, 'age'), equals('30'));

        final mUserLua = doc.getElementById('mUserLua') as Media;
        expect(doc.getPropertyValue(mUserLua, 'userId'), equals('u1'));
        expect(doc.getPropertyValue(mUserLua, 'userName'), equals('Bob'));
        expect(doc.getPropertyValue(mUserLua, 'userGender'), equals('male'));
        expect(doc.getPropertyValue(mUserLua, 'userAge'), equals('30'));

        final changes = doc.users.diffNewCurrentUser('u3');
        doc.users.setCurrentUser('u3');
        for (final entry in changes.entries) {
          doc.dispatchSettingsUpdate(entry.key, entry.value,
              userId: 'currentUser');
        }
        doc.tick(0);

        expect(doc.users.currentUser?.id, equals('u3'));
        expect(doc.getPropertyValue(uSettings, 'id'), equals('u3'));
        expect(doc.getPropertyValue(uSettings, 'name'), equals('Kid'));
        expect(doc.getPropertyValue(uSettings, 'gender'), equals('female'));
        expect(doc.getPropertyValue(uSettings, 'age'), equals('10'));

        expect(doc.getPropertyValue(mUserLua, 'userId'), equals('u3'));
        expect(doc.getPropertyValue(mUserLua, 'userName'), equals('Kid'));
        expect(doc.getPropertyValue(mUserLua, 'userGender'), equals('female'));
        expect(doc.getPropertyValue(mUserLua, 'userAge'), equals('10'));
      },
    );

    test(
      'multiuser_profile triggers ad start and stop with userProfile',
      () async {
        const xml = '''
<ncl id="multiUserDoc">
  <head>
    <regionBase>
      <region id="rgTop" left="5%" top="3%" width="90%" height="12%" zIndex="10"/>
      <region id="rgAd" left="75%" top="75%" width="20%" height="20%" zIndex="5"/>
    </regionBase>
    <descriptorBase>
      <descriptor id="dTop" region="rgTop"/>
      <descriptor id="dAd" region="rgAd"/>
    </descriptorBase>
    <connectorBase>
      <causalConnector id="onBeginSet">
        <connectorParam name="var"/>
        <simpleCondition role="onBegin"/>
        <simpleAction role="set" value="\$var" max="unbounded" qualifier="par"/>
      </causalConnector>
      <causalConnector id="onEndAttributionSet">
        <connectorParam name="var"/>
        <simpleCondition role="onEndAttribution"/>
        <simpleAction role="set" value="\$var" max="unbounded" qualifier="par"/>
      </causalConnector>
      <causalConnector id="onEndAttributionStop">
        <simpleCondition role="onEndAttribution"/>
        <simpleAction role="stop" max="unbounded" qualifier="par"/>
      </causalConnector>
      <causalConnector id="onBeginOrAttributionTestVarStart">
        <connectorParam name="var"/>
        <connectorParam name="value"/>
        <compoundCondition operator="and">
          <compoundCondition operator="or">
            <simpleCondition role="onBegin"/>
            <simpleCondition role="onEndAttribution"/>
          </compoundCondition>
          <assessmentStatement comparator="eq">
            <attributeAssessment role="var" attributeType="nodeProperty" eventType="attribution"/>
            <valueAssessment value="\$value"/>
          </assessmentStatement>
        </compoundCondition>
        <simpleAction role="start"/>
      </causalConnector>
    </connectorBase>
    <userBase>
      <userProfile id="pAdult" src="adult_query.json" max="1"/>
    </userBase>
  </head>
  <body id="body">
    <media id="uSettings" type="application/x-ncl-user-settings" user="currentUser">
      <property name="id"/>
      <property name="name"/>
      <property name="gender"/>
      <property name="age"/>
    </media>
    <media id="uAdult" type="application/x-ncl-user-settings" user="pAdult">
      <property name="gender"/>
    </media>
    <port id="pMain" component="mVideo"/>
    <port id="pTop" component="mUserLua"/>
    <media id="mUserLua" src="user_info.lua" descriptor="dTop">
      <property name="userId"/>
      <property name="userName"/>
      <property name="userGender"/>
      <property name="userAge"/>
    </media>
    <media id="mVideo" src="video.mp4"/>
    <media id="mMaleAd" src="ad_male.png" descriptor="dAd"/>
    <media id="mFemaleAd" src="ad_general.png" descriptor="dAd"/>
    <link xconnector="onBeginSet">
      <bind role="onBegin" component="mVideo"/>
      <bind role="get1" component="uSettings" interface="id"/>
      <bind role="get2" component="uSettings" interface="name"/>
      <bind role="get3" component="uSettings" interface="gender"/>
      <bind role="get4" component="uSettings" interface="age"/>
      <bind role="set" component="mUserLua" interface="userId">
        <bindParam name="var" value="\$get1"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userName">
        <bindParam name="var" value="\$get2"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userGender">
        <bindParam name="var" value="\$get3"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userAge">
        <bindParam name="var" value="\$get4"/>
      </bind>
    </link>
    <link xconnector="onEndAttributionSet">
      <bind role="onEndAttribution" component="uSettings" interface="id"/>
      <bind role="get" component="uSettings" interface="id"/>
      <bind role="get" component="uSettings" interface="name"/>
      <bind role="get" component="uSettings" interface="gender"/>
      <bind role="get" component="uSettings" interface="age"/>
      <bind role="set" component="mUserLua" interface="userGender">
        <bindParam name="var" value="\$get"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userName">
        <bindParam name="var" value="\$get"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userAge">
        <bindParam name="var" value="\$get"/>
      </bind>
      <bind role="set" component="mUserLua" interface="userId">
        <bindParam name="var" value="\$get"/>
      </bind>
    </link>
    <link xconnector="onEndAttributionStop">
      <bind role="onEndAttribution" component="uSettings" interface="id"/>
      <bind role="stop" component="mMaleAd"/>
      <bind role="stop" component="mFemaleAd"/>
    </link>
    <link xconnector="onBeginOrAttributionTestVarStart">
      <bind role="onBegin" component="mVideo"/>
      <bind role="onEndAttribution" component="uSettings" interface="id"/>
      <bind role="var" component="uAdult" interface="gender"/>
      <bindParam name="value" value="male"/>
      <bind role="start" component="mMaleAd"/>
    </link>
    <link xconnector="onBeginOrAttributionTestVarStart">
      <bind role="onBegin" component="mVideo"/>
      <bind role="onEndAttribution" component="uSettings" interface="id"/>
      <bind role="var" component="uAdult" interface="gender"/>
      <bindParam name="value" value="female"/>
      <bind role="start" component="mFemaleAd"/>
    </link>
  </body>
</ncl>
''';
        const usersDataJson = '''[
          {"id": "u1", "name": "Bob", "gender": "male", "age": 30},
          {"id": "u2", "name": "Alice", "gender": "female", "age": 30},
          {"id": "u3", "name": "Kid", "gender": "female", "age": 10}
        ]''';
        const adultQueryJson =
            '{"attribute": "age", "comparator": "gte", "value": "18"}';

        final gingacc = GingaCC(
          virtualFiles: {
            'adult_query.json': adultQueryJson,
          },
          config: GingaConfig(
            users: Users(usersDataJson),
          ),
        );

        final doc = NclDocument.fromContent(xml, gingacc: gingacc);
        await doc.loadUserProfiles();
        doc.start();
        doc.tick(0);

        final mMaleAd = doc.getMediaById('mMaleAd')!;
        final mFemaleAd = doc.getMediaById('mFemaleAd')!;
        final mUserLua = doc.getMediaById('mUserLua')!;

        expect(mMaleAd.getMainState(), equals(NclStateType.occurring));
        expect(mFemaleAd.getMainState(), equals(NclStateType.sleeping));
        expect(doc.getPropertyValue(mUserLua, 'userId'), equals('u1'));
        expect(doc.getPropertyValue(mUserLua, 'userName'), equals('Bob'));
        expect(doc.getPropertyValue(mUserLua, 'userGender'), equals('male'));
        expect(doc.getPropertyValue(mUserLua, 'userAge'), equals('30'));

        final changesToAlice = doc.users.diffNewCurrentUser('u2');
        doc.users.setCurrentUser('u2');
        for (final entry in changesToAlice.entries) {
          doc.dispatchSettingsUpdate(entry.key, entry.value,
              userId: 'currentUser');
        }
        doc.tick(0);

        expect(mMaleAd.getMainState(), equals(NclStateType.sleeping));
        expect(mFemaleAd.getMainState(), equals(NclStateType.occurring));
        expect(doc.getPropertyValue(mUserLua, 'userId'), equals('u2'));
        expect(doc.getPropertyValue(mUserLua, 'userName'), equals('Alice'));
        expect(doc.getPropertyValue(mUserLua, 'userGender'), equals('female'));
        expect(doc.getPropertyValue(mUserLua, 'userAge'), equals('30'));

        final changesToKid = doc.users.diffNewCurrentUser('u3');
        doc.users.setCurrentUser('u3');
        for (final entry in changesToKid.entries) {
          doc.dispatchSettingsUpdate(entry.key, entry.value,
              userId: 'currentUser');
        }
        doc.tick(0);

        expect(mMaleAd.getMainState(), equals(NclStateType.sleeping));
        expect(mFemaleAd.getMainState(), equals(NclStateType.sleeping));
        expect(doc.getPropertyValue(mUserLua, 'userId'), equals('u3'));
        expect(doc.getPropertyValue(mUserLua, 'userName'), equals('Kid'));
        expect(doc.getPropertyValue(mUserLua, 'userGender'), equals('female'));
        expect(doc.getPropertyValue(mUserLua, 'userAge'), equals('10'));

        final changesToBob = doc.users.diffNewCurrentUser('u1');
        doc.users.setCurrentUser('u1');
        for (final entry in changesToBob.entries) {
          doc.dispatchSettingsUpdate(entry.key, entry.value,
              userId: 'currentUser');
        }
        doc.tick(0);

        expect(mMaleAd.getMainState(), equals(NclStateType.occurring));
        expect(mFemaleAd.getMainState(), equals(NclStateType.sleeping));
        expect(doc.getPropertyValue(mUserLua, 'userId'), equals('u1'));
        expect(doc.getPropertyValue(mUserLua, 'userName'), equals('Bob'));
        expect(doc.getPropertyValue(mUserLua, 'userGender'), equals('male'));
        expect(doc.getPropertyValue(mUserLua, 'userAge'), equals('30'));
      },
    );

    test(
      'dispatchSettingsUpdate with userId=currentUser updates UserSettings with matching userProfile',
      () async {
        const xml = '''
<ncl id="multiUserDoc">
  <head>
    <connectorBase>
      <causalConnector id="onEndAttributionSet">
        <connectorParam name="var"/>
        <simpleCondition role="onEndAttribution"/>
        <simpleAction role="set" value="\$var" max="unbounded" qualifier="par"/>
      </causalConnector>
    </connectorBase>
    <userBase>
      <userProfile id="pAdult" src="adult_query.json" max="1"/>
    </userBase>
  </head>
  <body>
    <media id="uSettings" type="application/x-ncl-user-settings" user="pAdult">
      <property name="id"/>
      <property name="gender"/>
      <property name="age"/>
    </media>
  </body>
</ncl>
''';
        const usersDataJson = '''[
          {"id": "u1", "name": "Bob", "gender": "male", "age": 30},
          {"id": "u2", "name": "Alice", "gender": "female", "age": 30},
          {"id": "u3", "name": "Kid", "gender": "female", "age": 10}
        ]''';
        const adultQueryJson =
            '{"attribute": "age", "comparator": "gte", "value": "18"}';

        final gingacc = GingaCC(
          virtualFiles: {
            'adult_query.json': adultQueryJson,
          },
          config: GingaConfig(
            users: Users(usersDataJson),
          ),
        );

        final doc = NclDocument.fromContent(xml, gingacc: gingacc);
        await doc.loadUserProfiles();
        doc.start();
        doc.tick(0);

        final uSettings = doc.getElementById('uSettings') as UserSettings;
        expect(doc.getPropertyValue(uSettings, 'id'), equals('u1'));
        expect(doc.getPropertyValue(uSettings, 'gender'), equals('male'));

        // Switch to Alice (adult) -> profile matches -> uSettings is updated
        final changesAlice = doc.users.diffNewCurrentUser('u2');
        doc.users.setCurrentUser('u2');
        for (final entry in changesAlice.entries) {
          doc.dispatchSettingsUpdate(entry.key, entry.value,
              userId: 'currentUser');
        }
        doc.tick(0);

        expect(doc.getPropertyValue(uSettings, 'id'), equals('u2'));
        expect(doc.getPropertyValue(uSettings, 'gender'), equals('female'));

        // Switch to Kid (age 10 < 18) -> profile does NOT match -> uSettings is NOT updated
        final changesKid = doc.users.diffNewCurrentUser('u3');
        doc.users.setCurrentUser('u3');
        for (final entry in changesKid.entries) {
          doc.dispatchSettingsUpdate(entry.key, entry.value,
              userId: 'currentUser');
        }
        doc.tick(0);

        // Properties evaluate to null because Kid is not an adult
        expect(doc.getPropertyValue(uSettings, 'id'), isNull);
        expect(doc.getPropertyValue(uSettings, 'gender'), isNull);

        // Switch back to Bob (adult) -> profile matches -> uSettings is updated
        final changesBob = doc.users.diffNewCurrentUser('u1');
        doc.users.setCurrentUser('u1');
        for (final entry in changesBob.entries) {
          doc.dispatchSettingsUpdate(entry.key, entry.value,
              userId: 'currentUser');
        }
        doc.tick(0);

        expect(doc.getPropertyValue(uSettings, 'id'), equals('u1'));
        expect(doc.getPropertyValue(uSettings, 'gender'), equals('male'));
      },
    );
  });
}
