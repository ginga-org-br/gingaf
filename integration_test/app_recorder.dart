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

    runApp(RecorderApp(config: config));
  } catch (e, st) {
    stderr.writeln('[recorder] Error initializing: $e\n$st');
    exit(1);
  }
}

class RecorderApp extends StatefulWidget {
  final AppRecoderConfig config;

  const RecorderApp({
    super.key,
    required this.config,
  });

  @override
  State<RecorderApp> createState() => _RecorderAppState();
}

class _RecorderAppState extends State<RecorderApp> {
  final GlobalKey _boundaryKey = GlobalKey();
  Timer? _timer;
  int _frameIndex = 0;
  late Directory _capturesDir;
  late GingaCC _gingacc;

  @override
  void initState() {
    super.initState();
    final outPath = widget.config.outputDir ?? 'build/captures';
    _capturesDir = Directory(outPath);
    if (_capturesDir.existsSync()) {
      _capturesDir.deleteSync(recursive: true);
    }
    _capturesDir.createSync(recursive: true);

    _gingacc = GingaCC(
      config: GingaConfig(
        appSrc: widget.config.appSrc,
        startWithCCWS: true,
      ),
    );

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
          await _gingacc.ccws.stop();
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
          body: Ginga(gingacc: _gingacc),
        ),
      ),
    );
  }
}
