import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'package:ccws/ccws.dart';
import 'ginga_src_resolver.dart';
import 'html/html_app.dart' as html;
import 'main_av.dart';
import 'ncl/ncl_app.dart' as ncl;
import 'web_utils_stub.dart' if (dart.library.html) 'web_utils_web.dart';

final _logger = Logger('ginga');

class GingaConfig {
  final String? appSrc;
  final String? mainAvSrc;
  final bool enableCCWS;
  final String? usersDataSrc;
  final SrcResolver contentLoader;

  const GingaConfig([
    this.appSrc,
    this.enableCCWS = true,
    this.usersDataSrc,
    this.mainAvSrc,
    SrcResolver? contentLoader,
  ]) : contentLoader = contentLoader ?? const FileSrcResolver();

  bool get isEmpty =>
      appSrc == null && (mainAvSrc == null || mainAvSrc!.isEmpty);

  @override
  String toString() {
    return 'GingaConfig(appSrc: $appSrc, mainAvSrc: $mainAvSrc, enableCCWS: $enableCCWS, usersDataSrc: $usersDataSrc)';
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
  MainAVController? mainAVController;
  Widget? mainAVWidget;
  Widget? htmlApp;
  Widget? nclApp;
  bool _isExiting = false;
  bool _initialized = false;

  final GlobalKey<ncl.NCLAppState> _nclAppKey = GlobalKey<ncl.NCLAppState>();

  bool get _isSbtvdActiveInNcl {
    final state = _nclAppKey.currentState;
    return state?.hasSbtvdMedia ?? false;
  }

  @override
  void initState() {
    super.initState();
    _ccws = CCWS();
    final appSrc = widget.config.appSrc;
    if (widget.config.mainAvSrc != null &&
        widget.config.mainAvSrc!.isNotEmpty) {
      final controller = MainAVController()
        ..setMainAvUri(widget.config.mainAvSrc);
      mainAVController = controller;
      if (appSrc == null || appSrc.isEmpty) {
        mainAVWidget = MainAVWidget(controller: controller);
      }
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
    if (widget.config.contentLoader is GingaSrcResolver) {
      (widget.config.contentLoader as GingaSrcResolver)
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
            key: _nclAppKey,
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
    mainAVController?.stop();
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
