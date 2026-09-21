import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gingacc/gingacc.dart';
import 'package:gingaf/ginga.dart';
import 'package:logging/logging.dart';
import 'package:nclui/ncl_keys_flutter.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'app_recorder_config.dart';

void main(List<String> args) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    Logger.root.level = Level.WARNING;
    Logger.root.onRecord.listen((record) {
      stdout.writeln(
          '[${record.loggerName}] ${record.level.name}: ${record.message}');
    });
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      VideoPlayerMediaKit.ensureInitialized(
        windows: Platform.isWindows,
        linux: Platform.isLinux,
      );
    }

    final configEnv = const String.fromEnvironment('CONFIG');
    final AppRecoderConfig config;
    if (configEnv.isNotEmpty) {
      config = AppRecoderConfig.fromCli(configEnv);
    } else if (args.isNotEmpty) {
      config = AppRecoderConfig.fromCli(args[0]);
    } else {
      throw ArgumentError(
          'CONFIG must be provided via --dart-define=CONFIG=... or CLI argument');
    }

    final initialGingacc = GingaCC();
    GingaConfig configObj;
    try {
      final configUri =
          initialGingacc.resolveUri('ginga_config.json', config.appSrc);
      final hasConfig = await initialGingacc.loadContent(configUri) != null;
      if (hasConfig) {
        configObj = await GingaConfig.fromJson(
          'ginga_config.json',
          config.appSrc,
          initialGingacc,
        );
      } else {
        configObj = GingaConfig(
          appSrc: config.appSrc,
          startWithCCWS: true,
        );
      }
    } catch (_) {
      configObj = GingaConfig(
        appSrc: config.appSrc,
        startWithCCWS: true,
      );
    }
    configObj.appSrc = config.appSrc;
    final gingacc = GingaCC(
      config: configObj,
    );

    runApp(RecorderApp(config: config, gingacc: gingacc));
  } catch (e, st) {
    stderr.writeln('[recorder] Error initializing: $e\n$st');
    exit(1);
  }
}

class RecorderApp extends StatefulWidget {
  final AppRecoderConfig config;
  final GingaCC gingacc;

  const RecorderApp({
    super.key,
    required this.config,
    required this.gingacc,
  });

  @override
  State<RecorderApp> createState() => _RecorderAppState();
}

class _RecorderAppState extends State<RecorderApp> {
  final GlobalKey _boundaryKey = GlobalKey();
  final GlobalKey<GingaState> _gingaKey = GlobalKey<GingaState>();
  Timer? _timer;
  int _frameIndex = 0;
  late Directory _capturesDir;

  @override
  void initState() {
    super.initState();
    final outPath = widget.config.outputDir ?? 'build/captures';
    _capturesDir = Directory(outPath);
    if (_capturesDir.existsSync()) {
      _capturesDir.deleteSync(recursive: true);
    }
    _capturesDir.createSync(recursive: true);

    Future.delayed(const Duration(milliseconds: 600), () {
      final totalSteps = (widget.config.duration.inMilliseconds /
              widget.config.stepDuration.inMilliseconds)
          .round();

      _timer = Timer.periodic(widget.config.stepDuration, (timer) async {
        if (!mounted) return;

        final currentStep = timer.tick;
        if (widget.config.keyEvents.containsKey(currentStep)) {
          final keyName = widget.config.keyEvents[currentStep]!;
          final logicalKey = NclKeysFlutter.resolveKey(keyName);
          final physicalKey = NclKeysFlutter.resolvePhysicalKey(logicalKey);
          HardwareKeyboard.instance.handleKeyEvent(
            KeyDownEvent(
              physicalKey: physicalKey,
              logicalKey: logicalKey,
              timeStamp: Duration(
                  milliseconds: DateTime.now().millisecondsSinceEpoch),
            ),
          );
        }

        if (widget.config.userEvents.containsKey(currentStep)) {
          final action = widget.config.userEvents[currentStep]!;
          if (action == 'open_users') {
            _gingaKey.currentState?.openUsersOverlay();
          } else if (action == 'close_users') {
            _gingaKey.currentState?.closeUsersOverlay();
          } else {
            _gingaKey.currentState?.selectUser(action);
          }
        }

        final boundary = _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          try {
            final image = await boundary.toImage(pixelRatio: 1.0);
            final byteData =
                await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              final framePath =
                  '${_capturesDir.path}/frame_${_frameIndex.toString().padLeft(4, '0')}.png';
              File(framePath).writeAsBytesSync(byteData.buffer.asUint8List());
              _frameIndex++;
            }
          } catch (_) {}
        }

        if (timer.tick >= totalSteps) {
          timer.cancel();
          await widget.gingacc.ccws.stop();
          final doneMarker = File('${_capturesDir.path}/.done');
          doneMarker.writeAsStringSync('done');
          stdout.writeln('[recorder] done');
          exit(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Ginga(
            key: _gingaKey,
            gingacc: widget.gingacc,
          ),
        ),
      ),
    );
  }
}
