import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gingacc/ginga_config.dart';
import 'package:logging/logging.dart';

import 'arg_parsers.dart';
import 'web_utils_stub.dart' if (dart.library.js_interop) 'web_utils_web.dart';

export 'arg_parsers.dart';

final _logger = Logger('ginga.args');

class GingaArgs {
  final String? app;
  final String? config;
  final List<int>? breakpoints;
  final bool? playground;
  final List<String>? remoteDevices;

  const GingaArgs({
    this.app,
    this.config,
    this.breakpoints,
    this.playground,
    this.remoteDevices,
  });

  bool get isStandaloneRemoteDevice =>
      playground != true &&
      app == null &&
      config == null &&
      remoteDevices != null &&
      remoteDevices!.length == 1;

  bool get hasNoLaunchTarget =>
      playground != true && app == null && config == null;

  GingaConfig applyToConfig(GingaConfig base) {
    final mergedBreakpoints = List<int>.from(base.breakpoints);
    if (breakpoints != null) {
      for (final bp in breakpoints!) {
        if (!mergedBreakpoints.contains(bp)) {
          mergedBreakpoints.add(bp);
        }
      }
    }
    return base.copyWith(
      enablePlayground: playground ?? base.enablePlayground,
      breakpoints: mergedBreakpoints,
    );
  }

  List<String> toCliArgs() {
    final out = <String>[];
    if (app != null && app!.isNotEmpty) {
      out.add('--app=$app');
    }
    if (config != null && config!.isNotEmpty) {
      out.add('--config=$config');
    }
    if (playground == true) {
      out.add('--playground');
    } else if (playground == false) {
      out.add('--no-playground');
    }
    if (breakpoints != null && breakpoints!.isNotEmpty) {
      out.add('--breakpoints=${breakpoints!.join(',')}');
    }
    if (remoteDevices != null && remoteDevices!.isNotEmpty) {
      out.add('--remote-devices=${remoteDevices!.join(',')}');
    }
    return out;
  }

  factory GingaArgs.parse(
    List<String> args, {
    Map<String, String>? environment,
    Uri? webUri,
  }) {
    final cli = _parseCli(args);
    final env = _resolveEnvAndWeb(environment: environment, webUri: webUri);

    final appSrc = _firstNonEmpty(cli.app, env.app);
    final configSrc = _firstNonEmpty(cli.config, env.config);
    final bpRaw = _firstNonEmpty(cli.breakpoints, env.breakpoints);
    final remoteRaw = _firstNonEmpty(cli.remoteDevices, env.remoteDevices);

    return GingaArgs(
      app: appSrc,
      config: configSrc,
      breakpoints: parseBreakpoints(bpRaw),
      playground: cli.playground ?? env.playground,
      remoteDevices: parseRemoteDevices(remoteRaw),
    );
  }
}

GingaArgs parseArgsCliAndEnv(
  List<String> args, [
  Map<String, String>? environment,
]) =>
    GingaArgs.parse(args, environment: environment);

String? _firstNonEmpty(String? first, String? second) {
  final a = first?.trim();
  if (a != null && a.isNotEmpty) return a;
  final b = second?.trim();
  if (b != null && b.isNotEmpty) return b;
  return null;
}

