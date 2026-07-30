import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'ginga.dart';

import 'web_utils_stub.dart' if (dart.library.html) 'web_utils_web.dart';

final _logger = Logger('ginga');

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint(
        '[${record.loggerName}] ${record.level.name}: ${record.message}');
  });

  String? app = const String.fromEnvironment('APP').isNotEmpty
      ? const String.fromEnvironment('APP')
      : null;
  if (app == null && !kIsWeb) {
    app = Platform.environment['APP'];
  }
  if (app == null && kIsWeb) {
    try {
      final mainFile = getSessionStorageItem('GINGA_PLAYGROUND_MAIN');
      if (mainFile != null && mainFile.isNotEmpty) {
        app = mainFile;
      }
    } catch (e) {
      _logger.warning(
          'Failed to read GINGA_PLAYGROUND_MAIN from session storage: $e');
    }
  }
  final appSrc = (app != null && app.isNotEmpty) ? app : null;

  String? effectiveAppSrc = appSrc;
  if (!kIsWeb && appSrc != null) {
    _logger.info('Initial working directory: ${Directory.current.path}');
    try {
      final file = File(appSrc).absolute;
      _logger.info('Resolved app path: ${file.path}');
      if (file.existsSync()) {
        Directory.current = file.parent.path;
        _logger.info('Switched working directory to ${Directory.current.path}');
        effectiveAppSrc = file.path.split('/').last.split('\\').last;
      }
    } catch (e) {
      _logger.severe('Failed to set working directory: $e');
    }

    try {
      if (stdin.hasTerminal) {
        stdin.echoMode = false;
        stdin.lineMode = false;
      }
      stdin.listen((List<int> codes) {
        if (codes.contains(27)) {
          _logger.info('Captured ESC, stopping app.');
          exit(0);
        }
      });
    } catch (e) {
      _logger.severe('Failed to setup stdin listener: $e');
    }
  }

  String? mainav;
  if (const bool.hasEnvironment('MAINAV')) {
    mainav = const String.fromEnvironment('MAINAV');
  } else if (!kIsWeb && Platform.environment.containsKey('MAINAV')) {
    mainav = Platform.environment['MAINAV'];
  }
  final mainAvSrc =
      (mainav != null && mainav.isNotEmpty && mainav != 'true' && mainav != 'false')
          ? mainav
          : DEFAULT_VIDEO;

  bool ccws = const bool.fromEnvironment('CCWS', defaultValue: true);
  if (!kIsWeb) {
    if (Platform.environment.containsKey('CCWS')) {
      final val = Platform.environment['CCWS'];
      ccws = val == 'true';
    }
  }

  String? usersDataJson = const String.fromEnvironment('USERS_DATA').isNotEmpty
      ? const String.fromEnvironment('USERS_DATA')
      : null;
  if (usersDataJson == null) {
    if (kIsWeb) {
      usersDataJson = Uri.base.queryParameters['USERS_DATA'];
    } else {
      usersDataJson = Platform.environment['USERS_DATA'];
    }
  }
  final usersDataSrc =
      (usersDataJson != null && usersDataJson.isNotEmpty) ? usersDataJson : null;

  final config = GingaConfig(
    effectiveAppSrc,
    ccws,
    mainav != null && mainav != 'false',
    usersDataSrc,
    mainAvSrc,
  );
  _logger.info(config.toString());

  runApp(Ginga(config: config));
}
