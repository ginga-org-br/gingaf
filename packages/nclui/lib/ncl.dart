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
  final GingaConfig config;
  final GlobalKey<MainAVWidgetState>? mainAvKey;

  NclWidget({
    super.key,
    required super.src,
    super.media,
    super.document,
    GingaConfig? config,
    this.mainAvKey,
  }) : config = config ?? GingaConfig();

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
        if (!_mediaStateKeys.containsKey(id)) {
          widget.mainAvKey!.currentState?.setMedia(media, nclDocument);
          _mediaStateKeys[id] = widget.mainAvKey!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
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
      final doc = await NclDocument.fromSrc(
        widget.src,
        config: widget.config,
      );
      if (!mounted) return;

      nclDocument = doc;
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
            final now = DateTime.now();
            final deltaMs = now.difference(lastTick).inMilliseconds;
            lastTick = now;
            final changedMedia = nclDocument?.tick(deltaMs) ?? <Media>{};

            if (nclDocument != null) {
              for (var media in changedMedia) {
                _mediaStateKeys[media.id ?? '']?.currentState?.syncProperties();
              }

              final currentActiveMedia = nclDocument!.getActiveMedia();
              if (_syncActiveMedia(currentActiveMedia)) {
                if (mounted) {
                  setState(() {});
                }
              }

              if (!nclDocument!.isPlaying) {
                _ticker?.cancel();
                _ticker = null;
                nclDocument = null;
                if (mounted) {
                  NclWidgetExitNotification().dispatch(context);
                }
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

  void tick(int ms) {
    if (nclDocument != null) {
      final changedMedia = nclDocument!.tick(ms);
      for (var media in changedMedia) {
        _mediaStateKeys[media.id ?? '']?.currentState?.syncProperties();
      }
      _syncActiveMedia(nclDocument!.getActiveMedia());
      if (mounted) {
        setState(() {});
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
    if (errorMsg.isNotEmpty) {
      return Scaffold(
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
    }

    if (nclDocument == null && _cachedWidgets.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: errorMsg.isNotEmpty
              ? Text(errorMsg, style: const TextStyle(color: Colors.red))
              : const CircularProgressIndicator(),
        ),
      );
    }

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        key: const Key('ncl_app_stack'),
        fit: StackFit.expand,
        children: children,
      ),
    );
  }
}
