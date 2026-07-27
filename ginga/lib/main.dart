import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'ginga.dart';

final _logger = Logger('ginga');


void main(List<String> args) {
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

  String? mainav;
  if (const bool.hasEnvironment('MAINAV')) {
    final val = const String.fromEnvironment('MAINAV');
    mainav = (val.isEmpty || val == 'true') ? DEFAULT_VIDEO : val;
  }
  if (mainav == null && !kIsWeb) {
    if (Platform.environment.containsKey('MAINAV')) {
      final val = Platform.environment['MAINAV'];
      mainav = (val == null || val.isEmpty || val == 'true') ? DEFAULT_VIDEO : val;
    }
  }

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

  final config = GingaConfig(app, ccws, mainav, true, usersDataJson);
  runApp(Ginga(config: config));
  _logger.info(config.toString());

  if (!kIsWeb) {
    _logger.info('Initial working directory: ${Directory.current.path}');
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

  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && config.appUri != null) {
    try {
      final file = File(config.appUri!).absolute;
      _logger.info('Resolved app path: ${file.path}');
      if (file.existsSync()) {
        Directory.current = file.parent.path;
        _logger.info('Switched working directory to ${Directory.current.path}');
      }
    } catch (e) {
      _logger.severe('Failed to set working directory: $e');
    }
  }

  runApp(Ginga(config: config));
}
