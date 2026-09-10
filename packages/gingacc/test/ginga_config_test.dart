import 'package:gingacc/ginga_config.dart';
import 'package:gingacc/users.dart';
import 'package:test/test.dart';

void main() {
  group('GingaConfig Tests', () {
    test('Constructor should accept named parameters', () {
      expect(GingaConfig(appSrc: 'app.ncl').appSrc, 'app.ncl');
      expect(GingaConfig(appSrc: 'app.html').appSrc, 'app.html');
      expect(GingaConfig(appSrc: 'APP.NCL').appSrc, 'APP.NCL');
      expect(GingaConfig(appSrc: 'APP.HTML').appSrc, 'APP.HTML');
    });

    test('constructor initializes envVariables and defaults', () {
      final config = GingaConfig();
      expect(config.appSrc, isNull);
      expect(config.enableCCWS, isFalse);
      expect(config.enableMainAv, isFalse);
      expect(config.envVariables['system.language'], equals('por'));
      expect(config.users, isNotNull);
    });

    test('accepts users in constructor', () {
      final users = Users('{"id": "u1", "name": "Alice"}');
      final config = GingaConfig(users: users);
      expect(config.users.getUser('u1')?.name, equals('Alice'));
    });

    test('fromJson parses usersDataJson from JSON and populates users', () async {
      final config = await GingaConfig.fromJson(
        '{"usersDataJson": "[{\\"id\\": \\"u3\\", \\"name\\": \\"Charlie\\"}]"}',
      );
      expect(config.users.getUser('u3')?.name, equals('Charlie'));
    });

    test('loads single user from inline user JSON map with ID', () {
      final config = GingaConfig(
        users: Users(
          '{"id": "u100", "name": "Alice", "properties": {"age": 30}}',
        ),
      );
      expect(config.users.getUser('u100'), isNotNull);
      expect(config.users.getUserProperty('u100', 'age'), equals(30));
    });

    test('loads user properties from inline user JSON map without ID', () {
      final config = GingaConfig(
        users: Users('{"age": 45, "preferredLang": "en-US"}'),
      );
      final active = config.users.activeUser;
      expect(active, isNotNull);
      expect(active?.getProperty('age'), equals(45));
      expect(active?.getProperty('preferredLang'), equals('en-US'));
    });

    test('loads list of users from inline user JSON list', () {
      final config = GingaConfig(
        users: Users(
          '[{"id": "u201", "name": "Alice"}, {"id": "u202", "name": "Bob"}]',
        ),
      );
      expect(config.users.getUser('u201'), isNotNull);
      expect(config.users.getUser('u202'), isNotNull);
      expect(config.users.allUsers.length, equals(2));
    });

    test('loads all required viewer profile attributes', () {
      final config = GingaConfig(
        users: Users('''
{
  "id": "uViewer1",
  "name": "Alice",
  "properties": {
    "nickname": "AliceNick",
    "parentalControl": true,
    "maxContentRating": "14",
    "avatar": "avatar.png",
    "audioLanguage": "pt",
    "closedCaptioningLanguage": "pt",
    "userInterfaceLanguage": "pt",
    "closedCaptioning": true,
    "closedSigning": false,
    "closedSigningSide": "left",
    "closedSigningWidth": 20,
    "audioDescription": false,
    "dialogEnhancement": false,
    "voiceGuidance": false
  }
}
'''),
      );

      final user = config.users.getUser('uViewer1');
      expect(user, isNotNull);
      expect(user!.id, equals('uViewer1'));
      expect(user.name, equals('Alice'));
      expect(user.getProperty('nickname'), equals('AliceNick'));
      expect(user.getProperty('parentalControl'), isTrue);
      expect(user.getProperty('maxContentRating'), equals('14'));
      expect(user.getProperty('avatar'), equals('avatar.png'));
      expect(user.getProperty('audioLanguage'), equals('pt'));
      expect(user.getProperty('closedCaptioningLanguage'), equals('pt'));
      expect(user.getProperty('userInterfaceLanguage'), equals('pt'));
      expect(user.getProperty('closedCaptioning'), isTrue);
      expect(user.getProperty('closedSigning'), isFalse);
      expect(user.getProperty('closedSigningSide'), equals('left'));
      expect(user.getProperty('closedSigningWidth'), equals(20));
      expect(user.getProperty('audioDescription'), isFalse);
      expect(user.getProperty('dialogEnhancement'), isFalse);
      expect(user.getProperty('voiceGuidance'), isFalse);
    });

    test('appSrc can be mutated directly', () async {
      final config = await GingaConfig.fromJson('{"appSrc": "old.ncl"}');
      config.appSrc = 'new.ncl';
      expect(config.appSrc, equals('new.ncl'));
    });

    test(
        'envVariables supports all groups: system, user, default, service, si, channel, shared',
        () async {
      const json = '''
      {
        "envVariables": {
          "system.language": "por",
          "user.age": "30",
          "default.focus": "true",
          "service.id": "svc_01",
          "si.network": "net_01",
          "channel.number": "7",
          "shared.token": "abc123"
        }
      }
      ''';
      final config = await GingaConfig.fromJson(json);
      expect(config.envVariables['system.language'], equals('por'));
      expect(config.envVariables['user.age'], equals('30'));
      expect(config.envVariables['default.focus'], equals('true'));
      expect(config.envVariables['service.id'], equals('svc_01'));
      expect(config.envVariables['si.network'], equals('net_01'));
      expect(config.envVariables['channel.number'], equals('7'));
      expect(config.envVariables['shared.token'], equals('abc123'));

      expect(config.getGroup('system')['language'], equals('por'));
      expect(config.getGroup('user')['age'], equals('30'));
      expect(config.getGroup('default')['focus'], equals('true'));
      expect(config.getGroup('service')['id'], equals('svc_01'));
      expect(config.getGroup('si')['network'], equals('net_01'));
      expect(config.getGroup('channel')['number'], equals('7'));
      expect(config.getGroup('shared')['token'], equals('abc123'));
    });

    test('fromJson parses nested groups under envVariables and top-level groups',
        () async {
      const json = '''
      {
        "system": { "language": "eng" },
        "user": { "name": "Alice" },
        "service": { "name": "TV HD" }
      }
      ''';
      final config = await GingaConfig.fromJson(json);
      expect(config.envVariables['system.language'], equals('eng'));
      expect(config.envVariables['user.name'], equals('Alice'));
      expect(config.envVariables['service.name'], equals('TV HD'));
    });

    test('fromJson parses envVariables directly', () async {
      const json =
          '{"envVariables": {"system.language": "eng", "custom": "val"}}';
      final config = await GingaConfig.fromJson(json);
      expect(config.envVariables['system.language'], equals('eng'));
      expect(config.envVariables['custom'], equals('val'));
    });

    test('fromJson loads content from jsonSrc URI', () async {
      const dataUri =
          'data:application/json,{"envVariables":{"system.language":"deu"}}';
      final config = await GingaConfig.fromJson(dataUri);
      expect(config.envVariables['system.language'], equals('deu'));
    });

    test('fromJson handles empty string gracefully', () async {
      final config = await GingaConfig.fromJson('');
      expect(config.envVariables['system.language'], equals('por'));
    });

    test('fromJson throws FormatException on invalid json', () async {
      expect(
        () => GingaConfig.fromJson('{bad json}'),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'fromJson parses full config with appSrc, mainAvSrc, ccws, and usersDataJson',
        () async {
      const json = '''
      {
        "appSrc": "main.ncl",
        "mainAvSrc": "video.mp4",
        "usersDataJson": [
          {"id": "u1", "name": "Bob"}
        ],
        "enableCCWS": false,
        "envVariables": {
          "system.language": "eng",
          "user.age": "30",
          "default.font": "sans",
          "service.id": "1",
          "si.ts": "2",
          "channel.num": "10",
          "shared.key": "val"
        }
      }
      ''';
      final config = await GingaConfig.fromJson(json);
      expect(config.appSrc, equals('main.ncl'));
      expect(config.mainAvSrc, equals('video.mp4'));
      expect(config.users.getUser('u1')?.name, equals('Bob'));
      expect(config.enableCCWS, isFalse);
      expect(config.envVariables['system.language'], equals('eng'));
    });

    test('toString includes users when not empty and omits when empty', () {
      final configWithUsers = GingaConfig(
        appSrc: 'main.ncl',
        users: Users('[{"id": "u1", "name": "Bob"}]'),
      );
      final strWithUsers = configWithUsers.toString();
      expect(strWithUsers, contains('users: Users'));
      expect(strWithUsers, contains('UserData(id: u1, name: Bob'));
      expect(strWithUsers, isNot(contains('mainAvSrc:')));

      final configCustom = GingaConfig(
        appSrc: 'main.ncl',
        mainAvSrc: 'custom.mp4',
      );
      final strCustom = configCustom.toString();
      expect(strCustom, contains('mainAvSrc: custom.mp4'));

      final configEmpty = GingaConfig(
        appSrc: 'main.ncl',
        mainAvSrc: '',
      );
      expect(configEmpty.users.isEmpty, isTrue);
      expect(configEmpty.mainAvSrc, isEmpty);
    });
  });
}
