import 'package:gingacc/ginga_config.dart';
import 'package:test/test.dart';

void main() {
  group('GingaConfig Tests', () {
    test('Constructor should accept named parameters', () {
      expect(GingaConfig(appSrc: 'app.ncl').appSrc, 'app.ncl');
      expect(GingaConfig(appSrc: 'app.html').appSrc, 'app.html');
      expect(GingaConfig(appSrc: 'APP.NCL').appSrc, 'APP.NCL');
      expect(GingaConfig(appSrc: 'APP.HTML').appSrc, 'APP.HTML');
    });

    test('default constructor initializes envVariables and defaults', () {
      final config = GingaConfig();
      expect(config.appSrc, isNull);
      expect(config.usersDataSrc, isNull);
      expect(config.enableCCWS, isTrue);
      expect(config.envVariables['system.language'], equals('por'));
    });

    test('accepts usersDataSrc', () {
      final config = GingaConfig(usersDataSrc: 'data1.json');
      expect(config.usersDataSrc, equals('data1.json'));
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

    test('fromJson parses backward-compatible systemProperties directly',
        () async {
      const json =
          '{"userDataSrc": "users.json", "systemProperties": {"system.language": "eng", "custom": "val"}}';
      final config = await GingaConfig.fromJson(json);
      expect(config.usersDataSrc, equals('users.json'));
      expect(config.envVariables['system.language'], equals('eng'));
      expect(config.envVariables['custom'], equals('val'));
    });

    test('fromJson loads content from jsonSrc URI', () async {
      const dataUri =
          'data:application/json,{"userDataSrc":"users2.json","envVariables":{"system.language":"deu"}}';
      final config = await GingaConfig.fromJson(dataUri);
      expect(config.usersDataSrc, equals('users2.json'));
      expect(config.envVariables['system.language'], equals('deu'));
    });

    test('fromJson handles empty string gracefully', () async {
      final config = await GingaConfig.fromJson('');
      expect(config.usersDataSrc, isNull);
      expect(config.envVariables['system.language'], equals('por'));
    });

    test('fromJson throws FormatException on invalid json', () async {
      expect(
        () => GingaConfig.fromJson('{bad json}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromJson parses full config with appSrc, mainAvSrc, and ccws',
        () async {
      const json = '''
      {
        "appSrc": "main.ncl",
        "mainAvSrc": "video.mp4",
        "usersDataSrc": "users.json",
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
      expect(config.usersDataSrc, equals('users.json'));
      expect(config.enableCCWS, isFalse);
      expect(config.envVariables['system.language'], equals('eng'));
    });

    test('NclDocConfig typedef works identically', () async {
      final NclDocConfig config = await NclDocConfig.fromJson(
        '{"userDataSrc": "users.json", "systemProperties": {"system.language": "fra"}}',
      );
      expect(config.usersDataSrc, equals('users.json'));
      expect(config.envVariables['system.language'], equals('fra'));
    });
  });
}
