import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gingacc/gingacc.dart';
import 'package:logging/logging.dart';

import 'web_utils_stub.dart'
    if (dart.library.js_interop) 'web_utils_web.dart';

final _logger = Logger('ginga.args');

/// Resolves configuration arguments by first checking CLI, then ENV, then getGingaApp.
({String? app, String? config}) parseArgsCliAndEnv(
  List<String> args, [
  Map<String, String>? environment,
]) {
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

  String? appEnv;
  String? configEnv;

  if (environment != null) {
    appEnv = environment['GINGA_APP'] ??
        environment['ginga_app'] ??
        environment['APP'] ??
        environment['app'];
    configEnv = environment['CONFIG'] ?? environment['config'];
  } else {
    if (const String.fromEnvironment('GINGA_APP').isNotEmpty) {
      appEnv = const String.fromEnvironment('GINGA_APP');
    } else if (const String.fromEnvironment('APP').isNotEmpty) {
      appEnv = const String.fromEnvironment('APP');
    }
    if ((appEnv == null || appEnv.isEmpty) && !kIsWeb) {
      appEnv =
          Platform.environment['GINGA_APP'] ?? Platform.environment['APP'];
    }
    if ((appEnv == null || appEnv.isEmpty) && kIsWeb) {
      try {
        final webApp = getGingaApp();
        if (webApp != null && webApp.isNotEmpty) {
          appEnv = webApp;
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
  }

  final appSrc = (appArg != null && appArg.trim().isNotEmpty)
      ? appArg.trim()
      : ((appEnv != null && appEnv.trim().isNotEmpty) ? appEnv.trim() : null);
  final configSrc = (configArg != null && configArg.trim().isNotEmpty)
      ? configArg.trim()
      : ((configEnv != null && configEnv.trim().isNotEmpty)
          ? configEnv.trim()
          : null);

  return (app: appSrc, config: configSrc);
}

Future<GingaConfig> resolveGingaConfig({
  String? appSrc,
  String? configSrc,
  GingaCC? gingacc,
}) async {
  final target = gingacc ?? GingaCC();
  return await target.loadConfig(configSrc, appSrc);
}
