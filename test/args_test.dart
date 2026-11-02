import 'package:flutter_test/flutter_test.dart';
import 'package:gingacc/ginga_config.dart';
import 'package:gingaf/main.dart';

void main() {
  group('parseArgsCliAndEnv', () {
    test('returns null fields when arguments and environment are empty', () {
      final result = parseArgsCliAndEnv([], {});
      expect(result.app, isNull);
      expect(result.config, isNull);
    });

    test('parses --app and -a flags with separate argument', () {
      final result1 = parseArgsCliAndEnv(['--app', 'main.ncl'], {});
      expect(result1.app, equals('main.ncl'));
      expect(result1.config, isNull);

      final result2 = parseArgsCliAndEnv(['-a', 'app.ncl'], {});
      expect(result2.app, equals('app.ncl'));
      expect(result2.config, isNull);
    });

    test('parses --app= and -a= flags with inline value', () {
      final result1 = parseArgsCliAndEnv(['--app=main.ncl'], {});
      expect(result1.app, equals('main.ncl'));
      expect(result1.config, isNull);

      final result2 = parseArgsCliAndEnv(['-a=app.ncl'], {});
      expect(result2.app, equals('app.ncl'));
      expect(result2.config, isNull);
    });

    test('parses --config and -c flags with separate argument', () {
      final result1 = parseArgsCliAndEnv(['--config', 'config.json'], {});
      expect(result1.app, isNull);
      expect(result1.config, equals('config.json'));

      final result2 = parseArgsCliAndEnv(['-c', 'custom.json'], {});
      expect(result2.app, isNull);
      expect(result2.config, equals('custom.json'));
    });

    test('parses --config= and -c= flags with inline value', () {
      final result1 = parseArgsCliAndEnv(['--config=config.json'], {});
      expect(result1.app, isNull);
      expect(result1.config, equals('config.json'));

      final result2 = parseArgsCliAndEnv(['-c=custom.json'], {});
      expect(result2.app, isNull);
      expect(result2.config, equals('custom.json'));
    });

    test('parses both app and config options combined', () {
      final result1 = parseArgsCliAndEnv(
          ['--app', 'main.ncl', '--config', 'config.json'], {});
      expect(result1.app, equals('main.ncl'));
      expect(result1.config, equals('config.json'));

      final result2 =
          parseArgsCliAndEnv(['-c', 'app.json', '-a', 'demo.ncl'], {});
      expect(result2.app, equals('demo.ncl'));
      expect(result2.config, equals('app.json'));
    });

    test('parses positional arguments for app and config', () {
      final result1 = parseArgsCliAndEnv(['main.ncl'], {});
      expect(result1.app, equals('main.ncl'));
      expect(result1.config, isNull);

      final result2 = parseArgsCliAndEnv(['main.ncl', 'config.json'], {});
      expect(result2.app, equals('main.ncl'));
      expect(result2.config, equals('config.json'));
    });

    test(
        'reassigns app to config when single positional argument ends with .json',
        () {
      final result = parseArgsCliAndEnv(['config.json'], {});
      expect(result.app, isNull);
      expect(result.config, equals('config.json'));

      final resultUpper = parseArgsCliAndEnv(['CONFIG.JSON'], {});
      expect(resultUpper.app, isNull);
      expect(resultUpper.config, equals('CONFIG.JSON'));
    });

    test('resolves app and config from environment variables', () {
      final result = parseArgsCliAndEnv(
          [], {'GINGA_APP': 'env_app.ncl', 'GINGA_CONFIG': 'env_config.json'});
      expect(result.app, equals('env_app.ncl'));
      expect(result.config, equals('env_config.json'));

      final resultLower = parseArgsCliAndEnv([],
          {'ginga_app': 'lower_app.ncl', 'ginga_config': 'lower_config.json'});
      expect(resultLower.app, equals('lower_app.ncl'));
      expect(resultLower.config, equals('lower_config.json'));
    });

    test('CLI arguments take precedence over environment variables', () {
      final result = parseArgsCliAndEnv(
        ['--app', 'cli.ncl', '--config', 'cli.json'],
        {'GINGA_APP': 'env.ncl', 'GINGA_CONFIG': 'env.json'},
      );
      expect(result.app, equals('cli.ncl'));
      expect(result.config, equals('cli.json'));
    });

    test('falls back to environment variable when CLI argument is missing', () {
      final resultAppFromCli = parseArgsCliAndEnv(
        ['--app', 'cli.ncl'],
        {'GINGA_APP': 'env.ncl', 'GINGA_CONFIG': 'env.json'},
      );
      expect(resultAppFromCli.app, equals('cli.ncl'));
      expect(resultAppFromCli.config, equals('env.json'));

      final resultConfigFromCli = parseArgsCliAndEnv(
        ['--config', 'cli.json'],
        {'GINGA_APP': 'env.ncl', 'GINGA_CONFIG': 'env.json'},
      );
      expect(resultConfigFromCli.app, equals('env.ncl'));
      expect(resultConfigFromCli.config, equals('cli.json'));
    });

    test('parses --playground and -p flags', () {
      final res1 = parseArgsCliAndEnv(['--playground'], {});
      expect(res1.playground, isTrue);

      final res2 = parseArgsCliAndEnv(['-p'], {});
      expect(res2.playground, isTrue);

      final res3 = parseArgsCliAndEnv(['--playground=true'], {});
      expect(res3.playground, isTrue);

      final res4 = parseArgsCliAndEnv(['-p=true'], {});
      expect(res4.playground, isTrue);
    });

    test('parses --no-playground and false flag values', () {
      final res1 = parseArgsCliAndEnv(['--no-playground'], {});
      expect(res1.playground, isFalse);

      final res2 = parseArgsCliAndEnv(['--playground=false'], {});
      expect(res2.playground, isFalse);

      final res3 = parseArgsCliAndEnv(['-p=false'], {});
      expect(res3.playground, isFalse);
    });

    test('resolves playground flag from environment variables', () {
      final res1 = parseArgsCliAndEnv([], {'GINGA_PLAYGROUND': 'true'});
      expect(res1.playground, isTrue);

      final res2 = parseArgsCliAndEnv([], {'ginga_playground': '1'});
      expect(res2.playground, isTrue);

      final res3 = parseArgsCliAndEnv([], {'GINGA_PLAYGROUND': 'false'});
      expect(res3.playground, isFalse);
    });

    test('CLI playground argument takes precedence over environment variable', () {
      final res1 = parseArgsCliAndEnv(
        ['--playground'],
        {'GINGA_PLAYGROUND': 'false'},
      );
      expect(res1.playground, isTrue);

      final res2 = parseArgsCliAndEnv(
        ['--no-playground'],
        {'GINGA_PLAYGROUND': 'true'},
      );
      expect(res2.playground, isFalse);
    });

    test('running gingaf alone without playground flags keeps playground disabled', () {
      final res = parseArgsCliAndEnv(['--app=examples/video.ncl'], {});
      expect(res.app, equals('examples/video.ncl'));
      expect(res.playground, isNull);

      final config = GingaConfig();
      expect(config.enablePlayground, isFalse);

      if (res.playground != null) {
        final updated = config.copyWith(enablePlayground: res.playground!);
        expect(updated.enablePlayground, isFalse);
      }
    });

    test('running with explicit --no-playground or GINGA_PLAYGROUND=false forces playground false', () {
      final res1 = parseArgsCliAndEnv(['examples/video.ncl'], {'GINGA_PLAYGROUND': 'false'});
      expect(res1.playground, isFalse);

      final config = GingaConfig(enablePlayground: true).copyWith(enablePlayground: res1.playground);
      expect(config.enablePlayground, isFalse);
    });
  });
}
