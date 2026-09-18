import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:ncldoc/ncl_document.dart';

import 'av.dart';
import 'base_widget.dart';
import 'html.dart';
import 'image.dart';
import 'lua.dart';
import 'main_av.dart';
import 'text.dart';

export 'av.dart';
export 'base_widget.dart';
export 'html.dart';
export 'image.dart';
export 'lua.dart';
export 'main_av.dart';
export 'text.dart';

final _logger = Logger('ginga-ncl');

class NclWidgetExitNotification extends Notification {}

class NclWidget extends BaseWidget {
  final GlobalKey<MainAVWidgetState>? mainAvKey;
  final VoidCallback? onRequestMainAv;
  final Rectangle<double>? bounds;

  const NclWidget({
    super.key,
    required super.src,
    super.media,
    super.document,
    super.gingacc,
    this.mainAvKey,
    this.onRequestMainAv,
    this.bounds,
  });

  static NclWidgetState of(BuildContext context) {
    final state = maybeOf(context);
    if (state == null) {
      throw FlutterError(
          'NclWidget.of() called with a context that does not contain an NclWidget.');
    }
    return state;
  }

  static NclWidgetState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_NclInheritedWidget>()
        ?.state;
  }

  static Widget? createMediaWidget({
    Key? key,
    required Media media,
    NclDocument? document,
  }) {
    final mimeType = media.mimeType;
    var src = media.uri.isNotEmpty ? media.uri : (media.src ?? '');
    if (src.startsWith('sbtvd://')) {
      return null;
    }
    if (src.endsWith('.ncl') ||
        mimeType == 'application/x-ncl-NCL' ||
        mimeType == 'application/x-ncl-ncl') {
      return NclWidget(
        key: key,
        src: src,
        media: media,
        document: document,
        gingacc: document?.gingacc,
      );
    }
    if (mimeType.startsWith('video/') ||
        mimeType.startsWith('audio/') ||
        mimeType.contains('video') ||
        mimeType.contains('audio')) {
      return AVWidget(
        key: key,
        src: src,
        media: media,
        document: document,
      );
    }
    if (media is NCLua) {
      return LuaWidget(
        key: key,
        src: src,
        media: media,
        document: document,
      );
    }
    switch (mimeType) {
      case 'application/x-ncl-NCLua':
      case 'application/x-ginga-NCLua':
        return LuaWidget(
          key: key,
          src: src,
          media: media,
          document: document,
        );
      case 'text/plain':
        return TextWidget(
          key: key,
          src: src,
          media: media,
          document: document,
        );
      case 'text/html':
        return HtmlWidget(
          key: key,
          src: src,
          media: media,
          document: document,
        );
      case 'image/png':
      case 'image/jpeg':
      case 'image/gif':
      case 'image/webp':
      case 'image/bmp':
      case 'image/heic':
      case 'application/x-ginga-time':
      case 'application/x-ncl-time':
        return ImageWidget(
          key: key,
          src: src,
          media: media,
          document: document,
        );
      default:
        return null;
    }
  }

  @override
  State<NclWidget> createState() => NclWidgetState();
}

class NclWidgetState extends MediaState<NclWidget> {
  NclDocument? nclDocument;
  final Map<String, GlobalKey<MediaState>> _mediaStateKeys = {};
  final Map<String, Widget> _cachedWidgets = {};
  Timer? _ticker;
  String errorMsg = "";
  bool _loading = false;
  bool _isPaused = false;
  bool get isPaused => _isPaused;

