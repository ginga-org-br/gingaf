import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'ccws.dart';
import 'ginga_app_private_base.dart';
import 'ginga_config.dart';

export 'ccws.dart';
export 'ginga_app.dart';
export 'ginga_app_private_base.dart';
export 'ginga_config.dart';
export 'gingacc_plugins.dart';
export 'users.dart';

final _logger = Logger('gingacc');

const bool _isWeb = bool.fromEnvironment('dart.library.js_interop');

bool isHttpUri(Object? source) {
  if (source is Uri) {
    return source.isScheme('http') || source.isScheme('https');
  }
  if (source is String) {
    return source.startsWith('http://') || source.startsWith('https://');
  }
  return false;
}

bool isXmlString(String? src) {
  if (src == null) return false;
  return src.trim().startsWith('<');
}

class GingaCC {
  GingaConfig config;
  late final CCWS ccws = CCWS();
  final Map<String, GingaAppPrivateBase> _privateBases = {};
  final Map<String, String> _virtualFiles = {};

  Map<String, String>? get virtualFiles =>
      _virtualFiles.isEmpty ? null : Map.unmodifiable(_virtualFiles);

  void setVirtualFiles(Map<String, String>? files) {
    _virtualFiles.clear();
    if (files != null) {
      _virtualFiles.addAll(files);
    }
  }

  Uri resolveUri(String src, [String? baseDirSrc]) => resolvePathUri(
        src,
        baseDirSrc: baseDirSrc,
        virtualFiles: _virtualFiles,
      );

  Future<String?> loadContent(dynamic srcOrUri, [String? baseDirSrc]) =>
      loadPathContent(
        srcOrUri,
        baseDirSrc: baseDirSrc,
        virtualFiles: _virtualFiles,
      );

  String? loadContentSync(dynamic srcOrUri, [String? baseDirSrc]) =>
      loadPathContentSync(
        srcOrUri,
        baseDirSrc: baseDirSrc,
        virtualFiles: _virtualFiles,
      );

  GingaAppPrivateBase getPrivateBase({
    required String applicationId,
    Uri? baseUri,
  }) {
    final existing = _privateBases[applicationId];
    if (existing != null) {
      if (baseUri != null) {
        existing.baseUri = baseUri;
      }
      return existing;
    }
    final pb = GingaAppPrivateBase(
      applicationId: applicationId,
      gingacc: this,
      baseUri: baseUri,
      virtualFiles: virtualFiles,
    );
    _privateBases[applicationId] = pb;
    return pb;
  }

  void removePrivateBase(String applicationId) {
    _privateBases.remove(applicationId);
  }

  GingaCC({
    GingaConfig? config,
  }) : config = config ?? GingaConfig();

  FutureOr<GingaConfig> loadConfig([dynamic configOrSrc, String? appSrc]) {
    if (configOrSrc is GingaConfig) {
      if (appSrc != null) {
        configOrSrc.appSrc = appSrc;
      }
      config = configOrSrc;
      return config;
    }
    if (configOrSrc == null && appSrc == null) {
      config = GingaConfig();
      return config;
    }
    return _resolveConfigFromAppFolder(configOrSrc, appSrc).then((cfg) {
      config = cfg;
      return cfg;
    });
  }

  Future<GingaConfig> _resolveConfigFromAppFolder([
    dynamic configOrSrc,
    String? appSrc,
  ]) async {
    String? effectiveAppSrc = appSrc;
    String? effectiveConfigSrc = configOrSrc is String ? configOrSrc : null;

    if (!_isWeb) {
      final appFile =
          (appSrc != null && !isHttpUri(appSrc)) ? File(appSrc).absolute : null;
      final isJsonConfig = effectiveConfigSrc != null &&
          (effectiveConfigSrc.trim().startsWith('{') ||
              effectiveConfigSrc.trim().startsWith('['));
      final configFile = (effectiveConfigSrc != null &&
              !isHttpUri(effectiveConfigSrc) &&
              !isJsonConfig)
          ? File(effectiveConfigSrc).absolute
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

    GingaConfig cfg;
    if (effectiveConfigSrc != null) {
      try {
        cfg = await GingaConfig.fromJson(
          effectiveConfigSrc,
          effectiveAppSrc,
          this,
        );
      } catch (e) {
        _logger.severe('Failed to load config: $e');
        if (!_isWeb) {
          exit(1);
        }
        cfg = GingaConfig(startWithCCWS: true);
      }
    } else if (effectiveAppSrc != null) {
      try {
        final configUri = resolveUri('ginga_config.json', effectiveAppSrc);
        final hasConfig = await loadContent(configUri) != null;
        if (hasConfig) {
          cfg = await GingaConfig.fromJson(
            'ginga_config.json',
            effectiveAppSrc,
            this,
          );
        } else if (!_isWeb && File('ginga_config.json').existsSync()) {
          cfg = await GingaConfig.fromJson(
            'ginga_config.json',
            effectiveAppSrc,
            this,
          );
        } else {
          cfg = GingaConfig(startWithCCWS: true);
        }
      } catch (e) {
        _logger.warning('Failed to load config: $e');
        cfg = GingaConfig(startWithCCWS: true);
      }
    } else {
      cfg = GingaConfig(startWithCCWS: true);
    }

    final initialAppSrc = effectiveAppSrc ?? cfg.appSrc;
    String? resolvedAppSrc = initialAppSrc;
    if (!_isWeb && initialAppSrc != null && !isHttpUri(initialAppSrc)) {
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
      cfg.appSrc = resolvedAppSrc;
    }

    return cfg;
  }
}
