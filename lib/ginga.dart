import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gingacc/gingacc.dart';
import 'package:logging/logging.dart';
import 'package:nclui/html.dart' as html;
import 'package:nclui/main_av.dart';
import 'package:nclui/ncl.dart' as ncl;

import 'web_utils_stub.dart' if (dart.library.js_interop) 'web_utils_web.dart';

final _logger = Logger('ginga');

class Ginga extends StatefulWidget {
  final GingaCC? gingacc;

  const Ginga({
    super.key,
    this.gingacc,
  });

  @override
  State<Ginga> createState() => _GingaState();
}

class _GingaState extends State<Ginga> {
  late final GingaCC _gingacc;
  Widget? mainAVWidget;
  Widget? htmlApp;
  Widget? nclApp;
  bool _isExiting = false;
  bool _initialized = false;

  final GlobalKey<ncl.NclWidgetState> _nclAppKey =
      GlobalKey<ncl.NclWidgetState>();
  final GlobalKey<MainAVWidgetState> _mainAvKey =
      GlobalKey<MainAVWidgetState>();

  @override
  void initState() {
    super.initState();
    _gingacc = widget.gingacc ?? GingaCC();
    if (_gingacc.config.enableMainAv) {
      mainAVWidget = MainAVWidget(
        key: _mainAvKey,
        src: _gingacc.config.mainAvSrc,
      );
    }

    final isConfigEmpty =
        _gingacc.config.appSrc == null && !_gingacc.config.enableMainAv;
    if (isConfigEmpty && !kIsWeb) {
      _logger.severe('Both APP and MAINAV are disabled or empty, exiting.');
      _cleanup();
      return;
    }

    _gingacc.start();
    HardwareKeyboard.instance.addHandler(_handleKeyPress);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final appSrc = _gingacc.config.appSrc;
      if (appSrc != null) {
        if (appSrc.toLowerCase().endsWith('.html')) {
          htmlApp = html.HtmlWidget(
            src: appSrc,
            gingacc: _gingacc,
          );
        } else {
          nclApp = ncl.NclWidget(
            key: _nclAppKey,
            src: appSrc,
            mainAvKey: _mainAvKey,
            gingacc: _gingacc,
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
    _gingacc.stop();
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
      home: NotificationListener<ncl.NclWidgetExitNotification>(
        onNotification: (notification) {
          _logger.info(
              'Received NclWidgetExitNotification. Cleaning up and exiting.');
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
