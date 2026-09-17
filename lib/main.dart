import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gingacc/gingacc.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'ginga.dart';
import 'web_utils_stub.dart' if (dart.library.js_interop) 'web_utils_web.dart';

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

  if (!kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    try {
      ProcessSignal.sigint.watch().listen((_) {
        exit(0);
      });
    } catch (_) {}
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
    } else if (arg.startsWith('--config=')) {
      configArg = arg.substring('--config='.length);
    } else if (arg.startsWith('-c=')) {
      configArg = arg.substring('-c='.length);
    } else if (arg == '--app' || arg == '-a') {
      if (i + 1 < args.length) {
        appArg = args[++i];
      }
    } else if (arg.startsWith('--app=')) {
      appArg = arg.substring('--app='.length);
    } else if (arg.startsWith('-a=')) {
      appArg = arg.substring('-a='.length);
    } else if (!arg.startsWith('-')) {
      if (appArg == null) {
        appArg = arg;
      } else {
        configArg ??= arg;
      }
    }
  }

  if (appArg != null && appArg.toLowerCase().endsWith('.json')) {
    configArg ??= appArg;
    appArg = null;
  }

  final appSrc = (appArg != null && appArg.trim().isNotEmpty)
      ? appArg.trim()
      : ((appEnv != null && appEnv.trim().isNotEmpty) ? appEnv.trim() : null);
  final configSrc = (configArg != null && configArg.trim().isNotEmpty)
      ? configArg.trim()
      : ((configEnv != null && configEnv.trim().isNotEmpty)
          ? configEnv.trim()
          : null);

  if (!kIsWeb && appSrc == null && configSrc == null) {
    _logger.severe('both APP and CONFIG are empty, exiting');
    exit(1);
  }

  Map<String, String>? virtualFiles;
  if (kIsWeb) {
    try {
      final webFiles = getGingaAppFiles();
      if (webFiles != null) {
        virtualFiles = webFiles.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (e) {
      _logger.warning('Failed to load web virtual files: $e');
    }
  }

  final config = await resolveGingaConfig(
    appSrc: appSrc,
    configSrc: configSrc,
  );

  _logger.info(config.toString());

  runApp(Ginga(
    gingacc: GingaCC(
      config: config,
      virtualFiles: virtualFiles,
    ),
  ));
}

Future<GingaConfig> resolveGingaConfig({
  String? appSrc,
  String? configSrc,
  GingaCC? gingacc,
}) async {
  String? effectiveAppSrc = appSrc;
  String? effectiveConfigSrc = configSrc;

  if (!kIsWeb) {
    final appFile =
        (appSrc != null && !isHttp(appSrc)) ? File(appSrc).absolute : null;
    final configFile = (configSrc != null && !isHttp(configSrc))
        ? File(configSrc).absolute
        : null;

    if (appFile != null && appFile.existsSync()) {
      Directory.current = appFile.parent.path;
      effectiveAppSrc = path.basename(appFile.path);
      if (configFile != null && configFile.existsSync()) {
        effectiveConfigSrc = configFile.path;
      }
    } else if (configFile != null && configFile.existsSync()) {
      Directory.current = configFile.parent.path;
      effectiveConfigSrc = path.basename(configFile.path);
    }
  }

  final initialGingacc = gingacc ?? GingaCC();

  GingaConfig config;
  if (effectiveConfigSrc != null) {
    try {
      config = await GingaConfig.fromJson(
        effectiveConfigSrc,
        effectiveAppSrc,
        initialGingacc,
      );
    } catch (e) {
      _logger.severe('Failed to load config: $e');
      if (!kIsWeb) {
        exit(1);
      }
      config = GingaConfig(startWithCCWS: true);
    }
  } else if (effectiveAppSrc != null) {
    final localConfigFile = File('ginga_config.json');
    if (localConfigFile.existsSync()) {
      try {
        config = await GingaConfig.fromJson(
          'ginga_config.json',
          effectiveAppSrc,
          initialGingacc,
        );
      } catch (e) {
        _logger.warning('Failed to load config: $e');
        config = GingaConfig(startWithCCWS: true);
      }
    } else {
      config = GingaConfig(startWithCCWS: true);
    }
  } else {
    config = GingaConfig(startWithCCWS: true);
  }

  final initialAppSrc = effectiveAppSrc ?? config.appSrc;
  String? resolvedAppSrc = initialAppSrc;
  if (!kIsWeb && initialAppSrc != null && !isHttp(initialAppSrc)) {
    try {
      final file = File(initialAppSrc).absolute;
      if (file.existsSync()) {
        Directory.current = file.parent.path;
        resolvedAppSrc = path.basename(file.path);
      }
    } catch (e) {
      _logger.severe('Failed to set working directory: $e');
    }
  }

  if (resolvedAppSrc != null) {
    config.appSrc = resolvedAppSrc;
  }

  return config;
}
