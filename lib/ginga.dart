/// Main Ginga player application and widgets.
library ginga;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:gingacc/gingacc.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nclui/html_widget.dart' as html;
import 'package:nclui/main_av_widget.dart';
import 'package:nclui/ncl_widget.dart' as ncl;
import 'package:playground/playground.dart';

import 'menu/settings_menu.dart';
import 'menu/users_menu.dart';
import 'remote_device_player_widget.dart';
import 'web_utils_stub.dart' if (dart.library.js_interop) 'web_utils_web.dart';

export 'remote_device_player_widget.dart';

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

class _PlaygroundCompanionInstance {
  final String id;
  final String label;
  final String deviceClass;
  final GlobalKey<RemoteDevicePlayerWidgetState> playerKey;
  final Widget widget;

  const _PlaygroundCompanionInstance({
    required this.id,
    required this.label,
    required this.deviceClass,
    required this.playerKey,
    required this.widget,
  });
}

/// @nodoc
class GingaState extends State<Ginga> {
  late final GingaCC _gingacc;
  Widget? mainAVWidget;
  Widget? htmlApp;
  Widget? nclApp;
  String? _mainAppContent;
  final List<_PlaygroundCompanionInstance> _companions = [];
  final List<Process> _spawnedCompanionProcesses = [];
  int _nextCompanionSeq = 1;
  int get runningCompanionCount =>
      _companions.length + _spawnedCompanionProcesses.length;
  bool _isExiting = false;
  bool get isExiting => _isExiting;
  bool _isRunning = true;
  bool get isRunning => _isRunning;
  bool _initialized = false;
  bool _isPaused = false;
  bool _showUsersOverlay = false;
  bool _isTopSettingsOpen = false;
  late final bool _showCatalogSelector;
  String? _lastAppliedConfigJson;
  String? _lastAppliedAppPath;
  bool _isPlayerCatalogOpen = false;
  List<CatalogExample> _playerCatalogExamples = [];
  String? _selectedPlayerCatalogExample;

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
    if (catalogExamplesBaseUrl == defaultCatalogExamplesBaseUrl) {
      if (kIsWeb) {
        final host = Uri.base.host.toLowerCase();
        if (host == 'localhost' || host == '127.0.0.1') {
          catalogExamplesBaseUrl = '${Uri.base.origin}/examples';
        }
      } else if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        final localCatalog = File('examples/catalog.json').absolute;
        if (localCatalog.existsSync()) {
          catalogExamplesBaseUrl = localCatalog.parent.uri.toString();
        }
      }
    }
    _showCatalogSelector = widget.content == null &&
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
      _gingacc.ccws.start(
        enableSsdp:
            !kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST'),
      );
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
      _gingacc.ccws.start(
        enableSsdp:
            !kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST'),
      );
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
      if (!resetIfMissing &&
          _lastAppliedConfigJson == configJson &&
          _lastAppliedAppPath == appPath) {
        if (appPath != null && _gingacc.config.appSrc != appPath) {
          _gingacc.config = _gingacc.config.copyWith(appSrc: appPath);
        }
        return;
      }
      try {
        final loadedCfg = await GingaConfig.fromJson(
          configJson,
          appPath,
          _gingacc,
        );
        _lastAppliedConfigJson = configJson;
        _lastAppliedAppPath = appPath;
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
      _lastAppliedConfigJson = null;
      _lastAppliedAppPath = appPath;
      _gingacc.config = GingaConfig(
        appSrc: appPath,
        startWithCCWS: true,
        enablePlayground: enablePlayground,
        breakpoints: currentBps,
      );
    } else if (appPath != null && _gingacc.config.appSrc != appPath) {
      _lastAppliedAppPath = appPath;
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

  Future<void> _addRemoteDeviceFromPlayground(String deviceClass) async {
    if (!kIsWeb &&
        !Platform.environment.containsKey('FLUTTER_TEST') &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      try {
        await _gingacc.ccws.start(enableSsdp: true);
        final proc = await Process.start(
          Platform.resolvedExecutable,
          ['--remote-device=$deviceClass'],
          workingDirectory: Directory.current.path,
        );
        _spawnedCompanionProcesses.add(proc);
        unawaited(
          proc.exitCode.then((_) {
            _spawnedCompanionProcesses.remove(proc);
          }),
        );
        return;
      } catch (e) {
        _logger.warning('Failed to spawn standalone remote device window: $e');
      }
    }

    final companionId = 'companion_${_nextCompanionSeq++}';
    final playerKey = GlobalKey<RemoteDevicePlayerWidgetState>();
    final supportedTypes = deviceClass == 'ncl-360-vr'
        ? const [
            'application/x-ncl360',
            'application/x-ncl-360',
          ]
        : const [
            'text/html',
            'application/x-vlibras-gloss',
            'application/ttml+xml',
            'text/srt',
            'audio/mpeg',
            'application/x-ginga-NCL',
            'text/plain',
          ];

    final editorFiles = _gingacc.config.enablePlayground
        ? _playgroundKey.currentState?.allFileContents
        : null;
    final virtualFiles = (widget.virtualFiles != null || editorFiles != null)
        ? <String, String>{
            ...?widget.virtualFiles,
            ...?editorFiles,
          }
        : null;

    final companionWidget = RemoteDevicePlayerWidget(
      key: playerKey,
      gingacc: _gingacc,
      deviceClass: deviceClass,
      supportedTypes: supportedTypes,
      virtualFiles: virtualFiles,
    );

    if (!mounted) return;
    setState(() {
      _companions.add(
        _PlaygroundCompanionInstance(
          id: companionId,
          label: 'Remote Device class_id=$deviceClass',
          deviceClass: deviceClass,
          playerKey: playerKey,
          widget: companionWidget,
        ),
      );
    });
  }

  void _stopCompanion(String companionId) {
    final idx = _companions.indexWhere((c) => c.id == companionId);
    if (idx == -1) return;
    setState(() {
      _companions.removeAt(idx);
    });
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
    if (_companions.isEmpty) {
      _stopServices();
    }
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
    setState(() {
      _isTopSettingsOpen = true;
    });
    _settingsMenuKey.currentState?.open();
  }

  void closeSettingsMenu() {
    setState(() {
      _isTopSettingsOpen = false;
    });
    _settingsMenuKey.currentState?.close();
  }

  void toggleSettingsMenu() {
    setState(() {
      _isTopSettingsOpen = !_isTopSettingsOpen;
    });
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

  void _stopSpawnedCompanionProcesses() {
    for (final proc in _spawnedCompanionProcesses) {
      try {
        proc.kill();
      } catch (_) {}
    }
    _spawnedCompanionProcesses.clear();
  }

  Future<void> _cleanup() async {
    if (_isExiting) return;
    setState(() {
      _isExiting = true;
      _isRunning = false;
      htmlApp = null;
      nclApp = null;
      mainAVWidget = null;
      _companions.clear();
    });
    _stopSpawnedCompanionProcesses();
    _gingacc.clearRemoteDevices();
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
    _stopSpawnedCompanionProcesses();
    _gingacc.clearRemoteDevices();
    _stopServices();
    super.dispose();
  }

  Future<void> _toggleTopBarCatalog() async {
    if (_gingacc.config.enablePlayground) {
      await _playgroundKey.currentState?.toggleCatalog();
      if (mounted) {
        setState(() {});
      }
      return;
    }
    if (_isPlayerCatalogOpen) {
      setState(() {
        _isPlayerCatalogOpen = false;
      });
      return;
    }
    if (_playerCatalogExamples.isEmpty) {
      final loaded = await loadCatalogExamples(gingacc: _gingacc);
      if (mounted && loaded.isNotEmpty) {
        _playerCatalogExamples = loaded;
      }
    }
    if (!mounted) return;
    setState(() {
      _isPlayerCatalogOpen = true;
    });
  }

  Future<void> _selectPlayerCatalogExample(String mainFile) async {
    setState(() {
      _isPlayerCatalogOpen = false;
      _selectedPlayerCatalogExample = mainFile;
    });
    final loaded = await loadExampleContent(mainFile, gingacc: _gingacc);
    if (loaded != null) {
      _mainAppContent = loaded;
    }
    final appPath = resolveCatalogExampleUrl(mainFile);
    await _applyPlaygroundConfig(
      appPath,
      resetIfMissing: true,
      fromCatalog: true,
    );
    if (!mounted) return;
    _restart();
  }

  Widget _buildTopBarButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color iconColor = const Color(0xFFCCCCCC),
    bool isActive = false,
  }) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF3C3C3C)
                : const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF858585)
                  : const Color(0xFF454545),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: enabled ? iconColor : const Color(0xFF666666),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? const Color(0xFFE5E5E5)
                      : const Color(0xFF666666),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopMenuBar(BuildContext context) {
    final editorState = _playgroundKey.currentState;
    final isPlayground = _gingacc.config.enablePlayground;
    final isCatalogOpen = isPlayground
        ? (editorState?.isCatalogOpen == true)
        : _isPlayerCatalogOpen;
    final isDebugging = editorState?.isDebugging == true;
    final isDebugPaused = editorState?.isPaused == true;
    final isHtmlApp = isPlayground
        ? (editorState != null
            ? editorState.isHtmlApplication
            : (_gingacc.config.appSrc?.toLowerCase().endsWith('.html') ==
                    true ||
                _gingacc.config.appSrc?.toLowerCase().endsWith('.htm') ==
                    true ||
                _gingacc.config.appSrc?.toLowerCase().endsWith('.xhtml') ==
                    true))
        : (_gingacc.config.appSrc?.toLowerCase().endsWith('.html') == true ||
            _gingacc.config.appSrc?.toLowerCase().endsWith('.htm') == true ||
            _gingacc.config.appSrc?.toLowerCase().endsWith('.xhtml') == true);
    final currentPaused =
        _isPaused || (_nclAppKey.currentState?.isPaused ?? false);
    final hasBreakpoints = editorState != null
        ? editorState.breakpoints.isNotEmpty
        : _gingacc.config.breakpoints.isNotEmpty;
    final canRun = !_isRunning && !isDebugging;
    final canDebug = isPlayground &&
        !isHtmlApp &&
        hasBreakpoints &&
        !_isRunning &&
        !isDebugging;
    final canStop = _isRunning || isDebugging;

    return Container(
      key: const Key('playground_branding_banner'),
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2D2D2D), width: 1),
        ),
      ),
      child: Row(
        key: const Key('floating_control_menu'),
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/favicon.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'packages/playground/assets/favicon.png',
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error2, stackTrace2) =>
                          const Icon(
                        Icons.play_circle_filled,
                        size: 18,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPlayground ? 'GingaPlayground' : 'Ginga',
                    key: const Key('playground_branding_title'),
                    style: const TextStyle(
                      color: Color(0xFFCCCCCC),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (_showCatalogSelector) ...[
                    const SizedBox(width: 14),
                    _buildTopBarButton(
                      key: const Key('catalog_select'),
                      icon: Icons.grid_view_rounded,
                      label: 'Catalog',
                      isActive: isCatalogOpen,
                      onPressed: _toggleTopBarCatalog,
                    ),
                  ],
                  const SizedBox(width: 12),
                  IconButton(
                    key: const Key('monaco_run_button'),
                    tooltip: 'Start',
                    icon: const Icon(Icons.play_arrow, size: 18),
                    color: const Color(0xFF4CAF50),
                    disabledColor: const Color(0xFF555555),
                    onPressed: canRun
                        ? () {
                            final st = _playgroundKey.currentState;
                            if (st != null) {
                              st.run();
                            } else {
                              _runFromPlayground();
                            }
                          }
                        : null,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 26, minHeight: 26),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(26, 26),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  if (isPlayground)
                    IconButton(
                      key: const Key('monaco_debug_start_button'),
                      tooltip: isHtmlApp
                          ? 'Debugging not supported for HTML'
                          : (!hasBreakpoints
                              ? 'Add a breakpoint to start debugging'
                              : 'Start Debugging'),
                      icon: const Icon(Icons.bug_report, size: 16),
                      color: const Color(0xFF007ACC),
                      disabledColor: const Color(0xFF555555),
                      onPressed: canDebug
                          ? () {
                              final st = _playgroundKey.currentState;
                              if (st != null) {
                                st.startDebugSession();
                              } else {
                                _runFromPlayground();
                              }
                            }
                          : null,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(26, 26),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  if (isDebugging) ...[
                    const SizedBox(width: 6),
                    Container(
                      key: const Key('monaco_debug_controls_box'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF454545),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: const Key('monaco_debug_continue_button'),
                            tooltip: 'Continue',
                            icon: const Icon(Icons.fast_forward, size: 16),
                            color: const Color(0xFF75BEFF),
                            disabledColor: const Color(0xFF666666),
                            onPressed: isDebugPaused
                                ? () {
                                    _playgroundKey.currentState
                                        ?.continueExecution();
                                  }
                                : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 24, minHeight: 24),
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(24, 24),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          Container(
                            height: 14,
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            color: const Color(0xFF454545),
                          ),
                          IconButton(
                            key: const Key('monaco_stop_button'),
                            tooltip: 'Stop',
                            icon: const Icon(Icons.stop, size: 16),
                            color: Colors.redAccent,
                            disabledColor: const Color(0xFF666666),
                            onPressed: canStop
                                ? () {
                                    final st = _playgroundKey.currentState;
                                    if (st != null) {
                                      st.stopSession();
                                    } else {
                                      _stopFromPlayground();
                                    }
                                  }
                                : null,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 24, minHeight: 24),
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(24, 24),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (canStop) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      key: const Key('monaco_stop_button'),
                      tooltip: 'Stop',
                      icon: const Icon(Icons.stop, size: 18),
                      color: Colors.redAccent,
                      disabledColor: const Color(0xFF555555),
                      onPressed: () {
                        final st = _playgroundKey.currentState;
                        if (st != null) {
                          st.stopSession();
                        } else {
                          _stopFromPlayground();
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(26, 26),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  if (_isRunning) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      key: const Key('floating_pause_button'),
                      tooltip: currentPaused ? 'Resume' : 'Pause',
                      icon: Icon(
                        currentPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        size: 18,
                      ),
                      color: currentPaused
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFFB74D),
                      onPressed: togglePause,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(26, 26),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: const Key('floating_restart_button'),
                      tooltip: 'Restart',
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      color: const Color(0xFF64B5F6),
                      onPressed: _restart,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(26, 26),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: const Key('floating_forward_2s_button'),
                      tooltip: 'Forward +2s',
                      icon: const Icon(Icons.fast_forward_rounded, size: 18),
                      color: const Color(0xFFCCCCCC),
                      onPressed: forward2s,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(26, 26),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isTopSettingsOpen) ...[
                _buildTopBarButton(
                  key: const Key('floating_users_button'),
                  icon: Icons.people,
                  label: 'Users',
                  isActive: _showUsersOverlay,
                  onPressed: () {
                    if (_showUsersOverlay) {
                      closeUsersOverlay();
                    } else {
                      openUsersOverlay();
                    }
                  },
                ),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  key: const Key('monaco_add_remote_device_button'),
                  tooltip: 'Add Remote Device',
                  padding: EdgeInsets.zero,
                  color: const Color(0xFF252526),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: const BorderSide(
                      color: Color(0xFF454545),
                      width: 1,
                    ),
                  ),
                  onSelected: _addRemoteDeviceFromPlayground,
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      key: Key('add_remote_device_ncl_360_vr'),
                      value: 'ncl-360-vr',
                      child: Text(
                        'Remote Device: ncl-360-vr (NCL360)',
                        style: TextStyle(
                          color: Color(0xFFD4D4D4),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    PopupMenuItem<String>(
                      key: Key('add_remote_device_accessibility'),
                      value: 'accessibility',
                      child: Text(
                        'Remote Device: accessibility (HTML5)',
                        style: TextStyle(
                          color: Color(0xFFD4D4D4),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF454545),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.devices,
                          size: 14,
                          color: Color(0xFFCCCCCC),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Add Remote Device',
                          style: TextStyle(
                            color: Color(0xFFE5E5E5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
                key: const Key('floating_menu_toggle_button'),
                tooltip: 'Settings',
                icon: Icon(
                  _isTopSettingsOpen ? Icons.close : Icons.settings,
                  size: 18,
                ),
                color: _isTopSettingsOpen
                    ? Colors.white
                    : const Color(0xFFCCCCCC),
                onPressed: toggleSettingsMenu,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(26, 26),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final usersOverlay = _showUsersOverlay
        ? UsersMenu(
            users: _gingacc.config.users,
            onClose: closeUsersOverlay,
            onUserSelected: (_) => closeUsersOverlay(),
            dispatchCurrentUserUpdate: (name, value) {
              _gingacc.config.systemVariables[name] = value;
              _nclAppKey.currentState?.nclDocument?.dispatchSettingsUpdate(
                  name, value,
                  userId: 'currentUser');
            },
          )
        : null;

    if (!_isRunning) {
      return Container(
        key: const Key('no_running_app_placeholder'),
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Center(
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
            if (usersOverlay != null) usersOverlay,
          ],
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
          if (usersOverlay != null) usersOverlay,
        ],
      ),
    );
  }

  Widget _buildCompanionTile(_PlaygroundCompanionInstance companion) {
    return Container(
      key: Key('playground_companion_tile_${companion.id}'),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: const Color(0xFF2D2D2D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0xFF252526),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    companion.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFCCCCCC),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: Key('playground_companion_restart_${companion.id}'),
                  tooltip: 'Restart Companion',
                  icon: const Icon(Icons.restart_alt_rounded, size: 14),
                  color: const Color(0xFF9E9E9E),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 22, minHeight: 22),
                  onPressed: () => companion.playerKey.currentState?.restart(),
                ),
                const SizedBox(width: 2),
                IconButton(
                  key: Key('playground_companion_close_${companion.id}'),
                  tooltip: 'Stop Companion',
                  icon: const Icon(Icons.close, size: 14),
                  color: const Color(0xFF9E9E9E),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 22, minHeight: 22),
                  onPressed: () => _stopCompanion(companion.id),
                ),
              ],
            ),
          ),
          Expanded(child: companion.widget),
        ],
      ),
    );
  }

  Widget _buildPlayerArea(BuildContext context) {
    if (_companions.isEmpty) {
      return _buildPlayer(context);
    }
    return Column(
      key: const Key('playground_multidevice_column'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: KeyedSubtree(
            key: const Key('playground_main_player_pane'),
            child: _buildPlayer(context),
          ),
        ),
        Container(
          height: 2,
          color: const Color(0xFF2D2D2D),
        ),
        Expanded(
          flex: 2,
          child: Container(
            key: const Key('playground_companions_pane'),
            color: const Color(0xFF1E1E1E),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _companions
                  .map((c) => Expanded(child: _buildCompanionTile(c)))
                  .toList(),
            ),
          ),
        ),
      ],
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isOverlay) _buildTopMenuBar(context),
                    Expanded(
                      child: _gingacc.config.enablePlayground
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
                                        showTopBar: false,
                                        content: _mainAppContent ?? '',
                                        filePath: _gingacc.config.appSrc,
                                        gingacc: _gingacc,
                                        isRunning: _isRunning,
                                        showCatalogSelector:
                                            _showCatalogSelector,
                                        onCatalogExampleSelected:
                                            (selectedFile) async {
                                          final appPath =
                                              resolveCatalogExampleUrl(
                                                  selectedFile);
                                          await _applyPlaygroundConfig(
                                            appPath,
                                            resetIfMissing: true,
                                            fromCatalog: true,
                                          );
                                        },
                                        onCatalogOpenChanged: (_) {
                                          setState(() {});
                                        },
                                        onContentChanged: (newText) {
                                          _mainAppContent = newText;
                                          if (mounted) {
                                            setState(() {});
                                          }
                                        },
                                        onRun: _runFromPlayground,
                                        onAddRemoteDevice:
                                            _addRemoteDeviceFromPlayground,
                                        onStop: _stopFromPlayground,
                                        onDebug: _runFromPlayground,
                                        onContinue: () {
                                          resume();
                                        },
                                        onReload: _runFromPlayground,
                                        initialBreakpoints:
                                            _gingacc.config.breakpoints,
                                        onBreakpointsChanged: (newBps) {
                                          setBreakpoints(newBps);
                                          if (mounted) {
                                            setState(() {});
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                if (_playgroundKey
                                        .currentState?.isCatalogOpen !=
                                    true)
                                  Expanded(
                                    flex: 1,
                                    child: RepaintBoundary(
                                      child: _buildPlayerArea(context),
                                    ),
                                  ),
                              ],
                            )
                          : (_isPlayerCatalogOpen
                              ? CatalogGridView(
                                  key: const Key('catalog_grid_dialog'),
                                  examples: _playerCatalogExamples,
                                  selectedExample:
                                      _selectedPlayerCatalogExample,
                                  onSelected: _selectPlayerCatalogExample,
                                  onClose: () {
                                    setState(() {
                                      _isPlayerCatalogOpen = false;
                                    });
                                  },
                                )
                              : _buildPlayerArea(context)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
