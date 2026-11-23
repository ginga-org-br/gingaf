import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:gingacc/gingacc.dart';
import 'package:logging/logging.dart';
import 'package:plugins/plugins_registry.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'args.dart';
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

  if (parsedArgs.remoteDevice != null && parsedArgs.remoteDevice!.isNotEmpty) {
    final gingacc = GingaCC();
    final deviceClass = parsedArgs.remoteDevice!;
    final remoteKey = GlobalKey<RemoteDevicePlayerWidgetState>();
    runApp(
      MaterialApp(
        title: 'gingaf-remote',
        home: Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF252526),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF2D2D2D), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Remote Device class_id=$deviceClass',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFCCCCCC),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('standalone_remote_restart_button'),
                      tooltip: 'Restart Companion',
                      icon: const Icon(Icons.restart_alt_rounded, size: 14),
                      color: const Color(0xFF9E9E9E),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 22),
                      onPressed: () => remoteKey.currentState?.restart(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RemoteDevicePlayerWidget(
                  key: remoteKey,
                  gingacc: gingacc,
                  deviceClass: deviceClass,
                  useSsdpDiscovery: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }

  if (!kIsWeb &&
      parsedArgs.playground != true &&
      appSrc == null &&
      configSrc == null) {
    _logger.severe('both APP and CONFIG are empty, exiting');
    exit(1);
  }

  final gingacc = GingaCC();
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