String? _lookupMap(Map<String, String> map, List<String> keys) {
  for (final key in keys) {
    final direct = map[key];
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    final lowerKey = key.toLowerCase();
    for (final entry in map.entries) {
      if (entry.key.toLowerCase() == lowerKey &&
          entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }
  }
  return null;
}

({
  String? app,
  String? config,
  String? breakpoints,
  bool? playground,
  String? remoteDevices,
}) _parseCli(List<String> args) {
  String? appArg;
  String? configArg;
  String? breakpointsArg;
  bool? playgroundArg;
  String? remoteDevicesArg;

  String? matchOption(String arg, List<String> names, int index) {
    for (final name in names) {
      final prefix = '$name=';
      if (arg.startsWith(prefix)) {
        return arg.substring(prefix.length);
      }
    }
    return null;
  }

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];

    if (arg == '--config' || arg == '-c') {
      if (i + 1 < args.length) configArg = args[++i];
      continue;
    }
    final inlineConfig = matchOption(arg, const ['--config', '-c'], i);
    if (inlineConfig != null) {
      configArg = inlineConfig;
      continue;
    }

    if (arg == '--app' || arg == '-a') {
      if (i + 1 < args.length) appArg = args[++i];
      continue;
    }
    final inlineApp = matchOption(arg, const ['--app', '-a'], i);
    if (inlineApp != null) {
      appArg = inlineApp;
      continue;
    }

    if (arg == '--breakpoints' || arg == '-b') {
      if (i + 1 < args.length) breakpointsArg = args[++i];
      continue;
    }
    final inlineBp = matchOption(arg, const ['--breakpoints', '-b'], i);
    if (inlineBp != null) {
      breakpointsArg = inlineBp;
      continue;
    }

    if (arg == '--playground' || arg == '-p') {
      playgroundArg = true;
      continue;
    }
    if (arg == '--no-playground') {
      playgroundArg = false;
      continue;
    }
    final inlinePg = matchOption(arg, const ['--playground', '-p'], i);
    if (inlinePg != null) {
      playgroundArg = parseBoolFlag(inlinePg) ?? true;
      continue;
    }

    if (arg == '--remote-device' || arg == '--remote-devices') {
      if (i + 1 < args.length) remoteDevicesArg = args[++i];
      continue;
    }
    final inlineRemote =
        matchOption(arg, const ['--remote-device', '--remote-devices'], i);
    if (inlineRemote != null) {
      remoteDevicesArg = inlineRemote;
      continue;
    }

    if (!arg.startsWith('-')) {
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

  return (
    app: appArg,
    config: configArg,
    breakpoints: breakpointsArg,
    playground: playgroundArg,
    remoteDevices: remoteDevicesArg,
  );
}

({
  String? app,
  String? config,
  String? breakpoints,
  bool? playground,
  String? remoteDevices,
}) _resolveEnvAndWeb({
  Map<String, String>? environment,
  Uri? webUri,
}) {
  if (environment != null) {
    final fromEnv = (
      app: _lookupMap(environment, const ['GINGA_APP']),
      config: _lookupMap(environment, const ['GINGA_CONFIG']),
      breakpoints: _lookupMap(environment, const ['GINGA_BREAKPOINTS']),
      playground:
          parseBoolFlag(_lookupMap(environment, const ['GINGA_PLAYGROUND'])),
      remoteDevices: _lookupMap(environment, const [
        'GINGA_REMOTE_DEVICES',
        'GINGA_REMOTE_DEVICE',
        'remote-devices',
        'remote_devices',
      ]),
    );
    if (webUri == null) return fromEnv;
    final fromUri = _parseFromUri(webUri);
    return (
      app: _firstNonEmpty(fromEnv.app, fromUri.app),
      config: _firstNonEmpty(fromEnv.config, fromUri.config),
      breakpoints: _firstNonEmpty(fromEnv.breakpoints, fromUri.breakpoints),
      playground: fromEnv.playground ?? fromUri.playground,
      remoteDevices:
          _firstNonEmpty(fromEnv.remoteDevices, fromUri.remoteDevices),
    );
  }

  const defineApp = String.fromEnvironment('GINGA_APP');
  const defineConfig = String.fromEnvironment('GINGA_CONFIG');
  const definePlayground = String.fromEnvironment('GINGA_PLAYGROUND');
  const defineBreakpoints = String.fromEnvironment('GINGA_BREAKPOINTS');
  const defineRemoteDevices = String.fromEnvironment('GINGA_REMOTE_DEVICES');
  const defineRemoteDevice = String.fromEnvironment('GINGA_REMOTE_DEVICE');

  String? appEnv = defineApp.isNotEmpty ? defineApp : null;
  String? configEnv = defineConfig.isNotEmpty ? defineConfig : null;
  bool? playgroundEnv = definePlayground.isNotEmpty
      ? (parseBoolFlag(definePlayground) ?? true)
      : null;
  String? breakpointsEnv =
      defineBreakpoints.isNotEmpty ? defineBreakpoints : null;
  String? remoteDevicesEnv = defineRemoteDevices.isNotEmpty
      ? defineRemoteDevices
      : (defineRemoteDevice.isNotEmpty ? defineRemoteDevice : null);

  if (!kIsWeb) {
    final osEnv = Platform.environment;
    appEnv ??= _lookupMap(osEnv, const ['GINGA_APP']);
    configEnv ??= _lookupMap(osEnv, const ['GINGA_CONFIG']);
    playgroundEnv ??=
        parseBoolFlag(_lookupMap(osEnv, const ['GINGA_PLAYGROUND']));
    breakpointsEnv ??= _lookupMap(osEnv, const ['GINGA_BREAKPOINTS']);
    remoteDevicesEnv ??= _lookupMap(osEnv, const [
      'GINGA_REMOTE_DEVICES',
      'GINGA_REMOTE_DEVICE',
    ]);
  }

  if (kIsWeb || webUri != null) {
    final effectiveUri = webUri ?? (kIsWeb ? _safeBaseUri() : null);
    final fromUri = effectiveUri != null ? _parseFromUri(effectiveUri) : null;

    if (kIsWeb) {
      if (appEnv == null || appEnv.isEmpty) {
        try {
          appEnv = _firstNonEmpty(getGingaApp(), fromUri?.app);
        } catch (e) {
          _logger.warning('Failed to read app path on web: $e');
        }
      }
      if (playgroundEnv == null) {
        try {
          playgroundEnv = getGingaPlayground() ?? fromUri?.playground;
        } catch (e) {
          _logger.warning('Failed to read playground flag on web: $e');
        }
      }
      if (remoteDevicesEnv == null || remoteDevicesEnv.isEmpty) {
        try {
          final webDevices = getGingaRemoteDevices();
          if (webDevices != null && webDevices.isNotEmpty) {
            remoteDevicesEnv = webDevices.join(',');
          } else {
            remoteDevicesEnv = fromUri?.remoteDevices;
          }
        } catch (e) {
          _logger.warning('Failed to read remote-devices on web: $e');
        }
      }
    } else if (fromUri != null) {
      appEnv ??= fromUri.app;
      playgroundEnv ??= fromUri.playground;
      remoteDevicesEnv ??= fromUri.remoteDevices;
    }

    if (fromUri != null) {
      configEnv ??= fromUri.config;
      breakpointsEnv ??= fromUri.breakpoints;
    }
  }

  return (
    app: appEnv,
    config: configEnv,
    breakpoints: breakpointsEnv,
    playground: playgroundEnv,
    remoteDevices: remoteDevicesEnv,
  );
}

Uri? _safeBaseUri() {
  try {
    return Uri.base;
  } catch (_) {
    return null;
  }
}

({
  String? app,
  String? config,
  String? breakpoints,
  bool? playground,
  String? remoteDevices,
}) _parseFromUri(Uri uri) {
  final params = uri.queryParameters;
  final app = lookupQueryParam(params, const [
    'ginga_app',
    'app',
    'src',
    'appSrc',
  ]);
  final config = lookupQueryParam(params, const [
    'GINGA_CONFIG',
    'ginga_config',
    'config',
  ]);
  final breakpoints = lookupQueryParam(params, const [
    'GINGA_BREAKPOINTS',
    'ginga_breakpoints',
    'breakpoints',
  ]);
  final remoteDevices = lookupQueryParam(params, remoteDeviceParamKeys);

  bool? playground;
  if (uri.path.contains('/playground')) {
    playground = true;
  } else if (params.containsKey('playground') ||
      params.containsKey('ginga_playground')) {
    final val = params['playground'] ?? params['ginga_playground'];
    playground = parseBoolFlag(val) ?? true;
  } else if (uri.path.contains('/gingaf') || uri.path.contains('/player')) {
    playground = false;
  }

  return (
    app: app,
    config: config,
    breakpoints: breakpoints,
    playground: playground,
    remoteDevices: remoteDevices,
  );
}
