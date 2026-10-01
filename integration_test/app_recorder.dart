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
  Offset? _pointerPos;
  bool _pointerClicking = false;
  int _pointerHideTick = 0;

  Offset? _findCenterOfWidgetKey(Key key) {
    Element? findElement(Element element) {
      if (element.widget.key == key) return element;
      Element? result;
      element.visitChildren((child) {
        result ??= findElement(child);
      });
      return result;
    }

    final element = findElement(context as Element);
    final renderBox = element?.renderObject as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      return renderBox.localToGlobal(renderBox.size.center(Offset.zero));
    }
    return null;
  }

  void _updatePointer(Key key, {required bool clicking}) {
    final pos = _findCenterOfWidgetKey(key);
    if (pos != null) {
      setState(() {
        _pointerPos = pos;
        _pointerClicking = clicking;
        _pointerHideTick = (_timer?.tick ?? 0) + 4;
      });
    }
  }

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

        if (_pointerPos != null && currentStep > _pointerHideTick) {
          setState(() {
            _pointerPos = null;
            _pointerClicking = false;
          });
        } else if (_pointerClicking && currentStep > _pointerHideTick - 2) {
          setState(() {
            _pointerClicking = false;
          });
        }

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
          final rawAction = widget.config.userEvents[currentStep]!;
          final actions =
              rawAction.contains(';') ? rawAction.split(';') : [rawAction];
          for (final a in actions) {
            final action = a.trim();
            if (action == 'open_menu' || action == 'toggle_menu') {
              _gingaKey.currentState?.openSettingsMenu();
              _updatePointer(const Key('floating_menu_toggle_button'),
                  clicking: true);
            } else if (action == 'close_menu') {
              _gingaKey.currentState?.closeSettingsMenu();
              _updatePointer(const Key('floating_menu_toggle_button'),
                  clicking: true);
            } else if (action == 'open_users') {
              _gingaKey.currentState?.openUsersOverlay();
              _updatePointer(const Key('floating_users_button'), clicking: true);
            } else if (action == 'close_users') {
              _gingaKey.currentState?.closeUsersOverlay();
            } else if (action == 'forward_2s' ||
                action == 'forward2s' ||
                action == 'skip_2s' ||
                action == 'skip') {
              _gingaKey.currentState?.clickForward2s();
              _updatePointer(const Key('floating_forward_2s_button'),
                  clicking: true);
            } else if (action == 'toggle_pause' ||
                action == 'pause' ||
                action == 'resume' ||
                action == 'play') {
              _gingaKey.currentState?.clickTogglePause();
              _updatePointer(const Key('floating_pause_button'), clicking: true);
            } else if ((action.startsWith('forward_') ||
                    action.startsWith('skip_')) &&
                action.endsWith('s')) {
              final prefix =
                  action.startsWith('forward_') ? 'forward_' : 'skip_';
              final secondsStr =
                  action.substring(prefix.length, action.length - 1);
              final seconds = int.tryParse(secondsStr);
              if (seconds != null) {
                final steps = seconds ~/ 2;
                for (var s = 0; s < steps; s++) {
                  _gingaKey.currentState?.clickForward2s();
                }
                _updatePointer(const Key('floating_forward_2s_button'),
                    clicking: true);
              }
            } else {
              _gingaKey.currentState?.selectUser(action);
            }
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
          body: Stack(
            children: [
              Ginga(
                key: _gingaKey,
                gingacc: widget.gingacc,
              ),
              if (_pointerPos != null)
                Positioned(
                  left: _pointerPos!.dx - 12,
                  top: _pointerPos!.dy - 12,
                  child: IgnorePointer(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_pointerClicking)
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.35),
                              border: Border.all(
                                color: Colors.blueAccent,
                                width: 3,
                              ),
                            ),
                          ),
                        Icon(
                          Icons.touch_app,
                          size: 32,
                          color:
                              _pointerClicking ? Colors.blueAccent : Colors.white,
                          shadows: const [
                            Shadow(
                              blurRadius: 6,
                              color: Colors.black87,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
