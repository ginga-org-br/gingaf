import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gingacc/ginga_config.dart';
import 'package:logging/logging.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'ginga.dart';
import 'web_utils_stub.dart' if (dart.library.html) 'web_utils_web.dart';

final _logger = Logger('ginga');

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    VideoPlayerMediaKit.ensureInitialized(
      windows: Platform.isWindows,
      linux: Platform.isLinux,
    );
  }

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint(
        '[${record.loggerName}] ${record.level.name}: ${record.message}');
  });

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    if (args.contains('-h') || args.contains('--help')) {
      stdout.writeln('Usage: gingaf [options] [APP_FILE] [CONFIG_FILE]');
      stdout.writeln('');
      stdout.writeln('Options:');
      stdout.writeln('  -h, --help           Show this help message');
      stdout.writeln('  -c, --config <path>  Path to configuration file');
      stdout.writeln('  -a, --app <path>     Path to application file');
      stdout.writeln('');
      stdout.writeln('Environment Variables alternatives (mobile, web):');
      stdout.writeln('  APP         Path to the application file');
      stdout.writeln('  CONFIG      Path to the configuration file');
      stdout.flush();
      exit(0);
    }

    try {
      if (stdin.hasTerminal) {
        stdin.echoMode = false;
        stdin.lineMode = false;
        stdin.listen((List<int> codes) {
          if (codes.contains(27)) {
            _logger.info('Captured ESC, stopping app.');
            exit(0);
          }
        }, onError: (e) {
          _logger.warning('stdin error: $e');
        });
      }
    } catch (e) {
      _logger.severe('Failed to setup stdin listener: $e');
    }
  }

  String? appEnv;
  String? configEnv;

  if (const String.fromEnvironment('APP').isNotEmpty) {
    appEnv = const String.fromEnvironment('APP');
  }
  if ((appEnv == null || appEnv.isEmpty) && !kIsWeb) {
    appEnv = Platform.environment['APP'];
  }
  if ((appEnv == null || appEnv.isEmpty) && kIsWeb) {
    try {
      final mainFile = getGingaAppPath();
      if (mainFile != null && mainFile.isNotEmpty) {
        appEnv = mainFile;
      }
    } catch (e) {
      _logger.warning('Failed to read app path on web: $e');
    }
  }

  if (const String.fromEnvironment('CONFIG').isNotEmpty) {
    configEnv = const String.fromEnvironment('CONFIG');
  }
  if ((configEnv == null || configEnv.isEmpty) && !kIsWeb) {
    configEnv = Platform.environment['CONFIG'];
  }
  if ((configEnv == null || configEnv.isEmpty) && kIsWeb) {
    try {
      configEnv = Uri.base.queryParameters['CONFIG'] ??
          Uri.base.queryParameters['config'];
    } catch (e) {
      _logger.warning('Failed to read config path on web: $e');
    }
  }

  String? appArg;
  String? configArg;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--config' || arg == '-c') {
      if (i + 1 < args.length) {
        configArg = args[++i];
      }
    } else if (arg == '--app' || arg == '-a') {
      if (i + 1 < args.length) {
        appArg = args[++i];
      }
    } else if (!arg.startsWith('-')) {
      if (appArg == null) {
        appArg = arg;
      } else {
        configArg ??= arg;
      }
    }
  }

  final appSrc = (appArg != null && appArg.trim().isNotEmpty)
      ? appArg.trim()
      : ((appEnv != null && appEnv.trim().isNotEmpty) ? appEnv.trim() : null);
  final configSrc = (configArg != null && configArg.trim().isNotEmpty)
      ? configArg.trim()
      : ((configEnv != null && configEnv.trim().isNotEmpty)
          ? configEnv.trim()
          : null);

  GingaConfig config;
  if (configSrc != null) {
    try {
      config = await GingaConfig.fromJson(configSrc);
    } catch (e) {
      _logger.severe('Failed to load config: $e');
      config = GingaConfig();
    }
  } else if (appSrc != null) {
    try {
      config = await GingaConfig.fromJson('ginga_config.json', appSrc);
    } catch (e) {
      _logger.severe('Failed to load config: $e');
      config = GingaConfig();
    }
  } else {
    config = GingaConfig();
  }

  final initialAppSrc = appSrc ?? config.appSrc;
  String? effectiveAppSrc = initialAppSrc;
  if (!kIsWeb && initialAppSrc != null) {
    _logger.info('Initial working directory: ${Directory.current.path}');
    try {
      final file = File(initialAppSrc).absolute;
      _logger.info('Resolved app path: ${file.path}');
      if (file.existsSync()) {
        Directory.current = file.parent.path;
        _logger.info('Switched working directory to ${Directory.current.path}');
        effectiveAppSrc = file.path.split('/').last.split('\\').last;
      }
    } catch (e) {
      _logger.severe('Failed to set working directory: $e');
    }
  }

  if (effectiveAppSrc != null) {
    config.appSrc = effectiveAppSrc;
  }

  _logger.info(config.toString());

  runApp(Ginga(config: config));
}
