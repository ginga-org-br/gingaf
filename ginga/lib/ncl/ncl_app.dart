import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:ncl_doc/ncl_document.dart' hide State;

import 'widgets/ncl_media_widget.dart';

export 'widgets/av.dart';
export 'widgets/image.dart';
export 'widgets/lua.dart';
export 'widgets/ncl_media_widget.dart';
export 'widgets/ssml.dart';
export 'widgets/text.dart';

final _logger = Logger('ginga-ncl');

class NCLAppExitNotification extends Notification {}

class NCLApp extends MediaWidget {
  const NCLApp({
    super.key,
    required super.uri,
    super.media,
  });

  @override
  State<NCLApp> createState() => NCLAppState();
}

class NCLAppState extends MediaState<NCLApp> {
  final Map<String, GlobalKey<MediaState>> _mediaStateKeys = {};
  final Map<String, Widget> _cachedWidgets = {};
  NCLDocument? nclDocument;
  Timer? _ticker;
  String errorMsg = "";
  bool _loading = false;

  bool _syncActiveMedia(List<Media> activeMedia) {
    bool changed = false;
    final currentIds = activeMedia.map((m) => m.id ?? '').toSet();

    final toRemove =
        _cachedWidgets.keys.where((id) => !currentIds.contains(id)).toList();
    if (toRemove.isNotEmpty) changed = true;
    for (var id in toRemove) {
      _cachedWidgets.remove(id);
      _mediaStateKeys.remove(id);
    }

    for (var media in activeMedia) {
      final id = media.id ?? '';
      if (!_cachedWidgets.containsKey(id)) {
        final key = GlobalKey<MediaState>();
        final widget = WidgetFactory.createMediaWidget(key: key, media: media);
        if (widget != null) {
          _mediaStateKeys[id] = key;
          _cachedWidgets[id] = widget;
          changed = true;
        }
      }
    }
    return changed;
  }

  @override
  void initState() {
    super.initState();
    _logger.info("Starting NCL application: ${widget.uri}");
    _startApplication();
  }

  Future<void> _startApplication() async {
    if (_loading) return;
    _loading = true;
    try {
      if (mounted) {
        setState(() {});
      }

      String nclData = await loadContent(widget.uri);

      final uri = widget.uri.startsWith('http')
          ? Uri.parse(widget.uri)
          : (kIsWeb ? Uri.parse(widget.uri) : Uri.file(widget.uri));
      final doc = NCLDocument.fromXML(nclData, baseURI: uri);

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
          _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
            if (mounted) {
              final now = DateTime.now();
              final deltaMs = now.difference(lastTick).inMilliseconds;
              lastTick = now;
              final changedMedia = nclDocument?.tick(deltaMs) ?? <Media>{};

              if (nclDocument != null) {
                for (var media in changedMedia) {
                  _mediaStateKeys[media.id ?? '']
                      ?.currentState
                      ?.syncProperties();
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
                    setState(() {});
                  }
                  NCLAppExitNotification().dispatch(context);
                }
              }
            }
          });
        });
      }
    } catch (e, stacktrace) {
      _logger.severe("Error: $e\n$stacktrace");
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
    _logger.info("Stopping NCL application: ${widget.uri}");
    _ticker?.cancel();
    final doc = nclDocument;
    nclDocument = null;
    doc?.stop();
    super.dispose();
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    if (nclDocument == null && _cachedWidgets.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
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
      backgroundColor: Colors.white,
      body: Stack(
        key: const Key('ncl_app_stack'),
        fit: StackFit.expand,
        children: children,
      ),
    );
  }
}