  @override
  void pause() {
    if (_isPaused) return;
    _isPaused = true;
    widget.mainAvKey?.currentState?.controller?.pause();
    for (final key in _mediaStateKeys.values) {
      key.currentState?.pause();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    widget.mainAvKey?.currentState?.controller?.play();
    for (final key in _mediaStateKeys.values) {
      key.currentState?.resume();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void togglePause() {
    if (_isPaused) {
      resume();
    } else {
      pause();
    }
  }

  Rectangle<double> get bounds {
    if (widget.bounds != null) return widget.bounds!;
    if (rect != Rect.zero) {
      return Rectangle<double>(0.0, 0.0, rect.width, rect.height);
    }
    final size = MediaQuery.maybeOf(context)?.size;
    if (size != null && size != Size.zero) {
      return Rectangle<double>(0.0, 0.0, size.width, size.height);
    }
    return widget.gingacc?.config.graphsPlaneBounds ??
        nclDocument?.config.graphsPlaneBounds ??
        const Rectangle<double>(0.0, 0.0, 720.0, 480.0);
  }

  bool get hasSbtvdMedia {
    if (nclDocument == null) return false;
    final activeMedia = nclDocument!.getActiveMedia();
    return activeMedia.any((m) {
      final src = m.uri.isNotEmpty ? m.uri : (m.src ?? '');
      return src.startsWith('sbtvd://');
    });
  }

  final Map<String, String> persistentVars = {};

  bool _syncActiveMedia(List<Media> activeMedia) {
    bool changed = false;
    final currentIds = activeMedia.map((m) => m.id ?? '').toSet();

    final allTrackedIds = {..._cachedWidgets.keys, ..._mediaStateKeys.keys};
    final toRemove =
        allTrackedIds.where((id) => !currentIds.contains(id)).toList();
    for (var id in toRemove) {
      if (_cachedWidgets.containsKey(id)) {
        _cachedWidgets.remove(id);
        changed = true;
      }
      if (widget.mainAvKey != null && _mediaStateKeys[id] == widget.mainAvKey) {
        widget.mainAvKey!.currentState?.clearMedia();
      }
      _mediaStateKeys.remove(id);
    }

    for (var media in activeMedia) {
      final id = media.id ?? '';
      final isSbtvd = media.src?.startsWith('sbtvd://') == true ||
          media.uri.startsWith('sbtvd://');
      if (isSbtvd && widget.mainAvKey != null) {
        if (widget.mainAvKey!.currentState == null) {
          widget.onRequestMainAv?.call();
        }
        if (!_mediaStateKeys.containsKey(id)) {
          _mediaStateKeys[id] = widget.mainAvKey!;
          if (widget.mainAvKey!.currentState != null) {
            widget.mainAvKey!.currentState?.setMedia(media, nclDocument);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.mainAvKey?.currentState?.setMedia(media, nclDocument);
            widget.mainAvKey?.currentState?.syncProperties();
          });
        }
        continue;
      }
      if (!_cachedWidgets.containsKey(id)) {
        final key = GlobalKey<MediaState>();
        final mediaWidget = NclWidget.createMediaWidget(
          key: key,
          media: media,
          document: nclDocument,
        );
        if (mediaWidget != null) {
          _mediaStateKeys[id] = key;
          _cachedWidgets[id] = mediaWidget;
          changed = true;
          if (_isPaused) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              key.currentState?.pause();
            });
          }
        }
      }
    }
    return changed;
  }

  @override
  void initState() {
    super.initState();
    _logger.info("Starting NCL application: ${widget.src}");
    _startApplication();
  }

  Future<void> _startApplication() async {
    if (_loading) return;
    _loading = true;
    await Future.microtask(() {});
    try {
      if (mounted) {
        setState(() {});
      } else {
        return;
      }
      final gingacc = widget.gingacc ?? GingaCC();
      final doc = await NclDocument.fromSrc(
        widget.src,
        gingacc: gingacc,
      );
      if (!mounted) return;

      nclDocument = doc;
      doc.onStateChanged = () {
        if (mounted) {
          tick(0);
        }
      };
      doc.start();
      _syncActiveMedia(doc.getActiveMedia());

      if (mounted) {
        setState(() {
          errorMsg = "";
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          DateTime lastTick = DateTime.now();
          _ticker?.cancel();
          _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
            if (!mounted || _ticker == null) {
              timer.cancel();
              return;
            }
            if (_isPaused) {
              lastTick = DateTime.now();
              return;
            }
            final now = DateTime.now();
            final deltaMs = now.difference(lastTick).inMilliseconds;
            lastTick = now;
            tick(deltaMs);

            if (nclDocument != null && !nclDocument!.isPlaying) {
              _ticker?.cancel();
              _ticker = null;
              nclDocument = null;
              if (mounted) {
                NclWidgetExitNotification().dispatch(context);
              }
            }
          });
        });
      }
    } catch (e, stacktrace) {
      _logger.severe("Error: $e\n$stacktrace");
      nclDocument = null;
      _cachedWidgets.clear();
      _mediaStateKeys.clear();
      if (mounted) {
        setState(() {
          errorMsg = "Error: $e";
        });
      }
    } finally {
      _loading = false;
    }
  }

  String? _previousFocusId;

  void tick(int ms) {
    if (nclDocument != null) {
      final changedMedia = nclDocument!.tick(ms);
      for (var media in changedMedia) {
        _mediaStateKeys[media.id ?? '']?.currentState?.syncProperties();
      }

      final currentFocus = nclDocument!.currentFocusNodeId;
      bool focusChanged = false;
      if (currentFocus != _previousFocusId) {
        focusChanged = true;
        if (_previousFocusId != null) {
          _mediaStateKeys[_previousFocusId!]?.currentState?.syncProperties();
        }
        if (currentFocus != null) {
          _mediaStateKeys[currentFocus]?.currentState?.syncProperties();
        }
        _previousFocusId = currentFocus;
      }

      final activeChanged = _syncActiveMedia(nclDocument!.getActiveMedia());
      if (mounted && (activeChanged || focusChanged || ms == 0)) {
        setState(() {});
      }
    }
  }

  void handleKeyPress(String keyCode) {
    if (nclDocument != null) {
      final handled = nclDocument!.handleKey(keyCode);
      if (handled) {
        tick(0);
      }
    }
  }

  @override
  void dispose() {
    _logger.info("Stopping NCL application: ${widget.src}");
    _ticker?.cancel();
    _ticker = null;
    widget.mainAvKey?.currentState?.clearMedia();
    final doc = nclDocument;
    nclDocument = null;
    try {
      doc?.stop();
    } catch (e) {
      _logger.warning("Error stopping doc in dispose: $e");
    }
    super.dispose();
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    final Widget content;
    if (errorMsg.isNotEmpty) {
      content = Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              errorMsg,
              style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else if (nclDocument == null && _cachedWidgets.isEmpty) {
      content = Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: errorMsg.isNotEmpty
              ? Text(errorMsg, style: const TextStyle(color: Colors.red))
              : const CircularProgressIndicator(),
        ),
      );
    } else {
      final activeMedia = List<Media>.from(nclDocument?.getActiveMedia() ?? []);
      activeMedia.sort((a, b) {
        int getZIndex(Media media) {
          final zIndexProp = media
              .getProperties()
              .where((p) => p.name == 'zIndex' || p.name == 'zOrder')
              .firstOrNull;
          if (zIndexProp != null && zIndexProp.value != null) {
            return int.tryParse(zIndexProp.value!) ?? 0;
          }
          final resolvedZ = media.rawAttributes['resolvedZIndex'];
          if (resolvedZ != null) {
            return int.tryParse(resolvedZ) ?? 0;
          }
          return 0;
        }

        return getZIndex(a).compareTo(getZIndex(b));
      });

      final List<Widget> children = [];
      for (var media in activeMedia) {
        final widget = _cachedWidgets[media.id ?? ''];
        if (widget != null) {
          children.add(widget);
        }
      }

      content = Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          key: const Key('ncl_app_stack'),
          fit: StackFit.expand,
          children: children,
        ),
      );
    }

    return _NclInheritedWidget(
      state: this,
      bounds: bounds,
      child: content,
    );
  }
}

class _NclInheritedWidget extends InheritedWidget {
  final NclWidgetState state;
  final Rectangle<double> bounds;

  const _NclInheritedWidget({
    required this.state,
    required this.bounds,
    required super.child,
  });

  @override
  bool updateShouldNotify(_NclInheritedWidget oldWidget) {
    return bounds != oldWidget.bounds || state != oldWidget.state;
  }
}
