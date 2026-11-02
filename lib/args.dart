import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';

import 'web_utils_stub.dart' if (dart.library.js_interop) 'web_utils_web.dart';

final _logger = Logger('ginga.args');

({String? app, String? config, List<int>? breakpoints, bool? playground})
    parseArgsCliAndEnv(
  List<String> args, [
  Map<String, String>? environment,
]) {
  String? appArg;
  String? configArg;
  String? breakpointsArg;
  bool? playgroundArg;

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
    } else if (arg == '--breakpoints' || arg == '-b') {
      if (i + 1 < args.length) {
        breakpointsArg = args[++i];
      }
    } else if (arg.startsWith('--breakpoints=')) {
      breakpointsArg = arg.substring('--breakpoints='.length);
    } else if (arg.startsWith('-b=')) {
      breakpointsArg = arg.substring('-b='.length);
    } else if (arg == '--playground' || arg == '-p') {
      playgroundArg = true;
    } else if (arg == '--no-playground') {
      playgroundArg = false;
    } else if (arg.startsWith('--playground=')) {
      final val = arg.substring('--playground='.length).toLowerCase();
      playgroundArg = val != 'false' && val != '0' && val != 'no';
    } else if (arg.startsWith('-p=')) {
      final val = arg.substring('-p='.length).toLowerCase();
      playgroundArg = val != 'false' && val != '0' && val != 'no';
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
  bool? playgroundEnv;

  if (environment != null) {
    appEnv = environment['GINGA_APP'] ?? environment['ginga_app'];
    configEnv = environment['GINGA_CONFIG'] ?? environment['ginga_config'];
    final rawPg = environment['GINGA_PLAYGROUND'] ?? environment['ginga_playground'];
    if (rawPg != null) {
      final lower = rawPg.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') {
        playgroundEnv = true;
      } else if (lower == 'false' || lower == '0' || lower == 'no') {
        playgroundEnv = false;
      }
    }
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

    if (const String.fromEnvironment('GINGA_PLAYGROUND').isNotEmpty) {
      final envVal =
          const String.fromEnvironment('GINGA_PLAYGROUND').toLowerCase();
      playgroundEnv = envVal != 'false' && envVal != '0' && envVal != 'no';
    }
    if (playgroundEnv == null && !kIsWeb) {
      final envVal = (Platform.environment['GINGA_PLAYGROUND'] ??
              Platform.environment['ginga_playground'])
          ?.toLowerCase();
      if (envVal != null) {
        if (envVal == 'true' || envVal == '1' || envVal == 'yes') {
          playgroundEnv = true;
        } else if (envVal == 'false' || envVal == '0' || envVal == 'no') {
          playgroundEnv = false;
        }
      }
    }
    if (playgroundEnv == null && kIsWeb) {
      playgroundEnv = getGingaPlayground();
      if (playgroundEnv == null) {
        try {
          final uri = Uri.base;
          if (uri.path.contains('/playground')) {
            playgroundEnv = true;
          } else if (uri.queryParameters.containsKey('playground') ||
              uri.queryParameters.containsKey('ginga_playground')) {
            final val = (uri.queryParameters['playground'] ??
                    uri.queryParameters['ginga_playground'] ??
                    '')
                .toLowerCase();
            if (val == 'false' || val == '0' || val == 'no') {
              playgroundEnv = false;
            } else {
              playgroundEnv = true;
            }
          } else if (uri.path.contains('/gingaf')) {
            playgroundEnv = false;
          }
        } catch (e) {
          _logger.warning('Failed to read playground flag on web: $e');
        }
      }
    }
  }

  String? breakpointsEnv;
  if (environment != null) {
    breakpointsEnv =
        environment['GINGA_BREAKPOINTS'] ?? environment['ginga_breakpoints'];
  } else {
    if (const String.fromEnvironment('GINGA_BREAKPOINTS').isNotEmpty) {
      breakpointsEnv = const String.fromEnvironment('GINGA_BREAKPOINTS');
    }
    if ((breakpointsEnv == null || breakpointsEnv.isEmpty) && !kIsWeb) {
      breakpointsEnv = Platform.environment['GINGA_BREAKPOINTS'] ??
          Platform.environment['ginga_breakpoints'];
    }
    if ((breakpointsEnv == null || breakpointsEnv.isEmpty) && kIsWeb) {
      try {
        breakpointsEnv = Uri.base.queryParameters['GINGA_BREAKPOINTS'] ??
            Uri.base.queryParameters['ginga_breakpoints'];
      } catch (e) {
        _logger.warning('Failed to read breakpoints on web: $e');
      }
    }
  }

  final effectiveBpsArg =
      (breakpointsArg != null && breakpointsArg.trim().isNotEmpty)
          ? breakpointsArg.trim()
          : ((breakpointsEnv != null && breakpointsEnv.trim().isNotEmpty)
              ? breakpointsEnv.trim()
              : null);

  List<int>? breakpoints;
  if (effectiveBpsArg != null && effectiveBpsArg.isNotEmpty) {
    breakpoints = [];
    for (final part in effectiveBpsArg.split(',')) {
      final parsed = int.tryParse(part.trim());
      if (parsed != null) breakpoints.add(parsed);
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
  final playground = playgroundArg ?? playgroundEnv;

  return (
    app: appSrc,
    config: configSrc,
    breakpoints: breakpoints,
    playground: playground,
  );
}
