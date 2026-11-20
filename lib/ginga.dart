/// Main Ginga player application and widgets.
library ginga;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:gingacc/gingacc.dart';
import 'package:logging/logging.dart';
import 'package:nclui/html_widget.dart' as html;
import 'package:nclui/main_av_widget.dart';
import 'package:nclui/ncl_widget.dart' as ncl;
import 'package:playground/playground.dart';

import 'menu/settings_menu.dart';
import 'menu/users_menu.dart';
import 'web_utils_stub.dart' if (dart.library.js_interop) 'web_utils_web.dart';

final _logger = Logger('ginga');

/// {@category Build}
class Ginga extends StatefulWidget {
  final GingaCC? gingacc;
  final String? content;
  final Map<String, String>? virtualFiles;

  const Ginga({
    super.key,
    this.gingacc,
  })  : content = null,
        virtualFiles = null;

  const Ginga.fromContent(
    String this.content, {
    super.key,
    this.virtualFiles,
    this.gingacc,
  });

  @override
  State<Ginga> createState() => GingaState();
}

/// @nodoc
class GingaState extends State<Ginga> {
  late final GingaCC _gingacc;
  Widget? mainAVWidget;
  Widget? htmlApp;
  Widget? nclApp;
  String? _mainAppContent;
  bool _isExiting = false;
  bool get isExiting => _isExiting;
  bool _isRunning = true;
  bool get isRunning => _isRunning;
  bool _initialized = false;
  bool _isPaused = false;
  bool _showUsersOverlay = false;
  late final bool _showCatalogSelector;

  GlobalKey<ncl.NclWidgetState> _nclAppKey = GlobalKey<ncl.NclWidgetState>();
  GlobalKey<MainAVWidgetState> _mainAvKey = GlobalKey<MainAVWidgetState>();
  final GlobalKey<PlaygroundEditorState> _playgroundKey =
      GlobalKey<PlaygroundEditorState>();
  final GlobalKey<SettingsMenuState> _settingsMenuKey =
      GlobalKey<SettingsMenuState>();
  void Function()? _detachTv30Testbed;

