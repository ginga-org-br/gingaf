/// Main Ginga player application and widgets.
library ginga;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gingacc/gingacc.dart';
import 'package:logging/logging.dart';
import 'package:nclui/html.dart' as html;
import 'package:nclui/main_av.dart';
import 'package:nclui/ncl.dart' as ncl;
import 'package:playground/playground.dart';

import 'menu/settings_menu.dart';
import 'menu/users_menu.dart';
import 'web_utils_stub.dart' if (dart.library.js_interop) 'web_utils_web.dart';

export 'package:playground/playground.dart';

export 'main.dart';
export 'menu/settings_menu.dart';
export 'menu/users_menu.dart';
export 'web_utils_stub.dart' if (dart.library.js_interop) 'web_utils_web.dart';

final _logger = Logger('ginga');

/// {@category Build}
class Ginga extends StatefulWidget {
  final GingaCC? gingacc;

  const Ginga({
    super.key,
    this.gingacc,
  });

  @override
  State<Ginga> createState() => GingaState();
}

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
  StreamSubscription<String>? _tv30KeySub;
  StreamSubscription<double>? _tv30TimeSub;
  StreamSubscription<String>? _tv30StreamEventSub;

  void _ensureMainAvMounted() {
    if (mainAVWidget == null && !isTv30Mode()) {
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
    final isOverlay = isTv30Mode();
    _showCatalogSelector = _gingacc.config.enablePlayground &&
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

    if (kIsWeb) {
      _tv30KeySub = tv30KeyStream.listen((rawKey) {
        if (_isExiting) return;
        final nclKey = mapTv30KeyToNclKey(rawKey);
        if (nclKey == 'ESCAPE') {
          if (_showUsersOverlay) {
            closeUsersOverlay();
          } else {
            _cleanup();
          }
        } else if (nclKey != null) {
          _nclAppKey.currentState?.handleKeyPress(nclKey);
        }
      });
      _tv30TimeSub = tv30TimeStream.listen((time) {});
      _tv30StreamEventSub = tv30StreamEventStream.listen((event) {
        _logger.info('Received TV 3.0 stream event: $event');
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
    if (_gingacc.config.enablePlayground) {
      _loadMainAppContent();
    }
    if (appSrc != null) {
      final lowerSrc = appSrc.toLowerCase();
      if (lowerSrc.endsWith('.html') ||
          lowerSrc.endsWith('.htm') ||
          lowerSrc.endsWith('.xhtml')) {
        htmlApp = html.HtmlWidget(
          src: appSrc,
          gingacc: _gingacc,
        );
      } else {
        nclApp = ncl.NclWidget(
          key: _nclAppKey,
          src: appSrc,
          gingacc: _gingacc,
          mainAvKey: _mainAvKey,
          onRequestMainAv: _ensureMainAvMounted,
          onBreakpointHit: (media, action, line) {
            if (!_isPaused) {
              setState(() {
                _isPaused = true;
              });
            }
            _playgroundKey.currentState?.pauseAtLine(line);
          },
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

  void _savePlaygroundVirtualFiles() {
    final currentFiles =
        Map<String, String>.from(_gingacc.virtualFiles ?? {});
    if (_mainAppContent != null && _gingacc.config.appSrc != null) {
      currentFiles[_gingacc.config.appSrc!] = _mainAppContent!;
    }
    final editorFiles = _playgroundKey.currentState?.allFileContents;
    if (editorFiles != null) {
      for (final entry in editorFiles.entries) {
        currentFiles[entry.key] = entry.value;
        if (!entry.key.startsWith('examples/')) {
          currentFiles['examples/${entry.key}'] = entry.value;
        }
        if (entry.key.contains('/')) {
          currentFiles[entry.key.split('/').last] = entry.value;
        }
      }
    }
    _gingacc.setVirtualFiles(currentFiles);
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
        if ((kIsWeb && !isTv30Mode()) || _gingacc.config.enablePlayground) {
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
    _tv30KeySub?.cancel();
    _tv30TimeSub?.cancel();
    _tv30StreamEventSub?.cancel();
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

    final isOverlay = isTv30Mode();
    return Container(
      color: isOverlay ? Colors.transparent : Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (mainAVWidget != null) mainAVWidget!,
          if (htmlApp != null) htmlApp!,
          if (nclApp != null) nclApp!,
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
    final isOverlay = isTv30Mode();
    return MaterialApp(
      title: 'gingaf',
      themeMode: ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor:
            isOverlay ? Colors.transparent : Colors.grey[200],
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
                          child: KeyedSubtree(
                            key: const Key('flutter_monaco_widget'),
                            child: PlaygroundEditor(
                              key: _playgroundKey,
                              content: _mainAppContent ?? '',
                              filePath: _gingacc.config.appSrc,
                              gingacc: _gingacc,
                              isRunning: _isRunning,
                              showCatalogSelector: _showCatalogSelector,
                              onCatalogExampleSelected: (selectedFile) {
                                final appPath = selectedFile.startsWith('examples/')
                                    ? selectedFile
                                    : 'examples/$selectedFile';
                                _gingacc.config =
                                    _gingacc.config.copyWith(appSrc: appPath);
                                if (kIsWeb) {
                                  updateWebUrlApp(selectedFile);
                                }
                              },
                              onContentChanged: (newText) {
                                _mainAppContent = newText;
                              },
                              onRun: () {
                                _savePlaygroundVirtualFiles();
                                _restart();
                              },
                              onStop: _stopFromPlayground,
                              onDebug: () {
                                _savePlaygroundVirtualFiles();
                                _restart();
                              },
                              onContinue: () {
                                resume();
                              },
                              onReload: () {
                                _savePlaygroundVirtualFiles();
                                _restart();
                              },
                              initialBreakpoints: _gingacc.config.breakpoints,
                              onBreakpointsChanged: (newBps) {
                                setBreakpoints(newBps);
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: _buildPlayer(context),
                        ),
                      ],
                    )
                  : _buildPlayer(context),
        ),
      ),
    );
  }
}
