import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gingacc/gingacc.dart';
import 'package:logging/logging.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'ginga.dart';

export 'args.dart';

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
    try {
      ProcessSignal.sigint.watch().listen((_) {
        exit(0);
      });
    } catch (_) {}
  }

  final parsedArgs = parseArgsCliAndEnv(args);
  final appSrc = parsedArgs.app;
  final configSrc = parsedArgs.config;

  if (!kIsWeb && appSrc == null && configSrc == null) {
    _logger.severe('both APP and CONFIG are empty, exiting');
    exit(1);
  }

  final gingacc = GingaCC();
  await gingacc.loadConfig(configSrc, appSrc);

  _logger.info(gingacc.config.toString());

  runApp(Ginga(
    gingacc: gingacc,
  ));
}