  void _ensureMainAvMounted() {
    if (mainAVWidget == null && !isTv30Testbed()) {
      setState(() {
        mainAVWidget = MainAVWidget(
          key: _mainAvKey,
          src: _gingacc.config.mainAvSrc,
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _gingacc = widget.gingacc ?? GingaCC();
    if (widget.content != null) {
      _mainAppContent = widget.content;
      if (_gingacc.config.appSrc == null ||
          _gingacc.config.appSrc!.trim().isEmpty) {
        _gingacc.config.appSrc = 'main.ncl';
      }
    }
    final isOverlay = isTv30Testbed();
    _showCatalogSelector = _gingacc.config.enablePlayground &&
        widget.content == null &&
        (_gingacc.config.appSrc == null ||
            _gingacc.config.appSrc!.trim().isEmpty);
    if (_gingacc.config.enablePlayground) {
      _isRunning = false;
    } else {
      _isRunning = true;
      if (_gingacc.config.startWithMainAv && !isOverlay) {
        mainAVWidget = MainAVWidget(
          key: _mainAvKey,
          src: _gingacc.config.mainAvSrc,
        );
      }
    }

    if (_gingacc.config.startWithCCWS) {
      _gingacc.ccws.start();
    }
    HardwareKeyboard.instance.addHandler(_handleKeyPress);

    if (kIsWeb && isOverlay) {
      attachTv30Testbed(
        onKey: (nclKey) {
          if (_isExiting) return;
          if (nclKey == 'ESCAPE') {
            if (_showUsersOverlay) {
              closeUsersOverlay();
            } else {
              _cleanup();
            }
          } else {
            _nclAppKey.currentState?.handleKeyPress(nclKey);
          }
        },
        onStreamEvent: (event) {
          _logger.info('Received TV 3.0 stream event: $event');
        },
      ).then((detach) {
        if (mounted) {
          _detachTv30Testbed = detach;
        } else {
          detach?.call();
        }
      });
    }
  }

  Future<void> _autoResizeWindow() async {
    if (!kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      try {
        const channel = MethodChannel('gingaf/window');
        await channel.invokeMethod('autoResize', {
          'playground': _gingacc.config.enablePlayground,
        });
      } catch (_) {}
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _autoResizeWindow();
      if (_gingacc.config.enablePlayground) {
        _loadMainAppContent();
      } else {
        _setupApp();
      }
    }
  }

  Future<void> _loadMainAppContent() async {
    if (_mainAppContent != null && _mainAppContent!.isNotEmpty) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final appSrc = _gingacc.config.appSrc;
    if (appSrc != null) {
      if (appSrc.trim().startsWith('<')) {
        _mainAppContent = appSrc;
      } else {
        try {
          final loaded = await _gingacc.loadContent(appSrc);
          if (loaded != null) {
            _mainAppContent = loaded;
          }
        } catch (e) {
          _logger.warning('Failed to load main app content for playground: $e');
        }
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _setupApp() {
    final appSrc = _gingacc.config.appSrc;
    if (_gingacc.config.enablePlayground && _mainAppContent == null) {
      _loadMainAppContent();
    }
    if (appSrc != null) {
      final editorFiles = _gingacc.config.enablePlayground
          ? _playgroundKey.currentState?.allFileContents
          : null;
      final virtualFiles = (widget.virtualFiles != null || editorFiles != null)
          ? <String, String>{
              ...?widget.virtualFiles,
              ...?editorFiles,
            }
          : null;
      final content =
          (_gingacc.config.enablePlayground || widget.content != null)
              ? (_mainAppContent ?? widget.content)
              : null;

      void onBreakpointHit(Object? media, Object? action, int line) {
        if (!_isPaused) {
          setState(() {
            _isPaused = true;
          });
        }
        _playgroundKey.currentState?.pauseAtLine(line);
      }

      final lowerSrc = appSrc.toLowerCase();
      if (lowerSrc.endsWith('.html') ||
          lowerSrc.endsWith('.htm') ||
          lowerSrc.endsWith('.xhtml')) {
        htmlApp = content != null
            ? html.HtmlWidget.fromContent(
                content,
                src: appSrc,
                virtualFiles: virtualFiles,
                gingacc: _gingacc,
              )
            : html.HtmlWidget(
                src: appSrc,
                gingacc: _gingacc,
              );
      } else {
        nclApp = content != null
            ? ncl.NclWidget.fromContent(
                content,
                key: _nclAppKey,
                src: appSrc,
                virtualFiles: virtualFiles,
                gingacc: _gingacc,
                mainAvKey: _mainAvKey,
                onRequestMainAv: _ensureMainAvMounted,
                onBreakpointHit: onBreakpointHit,
              )
            : ncl.NclWidget(
                key: _nclAppKey,
                src: appSrc,
                gingacc: _gingacc,
                mainAvKey: _mainAvKey,
                onRequestMainAv: _ensureMainAvMounted,
                onBreakpointHit: onBreakpointHit,
              );
      }
    }
  }

  void _restart() {
    _logger.info('Restarting Ginga application');
    setState(() {
      _isRunning = true;
      _isPaused = false;
      _showUsersOverlay = false;
      htmlApp = null;
      nclApp = null;
      mainAVWidget = null;
    });
    _stopServices();
    if (_gingacc.config.startWithCCWS) {
      _gingacc.ccws.start();
    }
    _nclAppKey = GlobalKey<ncl.NclWidgetState>();
    _mainAvKey = GlobalKey<MainAVWidgetState>();
    if (_gingacc.config.startWithMainAv) {
      _ensureMainAvMounted();
    }
    setState(() {
      _setupApp();
    });
  }

  Future<void> _applyPlaygroundConfig(
    String? appPath, {
    required bool resetIfMissing,
    bool fromCatalog = false,
  }) async {
    final enablePlayground = _gingacc.config.enablePlayground;
    final currentBps = List<int>.from(_gingacc.config.breakpoints);

    String? configJson;
    final editorState = _playgroundKey.currentState;
    final editorFiles = editorState?.allFileContents;
    final isCatalogApp = fromCatalog ||
        (_showCatalogSelector && editorState?.selectedExample != null);

    if (editorFiles != null) {
      for (final entry in editorFiles.entries) {
        final normalizedKey = entry.key.replaceAll('\\', '/');
        if (normalizedKey == 'ginga_config.json' ||
            normalizedKey.endsWith('/ginga_config.json')) {
          configJson = entry.value;
          break;
        }
      }
    }

    if (configJson == null &&
        !isCatalogApp &&
        appPath != null &&
        appPath.trim().isNotEmpty &&
        !appPath.trim().startsWith('<')) {
      final normalizedApp = appPath.replaceAll('\\', '/');
      final slashIdx = normalizedApp.lastIndexOf('/');
      final siblingConfigPath = slashIdx != -1
          ? '${normalizedApp.substring(0, slashIdx)}/ginga_config.json'
          : 'ginga_config.json';
      if (widget.virtualFiles != null &&
          widget.virtualFiles!.containsKey(siblingConfigPath)) {
        configJson = widget.virtualFiles![siblingConfigPath];
      } else if (!kIsWeb &&
          !isHttpUri(siblingConfigPath) &&
          !siblingConfigPath.startsWith('file:')) {
        final f = File(siblingConfigPath);
        if (f.existsSync()) {
          configJson = f.readAsStringSync();
        }
      } else {
        final configUri = _gingacc.resolveUri('ginga_config.json', appPath);
        configJson = await _gingacc.loadContent(configUri);
      }
    }

    if (configJson != null && configJson.trim().isNotEmpty) {
      try {
        final loadedCfg = await GingaConfig.fromJson(
          configJson,
          appPath,
          _gingacc,
        );
        _gingacc.config = loadedCfg.copyWith(
          appSrc: appPath ?? loadedCfg.appSrc,
          enablePlayground: enablePlayground,
          breakpoints:
              currentBps.isNotEmpty ? currentBps : loadedCfg.breakpoints,
        );
        return;
      } catch (e) {
        _logger.warning('Failed to parse playground ginga_config.json: $e');
      }
    }

    if (resetIfMissing) {
      _gingacc.config = GingaConfig(
        appSrc: appPath,
        startWithCCWS: true,
        enablePlayground: enablePlayground,
        breakpoints: currentBps,
      );
    } else if (appPath != null && _gingacc.config.appSrc != appPath) {
      _gingacc.config = _gingacc.config.copyWith(
        appSrc: appPath,
      );
    }
  }

  Future<void> _runFromPlayground() async {
    final appSrc =
        _gingacc.config.appSrc ?? _playgroundKey.currentState?.activeFilePath;
    await _applyPlaygroundConfig(
      appSrc,
      resetIfMissing: false,
    );
    if (!mounted) return;
    _restart();
  }

  void _stopFromPlayground() {
    _logger.info('Stopping Ginga application from playground');
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _showUsersOverlay = false;
      htmlApp = null;
      nclApp = null;
      mainAVWidget = null;
    });
    _stopServices();
  }

  void pause() {
    if (!_isPaused) {
      setState(() {
        _isPaused = true;
      });
    }
    _nclAppKey.currentState?.pause();
    _mainAvKey.currentState?.controller?.pause();
  }

  void resume() {
    if (_isPaused) {
      setState(() {
        _isPaused = false;
      });
    }
    _nclAppKey.currentState?.resume();
    _mainAvKey.currentState?.controller?.play();
    _playgroundKey.currentState?.resumeFromPlayer();
  }

  void setBreakpoints(Iterable<int> breakpoints) {
    _gingacc.config.breakpoints
      ..clear()
      ..addAll(breakpoints);
    _nclAppKey.currentState?.setBreakpoints(breakpoints);
  }

  void togglePause() {
    final currentPaused =
        _isPaused || (_nclAppKey.currentState?.isPaused ?? false);
    if (currentPaused) {
      resume();
    } else {
      pause();
    }
  }

  void forward2s() {
    setState(() {
      _isPaused = true;
    });
    _mainAvKey.currentState?.controller?.pause();
    _nclAppKey.currentState?.forward(const Duration(seconds: 2));
    if (_nclAppKey.currentState == null) {
      final c = _mainAvKey.currentState?.controller;
      if (c != null && c.value.isInitialized) {
        c.seekTo(c.value.position + const Duration(seconds: 2));
      }
    }
  }

  void openUsersOverlay() {
    setState(() {
      _showUsersOverlay = true;
    });
  }

  void closeUsersOverlay() {
    setState(() {
      _showUsersOverlay = false;
    });
  }

  void openSettingsMenu() {
    _settingsMenuKey.currentState?.open();
  }

  void closeSettingsMenu() {
    _settingsMenuKey.currentState?.close();
  }

  void toggleSettingsMenu() {
    _settingsMenuKey.currentState?.toggle();
  }

  void clickForward2s() {
    _settingsMenuKey.currentState?.clickForward2s();
    if (_settingsMenuKey.currentState == null) {
      forward2s();
    }
  }

  void clickTogglePause() {
    _settingsMenuKey.currentState?.clickTogglePause();
    if (_settingsMenuKey.currentState == null) {
      togglePause();
    }
  }

  void selectUser(String userId) {
    final user = _gingacc.config.users.getUser(userId);
    if (user != null) {
      final changes = _gingacc.config.users.diffNewCurrentUser(user.id);
      _gingacc.config.users.setCurrentUser(user.id);
      for (final entry in changes.entries) {
        _gingacc.config.systemVariables[entry.key] = entry.value;
        _nclAppKey.currentState?.nclDocument?.dispatchSettingsUpdate(
            entry.key, entry.value,
            userId: 'currentUser');
      }
      _showUsersOverlay = false;
      setState(() {});
    }
  }

  bool _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_showUsersOverlay) {
          closeUsersOverlay();
          return true;
        }
        if ((kIsWeb && !isTv30Testbed()) || _gingacc.config.enablePlayground) {
          return false;
        }
        _logger.info('Captured ESC in Window, stopping app and mainAV.');
        _cleanup();
        return true;
      }
      if (_showUsersOverlay) {
        return false;
      }
      final currentFocus = FocusManager.instance.primaryFocus;
      if (currentFocus?.context?.widget is EditableText) {
        return false;
      }
      if (_playgroundKey.currentState?.isCatalogOpen == true) {
        return false;
      }
      String? nclKey;
      final lk = event.logicalKey;
      if (lk == LogicalKeyboardKey.arrowRight) {
        nclKey = 'RIGHT';
      } else if (lk == LogicalKeyboardKey.arrowLeft) {
        nclKey = 'LEFT';
      } else if (lk == LogicalKeyboardKey.arrowUp) {
        nclKey = 'UP';
      } else if (lk == LogicalKeyboardKey.arrowDown) {
        nclKey = 'DOWN';
      } else if (lk == LogicalKeyboardKey.enter ||
          lk == LogicalKeyboardKey.numpadEnter ||
          lk == LogicalKeyboardKey.select) {
        nclKey = 'ENTER';
      } else if (lk == LogicalKeyboardKey.f1 || lk == LogicalKeyboardKey.keyR) {
        nclKey = 'RED';
      } else if (lk == LogicalKeyboardKey.f2 || lk == LogicalKeyboardKey.keyG) {
        nclKey = 'GREEN';
      } else if (lk == LogicalKeyboardKey.f3 || lk == LogicalKeyboardKey.keyY) {
        nclKey = 'YELLOW';
      } else if (lk == LogicalKeyboardKey.f4 || lk == LogicalKeyboardKey.keyB) {
        nclKey = 'BLUE';
      } else if (lk == LogicalKeyboardKey.f5 || lk == LogicalKeyboardKey.keyI) {
        nclKey = 'INFO';
      } else if (lk == LogicalKeyboardKey.digit0 ||
          lk == LogicalKeyboardKey.numpad0) {
        nclKey = '0';
      } else if (lk == LogicalKeyboardKey.digit1 ||
          lk == LogicalKeyboardKey.numpad1) {
        nclKey = '1';
      } else if (lk == LogicalKeyboardKey.digit2 ||
          lk == LogicalKeyboardKey.numpad2) {
        nclKey = '2';
      } else if (lk == LogicalKeyboardKey.digit3 ||
          lk == LogicalKeyboardKey.numpad3) {
        nclKey = '3';
      } else if (lk == LogicalKeyboardKey.digit4 ||
          lk == LogicalKeyboardKey.numpad4) {
        nclKey = '4';
      } else if (lk == LogicalKeyboardKey.digit5 ||
          lk == LogicalKeyboardKey.numpad5) {
        nclKey = '5';
      } else if (lk == LogicalKeyboardKey.digit6 ||
          lk == LogicalKeyboardKey.numpad6) {
        nclKey = '6';
      } else if (lk == LogicalKeyboardKey.digit7 ||
          lk == LogicalKeyboardKey.numpad7) {
        nclKey = '7';
      } else if (lk == LogicalKeyboardKey.digit8 ||
          lk == LogicalKeyboardKey.numpad8) {
        nclKey = '8';
      } else if (lk == LogicalKeyboardKey.digit9 ||
          lk == LogicalKeyboardKey.numpad9) {
        nclKey = '9';
      }
      if (nclKey != null) {
        _nclAppKey.currentState?.handleKeyPress(nclKey);
        return true;
      }
    }
    return false;
  }

  void _stopServices() {
    _gingacc.ccws.stop();
  }

  Future<void> _cleanup() async {
    if (_isExiting) return;
    setState(() {
      _isExiting = true;
      _isRunning = false;
      htmlApp = null;
      nclApp = null;
      mainAVWidget = null;
    });
    _stopServices();
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      Future.delayed(const Duration(milliseconds: 200), () => exit(0));
    } else if (kIsWeb) {
      notifyParentAppExited();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyPress);
    _detachTv30Testbed?.call();
    _stopServices();
    super.dispose();
  }

