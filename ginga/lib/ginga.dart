import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'ccws/ccws.dart';
import 'ginga_content.dart';
import 'html/html_app.dart' as html;
import 'main_av.dart';
import 'ncl/ncl_app.dart' as ncl;
import 'web_utils_stub.dart' if (dart.library.html) 'web_utils_web.dart';

final _logger = Logger('ginga');

const DEFAULT_VIDEO =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

class GingaConfig {
  final String? appSrc;
  final String mainAvSrc;
  final bool enableCCWS;
  final bool enableMainAv;
  final String? usersDataSrc;
  final ContentLoader contentLoader;

  const GingaConfig([
    this.appSrc,
    this.enableCCWS = true,
    this.enableMainAv = true,
    this.usersDataSrc,
    this.mainAvSrc = DEFAULT_VIDEO,
    ContentLoader? contentLoader,
  ]) : contentLoader = contentLoader ?? const FileContentLoader();

  bool get isEmpty => appSrc == null && !enableMainAv;

  @override
  String toString() {
    return 'GingaConfig(appSrc: $appSrc, mainAvSrc: $mainAvSrc, enableCCWS: $enableCCWS, enableMainAv: $enableMainAv, usersDataSrc: $usersDataSrc)';
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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ccws = CCWS();
    mainAVController = MainAVController()
      ..setMainAvUri(widget.config.mainAvSrc);
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
    HardwareKeyboard.instance.addHandler(_handleKeyPress);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.config.contentLoader is GingaContentLoader) {
      (widget.config.contentLoader as GingaContentLoader)
          .setBuildContext(context);
    }
    if (!_initialized) {
      _initialized = true;
      final appSrc = widget.config.appSrc;
      if (appSrc != null) {
        _logger.info('Starting application $appSrc');
        if (appSrc.toLowerCase().endsWith('.html')) {
          htmlApp = html.HTMLApp(
            src: appSrc,
            ccws: _ccws,
            config: widget.config,
          );
        } else {
          nclApp = ncl.NCLApp(
            src: appSrc,
            mainAVController: mainAVController,
            config: widget.config,
          );
        }
      }
    }
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
