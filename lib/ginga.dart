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
    if (_gingacc.config.startWithMainAv) {
      mainAVWidget = MainAVWidget(
        key: _mainAvKey,
        src: _gingacc.config.mainAvSrc,
      );
    }

    final isConfigEmpty =
        _gingacc.config.appSrc == null && !_gingacc.config.startWithMainAv;
    if (isConfigEmpty && !kIsWeb) {
      _logger.severe('both APP and CONFIG are empty, exiting');
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
      } else if (lk == LogicalKeyboardKey.f1 ||
          lk == LogicalKeyboardKey.keyR) {
        nclKey = 'RED';
      } else if (lk == LogicalKeyboardKey.f2 ||
          lk == LogicalKeyboardKey.keyG) {
        nclKey = 'GREEN';
      } else if (lk == LogicalKeyboardKey.f3 ||
          lk == LogicalKeyboardKey.keyY) {
        nclKey = 'YELLOW';
      } else if (lk == LogicalKeyboardKey.f4 ||
          lk == LogicalKeyboardKey.keyB) {
        nclKey = 'BLUE';
      } else if (lk == LogicalKeyboardKey.f5 ||
          lk == LogicalKeyboardKey.keyI) {
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
