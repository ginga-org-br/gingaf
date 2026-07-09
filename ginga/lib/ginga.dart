import 'dart:io';

import 'web_utils_stub.dart' if (dart.library.html) 'web_utils_web.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'ccws/ccws.dart';
import 'html/html_app.dart' as html;
import 'main_av.dart';
import 'ncl/ncl_app.dart' as ncl;

final _logger = Logger('ginga');

class GingaConfig {
  final String? appPath;
  final String? mainAvUri;
  final bool enableCCWS;

  GingaConfig([String? manualPath, bool? manualCCWS, String? manualVideo])
      : appPath = _resolve(manualPath),
        mainAvUri = manualVideo ?? _resolveVideo(),
        enableCCWS = manualCCWS ??
            const bool.fromEnvironment('CCWS', defaultValue: true);

  static String? _resolveVideo() {
    String? video = const String.fromEnvironment('MAINAV').isNotEmpty
        ? const String.fromEnvironment('MAINAV')
        : null;
    if (video == null && !kIsWeb) {
      video = Platform.environment['MAINAV'];
    }
    return video ??
        'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
  }

  static String? _resolve(String? manualPath) {
    String? path = manualPath;

    if (path == null) {
      path = const String.fromEnvironment('APP').isNotEmpty
          ? const String.fromEnvironment('APP')
          : null;

      if (path == null && kIsWeb) {
        path = Uri.base.queryParameters['APP'];
        if (path == null) {
          path = getSessionStorageItem('GINGA_PLAYGROUND_MAIN');
        }
      }

      if (path == null && !kIsWeb) {
        path = Platform.environment['APP'];
      }
      if (path == null && !kIsWeb) {
        final file = File('.ginga_app');
        if (file.existsSync()) {
          path = file.readAsStringSync().trim();
        }
      }
    }

    if (path == null || path.isEmpty) return null;

    final lower = path.toLowerCase();
    if (!lower.endsWith('.ncl') && !lower.endsWith('.html')) {
      _logger.severe('\nUnsupported format: $path');
      return null;
    }

    return path;
  }

  bool get isEmpty => appPath == null && mainAvUri == null;

  @override
  String toString() {
    return 'GingaConfig(appPath: $appPath, mainAvUri: $mainAvUri, enableCCWS: $enableCCWS)';
  }
}

class Ginga extends StatefulWidget {
  final GingaConfig config;
  const Ginga({super.key, required this.config});

  @override
  State<Ginga> createState() => _GingaState();
}

class _GingaState extends State<Ginga> {
  late final CCWS _ccws;
  late final MainAVController mainAVController;
  Widget? mainAVWidget;
  Widget? htmlApp;
  Widget? nclApp;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _ccws = CCWS();
    if (widget.config.enableCCWS) {
      _logger.info('Starting CCWS');
      _ccws.start();
    }

    mainAVController = MainAVController()
      ..setMainAvUri(widget.config.mainAvUri);
    mainAVWidget = MainAVWidget(controller: mainAVController);

    final path = widget.config.appPath;
    if (path != null) {
      _logger.info('Starting application $path');
      if (path.toLowerCase().endsWith('.html')) {
        htmlApp = html.HTMLApp(
          uri: path,
          ccws: _ccws,
        );
      } else {
        nclApp = ncl.NCLApp(
          uri: path,
          mainAVController: mainAVController,
        );
      }
    }
    HardwareKeyboard.instance.addHandler(_handleKeyPress);
  }

  bool _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _logger.info('Captured ESC in Window, stopping app and mainAV.');
        _cleanup();
        return true;
      }
    }
    return false;
  }

  void _stopServices() {
    mainAVController.stop();
    if (widget.config.enableCCWS) {
      _ccws.stop();
    }
  }

  Future<void> _cleanup() async {
    if (_isExiting) return;
    setState(() {
      _isExiting = true;
      htmlApp = null;
      nclApp = null;
      mainAVWidget = null;
    });
    _stopServices();
    if (!kIsWeb) {
      Future.delayed(const Duration(milliseconds: 200), () => exit(0));
    } else {
      notifyParentAppExited();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyPress);
    _stopServices();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'gingaf',
      themeMode: ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[200],
      ),
      home: NotificationListener<ncl.NCLAppExitNotification>(
        onNotification: (notification) {
          _logger.info(
              'Received NCLAppExitNotification. Cleaning up and exiting.');
          _cleanup();
          return true;
        },
        child: Scaffold(
          body: _isExiting
              ? const SizedBox.shrink()
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (mainAVWidget != null) mainAVWidget!,
                    if (htmlApp != null) htmlApp!,
                    if (nclApp != null) nclApp!,
                  ],
                ),
        ),
      ),
    );
  }
}
