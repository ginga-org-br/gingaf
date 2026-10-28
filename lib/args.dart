import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';

import 'web_utils_stub.dart' if (dart.library.js_interop) 'web_utils_web.dart';

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
    appEnv = environment['GINGA_APP'] ?? environment['ginga_app'];
    configEnv = environment['GINGA_CONFIG'] ?? environment['ginga_config'];
  } else {
    if (const String.fromEnvironment('GINGA_APP').isNotEmpty) {
      appEnv = const String.fromEnvironment('GINGA_APP');
    }
    if ((appEnv == null || appEnv.isEmpty) && !kIsWeb) {
      appEnv = Platform.environment['GINGA_APP'] ??
          Platform.environment['ginga_app'];
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

    if (const String.fromEnvironment('GINGA_CONFIG').isNotEmpty) {
      configEnv = const String.fromEnvironment('GINGA_CONFIG');
    }
    if ((configEnv == null || configEnv.isEmpty) && !kIsWeb) {
      configEnv = Platform.environment['GINGA_CONFIG'] ??
          Platform.environment['ginga_config'];
    }
    if ((configEnv == null || configEnv.isEmpty) && kIsWeb) {
      try {
        configEnv = Uri.base.queryParameters['GINGA_CONFIG'] ??
            Uri.base.queryParameters['ginga_config'];
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
