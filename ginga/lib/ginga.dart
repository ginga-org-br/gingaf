import 'dart:io';
import 'dart:convert';

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

const DEFAULT_VIDEO =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

class GingaConfig {
  final String? appUri;
  final String? mainAvUri;
  final bool enableCCWS;
  final bool enableMainAv;
  final String? usersDataJson;

  GingaConfig([
    String? manualPath,
    bool manualCCWS = true,
    String? manualVideo,
    bool manualEnableMainAv = true,
    this.usersDataJson,
  ])  : appUri = uriResolver(manualPath),
         mainAvUri = (manualVideo == 'false') ? null : uriResolver(manualVideo ?? DEFAULT_VIDEO),
         enableCCWS = manualCCWS,
         enableMainAv = (manualVideo == 'false') ? false : manualEnableMainAv;

  static String? uriResolver(dynamic input) {
    if (input is Uri) {
      final path = input.isScheme('file') ? input.toFilePath() : input.path;
      if (kIsWeb) {
        try {
          final mockJson = getSessionStorageItem('GINGA_PLAYGROUND_FILES');
          if (mockJson != null) {
            final mockFiles = jsonDecode(mockJson);
            final fileName = input.pathSegments.last;
            if (mockFiles.containsKey(fileName)) {
              return mockFiles[fileName];
            }
          }
        } catch (_) {}
      }
      if (!kIsWeb) {
        final file = File(path);
        if (file.existsSync()) {
          return file.readAsStringSync();
        }
        final fileName = path.contains('/') ? path.substring(path.lastIndexOf('/') + 1) : path;
        final localFile = File(fileName);
        if (localFile.existsSync()) {
          return localFile.readAsStringSync();
        }
      }
      return null;
    } else if (input is String?) {
      String? path = input;

      if (path == null) {
        if (kIsWeb) {
          path = Uri.base.queryParameters['APP'];
          if (path == null) {
            path = getSessionStorageItem('GINGA_PLAYGROUND_MAIN');
          }
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
      if (!lower.endsWith('.ncl') && !lower.endsWith('.html') && !lower.endsWith('.mp4') && !lower.endsWith('.mkv') && !lower.endsWith('.avi')) {
        _logger.severe('\nUnsupported format: $path');
        return null;
      }

      return path;
    }
    return null;
  }

  bool get isEmpty => appUri == null && mainAvUri == null;

  @override
  String toString() {
    return 'GingaConfig(appUri: $appUri, mainAvUri: $mainAvUri, enableCCWS: $enableCCWS, enableMainAv: $enableMainAv, usersDataJson: $usersDataJson)';
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
    mainAVController = MainAVController()
      ..setMainAvUri(widget.config.mainAvUri);
    if (widget.config.enableMainAv) {
      mainAVWidget = MainAVWidget(controller: mainAVController);
    }

    if (widget.config.isEmpty && !kIsWeb) {
      _logger.severe('Both APP and MAINAV are disabled or empty, exiting.');
      _cleanup();
      return;
    }

    if (widget.config.enableCCWS) {
      _logger.info('Starting CCWS');
      _ccws.start();
    }

    final path = widget.config.appUri;
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
          usersDataJson: widget.config.usersDataJson,
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
