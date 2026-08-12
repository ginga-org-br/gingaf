import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:ncldoc/ncl_document.dart';

import '../main_av.dart';
import 'widgets/ncl_media_widget.dart';

export 'widgets/av.dart';
export 'widgets/html.dart';
export 'widgets/image.dart';
export 'widgets/lua.dart';
export 'widgets/ncl_media_widget.dart';
export 'widgets/ssml.dart';
export 'widgets/text.dart';

final _logger = Logger('ginga-ncl');

class NCLAppExitNotification extends Notification {}

class NCLApp extends MediaWidget {
  final MainAVController? mainAVController;

  NCLApp({
    super.key,
    required super.src,
    super.media,
    this.mainAVController,
    super.config,
  });

  @override
  State<NCLApp> createState() => NCLAppState();
}

class NCLAppState extends MediaState<NCLApp> {
  NCLDocument? nclDocument;
  final Map<String, GlobalKey<MediaState>> _mediaStateKeys = {};
  final Map<String, Widget> _cachedWidgets = {};
  Timer? _ticker;
  String errorMsg = "";
  bool _loading = false;
  String? _initialMainAvUri;

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

    String? sbtvdUri;
    for (var media in activeMedia) {
      if (media.uri.startsWith('sbtvd://')) {
        sbtvdUri = media.uri;
      }
    }
    if (sbtvdUri != null) {
      final resolvedUri = sbtvdUri.startsWith('sbtvd://')
          ? (_initialMainAvUri ?? sbtvdUri)
          : sbtvdUri;
      widget.mainAVController?.setMainAvUri(resolvedUri);
    } else {
      if (widget.mainAVController != null &&
          widget.mainAVController!.uri != _initialMainAvUri) {
        widget.mainAVController!.setMainAvUri(_initialMainAvUri);
      }
    }

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
        final mediaWidget = WidgetFactory.createMediaWidget(
            key: key,
            media: media,
            mainAVController: widget.mainAVController,
            config: widget.config);
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
    _initialMainAvUri = widget.mainAVController?.uri;
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
      }

      final activeLoader = widget.config.contentLoader
        ..setBuildContext(context);

      final srcString = widget.src;
      final String nclData;
      if (srcString.trim().startsWith('<')) {
        nclData = srcString;
      } else {
        final uri = activeLoader.resolveUri(srcString);
        nclData = await activeLoader.load(uri) ?? '';
      }
      if (!mounted) return;

      final usersDataSrc = widget.config.usersDataSrc;
      String? effectiveUserData;
      if (usersDataSrc != null) {
        final str = usersDataSrc.trim();
        if (str.startsWith('[') || str.startsWith('{')) {
          effectiveUserData = str;
        } else {
          final uri = activeLoader.resolveUri(str);
          final content = await activeLoader.load(uri);
          if (!mounted) return;
          if (content == null) {
            throw Exception('USERS_DATA file does not exist: $usersDataSrc');
          }
          effectiveUserData = content;
        }
      }
      if (!mounted) return;
      final doc = NCLDocument.fromContent(
        nclData,
        docSrc: srcString,
        userData: effectiveUserData,
        contentLoader: activeLoader,
      );

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
                  NCLAppExitNotification().dispatch(context);
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