  Widget _buildPlayer(BuildContext context) {
    if (!_isRunning) {
      return Container(
        key: const Key('no_running_app_placeholder'),
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Colors.white54,
              ),
              SizedBox(height: 16),
              Text(
                'No running application',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Click Run or Start Debugging to begin',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isOverlay = isTv30Testbed();
    final planeBounds = _gingacc.config.graphicPlaneBounds;
    final planeWidth = planeBounds.width > 0 ? planeBounds.width : 1280.0;
    final planeHeight = planeBounds.height > 0 ? planeBounds.height : 720.0;
    final useNativeOverlayLayout = !kIsWeb &&
        Platform.isLinux &&
        !Platform.environment.containsKey('FLUTTER_TEST');
    final Widget playerStack = Stack(
      fit: StackFit.expand,
      children: [
        if (mainAVWidget != null) mainAVWidget!,
        if (htmlApp != null) htmlApp!,
        if (nclApp != null) nclApp!,
      ],
    );
    return Container(
      color: isOverlay ? Colors.transparent : Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          useNativeOverlayLayout
              ? Center(
                  child: AspectRatio(
                    aspectRatio: planeWidth / planeHeight,
                    child: playerStack,
                  ),
                )
              : SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: planeWidth,
                      height: planeHeight,
                      child: MediaQuery(
                        data: (MediaQuery.maybeOf(context) ??
                                const MediaQueryData())
                            .copyWith(size: Size(planeWidth, planeHeight)),
                        child: playerStack,
                      ),
                    ),
                  ),
                ),
          if (!_showUsersOverlay)
            SettingsMenu(
              key: _settingsMenuKey,
              isPaused: _isPaused,
              onReload: _restart,
              onTogglePause: togglePause,
              onForward2s: forward2s,
              onOpenUsers: openUsersOverlay,
            ),
          if (_showUsersOverlay)
            UsersMenu(
              users: _gingacc.config.users,
              onClose: closeUsersOverlay,
              onUserSelected: (_) => closeUsersOverlay(),
              dispatchCurrentUserUpdate: (name, value) {
                _gingacc.config.systemVariables[name] = value;
                _nclAppKey.currentState?.nclDocument?.dispatchSettingsUpdate(
                    name, value,
                    userId: 'currentUser');
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOverlay = isTv30Testbed();
    return MaterialApp(
      title: 'gingaf',
      themeMode: ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor:
            isOverlay ? Colors.transparent : const Color(0xFF1E1E1E),
      ),
      home: NotificationListener<ncl.NclWidgetExitNotification>(
        onNotification: (notification) {
          if (_gingacc.config.enablePlayground) {
            _logger.info(
                'Received NclWidgetExitNotification in playground mode. Keeping playground active.');
            setState(() {
              _isRunning = false;
            });
            return true;
          }
          _logger.info(
              'Received NclWidgetExitNotification. Cleaning up and exiting.');
          _cleanup();
          return true;
        },
        child: Scaffold(
          backgroundColor: isOverlay ? Colors.transparent : null,
          body: _isExiting
              ? const SizedBox.shrink()
              : _gingacc.config.enablePlayground
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 1,
                          child: RepaintBoundary(
                            child: KeyedSubtree(
                              key: const Key('flutter_monaco_widget'),
                              child: PlaygroundEditor(
                                key: _playgroundKey,
                                content: _mainAppContent ?? '',
                                filePath: _gingacc.config.appSrc,
                                gingacc: _gingacc,
                                isRunning: _isRunning,
                                showCatalogSelector: _showCatalogSelector,
                                onCatalogExampleSelected: (selectedFile) async {
                                  final appPath =
                                      resolveCatalogExampleUrl(selectedFile);
                                  await _applyPlaygroundConfig(
                                    appPath,
                                    resetIfMissing: true,
                                    fromCatalog: true,
                                  );
                                },
                                onContentChanged: (newText) {
                                  _mainAppContent = newText;
                                },
                                onRun: _runFromPlayground,
                                onStop: _stopFromPlayground,
                                onDebug: _runFromPlayground,
                                onContinue: () {
                                  resume();
                                },
                                onReload: _runFromPlayground,
                                initialBreakpoints: _gingacc.config.breakpoints,
                                onBreakpointsChanged: (newBps) {
                                  setBreakpoints(newBps);
                                },
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: RepaintBoundary(
                            child: _buildPlayer(context),
                          ),
                        ),
                      ],
                    )
                  : _buildPlayer(context),
        ),
      ),
    );
  }
}
