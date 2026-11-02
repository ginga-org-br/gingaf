import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:gingacc/gingacc.dart';
import 'package:logging/logging.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'ginga.dart';
import 'plugins/plugins_registry.dart';

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
    final msg =
        '[${record.loggerName}] ${record.level.name}: ${record.message}';
    if (kIsWeb) {
      debugPrint(msg);
    } else {
      stdout.writeln(msg);
    }
  });

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    try {
      ProcessSignal.sigint.watch().listen((_) {
        exit(0);
      });
    } catch (_) {}
  }

  try {
    registerAllPlugins(GetIt.instance);
  } catch (_) {}

  final parsedArgs = parseArgsCliAndEnv(args);
  final appSrc = parsedArgs.app;
  final configSrc = parsedArgs.config;

  if (!kIsWeb && appSrc == null && configSrc == null) {
    _logger.severe('both APP and CONFIG are empty, exiting');
    exit(1);
  }

  final gingacc = GingaCC();
  if (kIsWeb) {
    try {
      final webFiles = getGingaAppFiles();
      if (webFiles != null && webFiles.isNotEmpty) {
        gingacc.setVirtualFiles(webFiles);
      }
    } catch (e) {
      _logger.warning('Failed to load web virtual files: $e');
    }
  }
  await gingacc.loadConfig(configSrc, appSrc);
  if (parsedArgs.playground != null) {
    gingacc.config = gingacc.config.copyWith(
      enablePlayground: parsedArgs.playground!,
    );
  }
  if (parsedArgs.breakpoints != null && parsedArgs.breakpoints!.isNotEmpty) {
    for (final bp in parsedArgs.breakpoints!) {
      if (!gingacc.config.breakpoints.contains(bp)) {
        gingacc.config.breakpoints.add(bp);
      }
    }
  }

  _logger.info(gingacc.config.toString());

  final gingaKey = GlobalKey<GingaState>();

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    try {
      stdin.transform(utf8.decoder).transform(const LineSplitter()).listen(
          (line) {
        final trimmed = line.trim();
        final lower = trimmed.toLowerCase();
        if (lower == 'continue' || lower == 'c' || lower == 'resume') {
          _logger.info('[Controller] Resuming presentation');
          gingaKey.currentState?.resume();
        } else if (lower == 'pause' || lower == 'p') {
          _logger.info('[Controller] Pausing presentation');
          gingaKey.currentState?.pause();
        } else if (lower == 'forward' || lower == 'f') {
          gingaKey.currentState?.forward2s();
        } else if (lower == 'toggle' || lower == 't') {
          gingaKey.currentState?.togglePause();
        } else if (lower.startsWith('bp ') ||
            lower.startsWith('breakpoints ')) {
          final parts = trimmed.substring(trimmed.indexOf(' ') + 1);
          final lines = parts
              .split(RegExp(r'[\s,]+'))
              .map((s) => int.tryParse(s.trim()))
              .whereType<int>()
              .toList();
          _logger.info('[Controller] Updated breakpoints: $lines');
          gingaKey.currentState?.setBreakpoints(lines);
        }
      }, onError: (e) {
        _logger.warning('[Controller] stdin listener error: $e');
      });
    } catch (e) {
      _logger.warning('[Controller] Could not listen to stdin: $e');
    }
  }

  runApp(Ginga(
    key: gingaKey,
    gingacc: gingacc,
  ));
}
